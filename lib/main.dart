import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:torch_light/torch_light.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(home: BarcodeScannerPage());
}

class BarcodeScannerPage extends StatefulWidget {
  @override
  _BarcodeScannerPageState createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final player = AudioPlayer();
  final MobileScannerController controller = MobileScannerController(
    facing: CameraFacing.front,
    torchEnabled: false,
    detectionSpeed: DetectionSpeed.normal,
    returnImage: true,
    formats: [BarcodeFormat.code128, BarcodeFormat.ean13, BarcodeFormat.qrCode, BarcodeFormat.upcA],
  );

  bool isPlaying = false;
  bool isCooldown = false;
  String? scannedCode;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(statusBarColor: Colors.transparent));

    player.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: [AVAudioSessionOptions.defaultToSpeaker],
      ),
    ));

    player.onPlayerComplete.listen((event) {
      setState(() => isPlaying = false);
    });
  }

  void _onDetect(BarcodeCapture capture) async {
    if (isPlaying || isCooldown) return;

    final barcode = capture.barcodes.first.rawValue;
    if (barcode == null) return;

    // EAN-13 체크섬 자동 추가
    String finalCode = barcode.length == 12 ? _appendEAN13Checksum(barcode) : barcode;

    setState(() {
      scannedCode = finalCode;
      isPlaying = true;
      isCooldown = true;
    });

    try {
      await player.stop();

      final path = _audioPath(finalCode);
      if (path != null) {
        if (path != null) {
          await flash();

          // ✅ 먼저 morse_dash.wav 재생
          await player.play(AssetSource('audio/morse_dash.wav'));
          await player.onPlayerComplete.first;

          // ✅ 중복 방지 조건 추가
          if (path != 'audio/morse_dash.wav') {
            await player.play(AssetSource(path));
            await player.onPlayerComplete.first;
          }

          await delay();
        }
      } else {
        setState(() {
          isPlaying = false;
          isCooldown = false;
        });
      }
    } catch (e) {
      print('🔴 에러: $e');
      setState(() {
        isPlaying = false;
        isCooldown = false;
      });
    }
  }

  String _appendEAN13Checksum(String code) {
    if (code.length != 12) return code;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(code[i]);
      sum += i % 2 == 0 ? digit : digit * 3;
    }
    int checksum = (10 - (sum % 10)) % 10;
    return '$code$checksum';
  }

  String? _audioPath(String barcode) {
    const map = {
      '8809092578891': 'audio/morse_dash.wav',
      '5995295754033': 'audio/morse_dot.wav',
      '8809599361279': 'audio/111111.mp3',
      '8801114163405': 'audio/111112.mp3',
      '599519575403': 'audio/111113.mp3',
      '8809189925317': 'audio/111114.mp3',
      '8801068931396': 'audio/111115.mp3',
      '2000000913414': 'audio/111116.mp3',
    };
    return map[barcode];
  }

  @override
  void dispose() {
    player.dispose();
    controller.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        MobileScanner(
          controller: controller,
          onDetect: _onDetect,
        ),
        if (scannedCode != null)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$scannedCode',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  flash() async {
    try {
      if (await TorchLight.isTorchAvailable()) {
        await TorchLight.enableTorch();
        await Future.delayed(Duration(milliseconds: 100));
        await TorchLight.disableTorch();
      }
    } catch (e) {
      print('🔦 플래시 오류: $e');
    }
  }

  delay() async {
    await Future.delayed(Duration(seconds: 3));
    setState(() => isCooldown = false);
  }
}

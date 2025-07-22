import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
    facing: CameraFacing.back,
    torchEnabled: false,
    detectionSpeed: DetectionSpeed.normal,
    returnImage: true,
    formats: [BarcodeFormat.all],
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

    setState(() {
      scannedCode = barcode;
      isPlaying = true;
      isCooldown = true;
    });

    try {
      await player.stop();

      final path = _audioPath(barcode);
      if (path != null) {
        await flash();
        await player.play(AssetSource(path));
        await delay();
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

  String? _audioPath(String barcode) {
    const map = {
      '8809092578891': 'audio/morse_dash.wav',
      '599529575403': 'audio/morse_dot.wav',
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
    await controller.toggleTorch();
    await Future.delayed(Duration(milliseconds: 100));
    await controller.toggleTorch();
  }

  delay() async {
    await Future.delayed(Duration(seconds: 3));
    setState(() => isCooldown = false);
  }
}

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

class _BarcodeScannerPageState extends State<BarcodeScannerPage> with SingleTickerProviderStateMixin {
  final player = AudioPlayer();
  final MobileScannerController controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
    detectionSpeed: DetectionSpeed.normal,
    returnImage: true,
    formats: [BarcodeFormat.code128, BarcodeFormat.ean13, BarcodeFormat.qrCode, BarcodeFormat.upcA],
  );

  bool isPlaying = false;
  bool isCooldown = false;
  String? scannedCode;
  late AnimationController _laserController;
  late Animation<double> _laserPosition;

  int tapCount = 0;
  DateTime? firstTapTime;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final screenHeight = MediaQuery.of(context).size.height;

    _laserController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();

    _laserPosition = Tween<double>(begin: 0, end: screenHeight).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.linear),
    );
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
      '8809092578891': 'audio/1.wav',
      '8809524905714': 'audio/2.wav',
      '8809189925317': 'audio/3.wav',
      '8801068931396': 'audio/4.wav',
      '8809599361279': 'audio/5.wav',
      '8801114163405': 'audio/6.wav',
      '5995295754033': 'audio/morse_dash.wav',
      '599519575403': 'audio/morse_dash.wav',
      '2000000913414': 'audio/morse_dash.wav',
      'http://m.site.naver.com/0EvG1': 'audio/morse_dash.wav',
    };
    return map[barcode];
  }

  void _handleTap() {
    final now = DateTime.now();
    if (firstTapTime == null || now.difference(firstTapTime!) > Duration(seconds: 5)) {
      firstTapTime = now;
      tapCount = 1;
    } else {
      tapCount++;
      if (tapCount >= 10) {
        controller.switchCamera();
        tapCount = 0;
        firstTapTime = null;
      }
    }
  }

  @override
  void dispose() {
    player.dispose();
    controller.dispose();
    WakelockPlus.disable();
    _laserController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _handleTap,
    child: Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          AnimatedBuilder(
            animation: _laserPosition,
            builder: (_, __) => Positioned(
              top: _laserPosition.value,
              left: 0,
              right: 0,
              child: Container(height: 20, color: Colors.redAccent),
            ),
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
    ),
  );

  flash() async {
    try {
      await TorchLight.enableTorch();
      await Future.delayed(Duration(milliseconds: 100));
      await TorchLight.disableTorch();
    } catch (e) {
      print('🔦 플래시 오류: $e');
    }
  }

  delay() async {
    await Future.delayed(Duration(seconds: 3));
    setState(() => isCooldown = false);
  }
}

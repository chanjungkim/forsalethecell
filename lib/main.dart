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
  final MobileScannerController controller = MobileScannerController();
  bool isPlaying = false;
  bool isCooldown = false;
  String? scannedCode;

  @override
  void initState() {
    super.initState();
    // 화면 항상 켜짐
    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  }

  void _onDetect(BarcodeCapture capture) async {
    final barcode = capture.barcodes.first.rawValue;
    if (barcode == null || isPlaying || isCooldown) return;

    final path = 'assets/audio/$barcode.mp3';

    try {
      setState(() {
        scannedCode = barcode;
        isPlaying = true;
        isCooldown = true;
      });

      // 플래시 깜빡이기
      await controller.toggleTorch();
      await Future.delayed(Duration(milliseconds: 100));
      await controller.toggleTorch();

      switch (barcode) {
        case '8809092578891':
          await player.play(AssetSource('audio/morse_dash.wav'));
          break;
        case '599529575403':
          await player.play(AssetSource('audio/morse_dot.wav'));
          break;
        case '8809599361279':
          await player.play(AssetSource('audio/111111.mp3'));
          break;
        case '8801114163405':
          await player.play(AssetSource('audio/111112.mp3'));
          break;
        case '599519575403':
          await player.play(AssetSource('audio/111113.mp3'));
          break;
        case '8809189925317':
          await player.play(AssetSource('audio/111114.mp3'));
          break;
        case '8801068931396':
          await player.play(AssetSource('audio/111115.mp3'));
          break;
        case '2000000913414':
          await player.play(AssetSource('audio/111116.mp3'));
          break;
        default:
          await player.play(AssetSource('audio/111113.mp3'));
        // 기본 처리
      }
      player.onPlayerComplete.listen((event) {
        setState(() => isPlaying = false);
      });

      // 3초 쿨타임 설정
      await Future.delayed(Duration(seconds: 3));
      setState(() => isCooldown = false);
    } catch (e) {
      print('🔴 에러: \$e');
      setState(() {
        isPlaying = false;
        isCooldown = false;
      });
    }
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
}

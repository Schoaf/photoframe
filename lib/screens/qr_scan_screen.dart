import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/app_localizations.dart';

/// Scans one QR code (e.g. the token HA shows) and returns its text.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  // On the wall, the front camera faces whoever holds up the code.
  final _controller = MobileScannerController(
    facing: CameraFacing.front,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _hasResult = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (value == null || _hasResult) return;
    _hasResult = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text(l10n.scanQr),
        actions: [
          IconButton(
            iconSize: 32,
            tooltip: l10n.switchCamera,
            icon: const Icon(Icons.cameraswitch),
            onPressed: _controller.switchCamera,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                l10n.scanQrHint,
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 8)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

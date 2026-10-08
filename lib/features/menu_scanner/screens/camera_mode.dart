import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraMode extends StatelessWidget {
  final CameraController? controller;
  final bool isScanning;
  final VoidCallback onTakePicture;

  const CameraMode({
    super.key,
    required this.controller,
    required this.isScanning,
    required this.onTakePicture,
  });

  @override
  Widget build(BuildContext context) {
    final camera = controller;

    if (camera == null || !camera.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // =========================================
          // FULL SCREEN CAMERA
          // =========================================
          Positioned.fill(child: CameraPreview(camera)),

          // =========================================
          // SCAN BUTTON
          // =========================================
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Center(
                  child: GestureDetector(
                    onTap: isScanning ? null : onTakePicture,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 4,
                        ),
                      ),
                      child: isScanning
                          ? const Padding(
                              padding: EdgeInsets.all(22),
                              child: CircularProgressIndicator(
                                color: Colors.black,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              color: Colors.black,
                              size: 32,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

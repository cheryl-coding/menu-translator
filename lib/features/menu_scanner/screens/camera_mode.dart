import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraMode extends StatelessWidget {
  final CameraController? controller;
  final bool isScanning;
  final VoidCallback onTakePicture;
  final VoidCallback onPickImage;

  const CameraMode({
    super.key,
    required this.controller,
    required this.isScanning,
    required this.onTakePicture,
    required this.onPickImage,
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
          // CAMERA CONTROLS
          // =========================================
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: SizedBox(
                  height: 78,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Gallery button - LEFT
                      Positioned(
                        left: 40,
                        child: IconButton(
                          onPressed: isScanning ? null : onPickImage,
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            color: Colors.white,
                            size: 32,
                          ),
                          tooltip: 'Choose menu photo',
                        ),
                      ),

                      // Camera shutter - CENTER
                      GestureDetector(
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
                    ],
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

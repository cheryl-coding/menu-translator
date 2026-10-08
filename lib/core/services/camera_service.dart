// availableCameras()
// CameraController
// initialize()
// takePicture()
// dispose()

import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  CameraController? get controller => _controller;

  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isTakingPicture => _controller?.value.isTakingPicture ?? false;

  Future<void> initialize() async {
    // Dispose previous controller if there is one.
    await dispose();
    final cameras = await availableCameras();

    if (cameras.isEmpty) {
      throw Exception('No cameras found');
    }

    // Prefer back camera.
    final camera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _controller = controller;

    await controller.initialize();
  }

  Future<XFile> takePicture() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      throw Exception('Camera is not initialized');
    }
    return await controller.takePicture();
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}

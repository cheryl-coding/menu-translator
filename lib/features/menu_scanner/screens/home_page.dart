import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/services/pexels_service.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/services/image_service.dart';
import '../../../core/services/menu_phrase_service.dart';
import '../utils/menu_coordinate_helper.dart';
import '../models/dish_image.dart';
import 'camera_mode.dart';
import 'menu_mode.dart';

enum AppMode { camera, menu }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --------------------------------------------------
  // SERVICES
  // --------------------------------------------------

  final PexelsService _pexelsService = PexelsService();

  // --------------------------------------------------
  // CONTROLLERS
  // --------------------------------------------------
  final OcrService _ocrService = OcrService();
  final MenuPhraseService _menuPhraseService = MenuPhraseService();
  final TextEditingController _searchController = TextEditingController();
  final ImageService _imageService = ImageService();
  final CameraService _cameraService = CameraService();

  // --------------------------------------------------
  // IMAGE / OCR DATA
  // --------------------------------------------------

  File? _image;

  // IMPORTANT:
  // We need this to convert ML Kit coordinates
  // into coordinates on the displayed image.
  Size? _imageSize;

  List<MenuPhrase> _textElements = [];

  String extractedText = '';

  // --------------------------------------------------
  // DISH DATA
  // --------------------------------------------------

  String selectedDish = '';
  MenuPhrase? highlightedElement;
  List<DishImage> dishImages = [];

  // --------------------------------------------------
  // APP MODE
  // --------------------------------------------------

  AppMode _mode = AppMode.camera;

  // --------------------------------------------------
  // UI STATE
  // --------------------------------------------------

  bool isScanning = false;

  bool isSearching = false;

  // --------------------------------------------------
  // initialize the camera startup
  // --------------------------------------------------

  @override
  void initState() {
    super.initState();
    _goToCameraMode();
  }

  // --------------------------------------------------
  // DISPOSE
  // --------------------------------------------------

  @override
  void dispose() {
    _cameraService.dispose();
    _ocrService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ==================================================
  // INITIALIZE CAMERA
  // ==================================================

  Future<void> _initializeCamera() async {
    await _cameraService.initialize();
  }

  // ==================================================
  // OPEN CAMERA MODE
  // ==================================================

  Future<void> _goToCameraMode() async {
    try {
      setState(() {
        _mode = AppMode.camera;
      });

      await _initializeCamera();

      if (!mounted) return;

      setState(() {});
    } catch (e) {
      debugPrint('Could not open camera: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open camera: $e')));
    }
  }

  // ==================================================
  // TAKE PICTURE
  // ==================================================

  Future<void> _takePicture() async {
    final controller = _cameraService.controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    try {
      setState(() {
        isScanning = true;
      });

      // 1. Take picture.
      final XFile photo = await _cameraService.takePicture();

      final File rawImageFile = File(photo.path);

      // 2. Normalize orientation.
      final File imageFile = await _imageService.normalizeOrientation(
        rawImageFile,
      );

      // 3. Get image size.
      final Size imageSize = await _imageService.getImageSize(imageFile);

      if (!mounted) return;

      // 4. Reset old menu state.
      setState(() {
        _image = imageFile;
        _imageSize = imageSize;
        _textElements = [];
        extractedText = '';
        selectedDish = '';
        dishImages = [];
        highlightedElement = null;
      });

      // 5. Camera is no longer needed.
      await _cameraService.dispose();

      // 6. Run OCR.
      await _extractText(imageFile);

      if (!mounted) return;

      // 7. Open menu mode.
      setState(() {
        _mode = AppMode.menu;
      });
    } catch (e) {
      debugPrint('Take picture error: $e');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not take picture: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          isScanning = false;
        });
      }
    }
  }

  // ==================================================
  // OCR
  // ==================================================

  Future<void> _extractText(File imageFile) async {
    try {
      setState(() {
        isScanning = true;
      });

      final RecognizedText recognizedText = await _ocrService.recognizeText(
        imageFile,
      );

      final words = _ocrService.extractElements(recognizedText);
      final elements = _menuPhraseService.groupIntoPhrases(words);

      if (!mounted) return;

      setState(() {
        extractedText = recognizedText.text;
        _textElements = elements;
      });

      debugPrint('OCR TEXT:\n$extractedText');
    } catch (e) {
      debugPrint('OCR error: $e');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not read the menu: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          isScanning = false;
        });
      }
    }
  }

  Future<void> _searchDish(String dishName) async {
    try {
      setState(() {
        isSearching = true;
        selectedDish = dishName;
        dishImages = [];
      });

      final results = await _pexelsService.searchDish(dishName);

      if (!mounted) return;

      setState(() {
        dishImages = results;
      });
    } catch (e) {
      debugPrint('Pexels search error: $e');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not find pictures: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          isSearching = false;
        });
      }
    }
  }

  // ==================================================
  // HANDLE MENU TAP
  // ==================================================
  void _handleMenuTap(Offset tapPosition, Size displayedSize) {
    if (_textElements.isEmpty || _imageSize == null) {
      return;
    }

    final element = MenuCoordinateHelper.findTappedElement(
      tapPosition: tapPosition,
      elements: _textElements,
      originalImageSize: _imageSize!,
      displayedSize: displayedSize,
    );

    if (element == null) {
      debugPrint('No OCR box was tapped.');
      return;
    }

    final dishName = element.text.trim();

    if (dishName.isEmpty) {
      return;
    }

    setState(() {
      highlightedElement = element;
    });

    _searchController.text = dishName;

    _searchDish(dishName);
  }

  // ==================================================
  // CLOSE DISH PHOTOS
  // ==================================================

  void _closeDishPhotos() {
    setState(() {
      selectedDish = '';
      dishImages = [];
      isSearching = false;
    });
  }

  // ==================================================
  // MAIN UI
  // ==================================================

  @override
  Widget build(BuildContext context) {
    if (_mode == AppMode.camera) {
      return CameraMode(
        controller: _cameraService.controller,
        isScanning: isScanning,
        onTakePicture: _takePicture,
      );
    }

    if (_image == null || _imageSize == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MenuMode(
      image: _image!,
      imageSize: _imageSize!,
      textElements: _textElements,
      highlightedElement: highlightedElement,
      selectedDish: selectedDish,
      dishImages: dishImages,
      isSearching: isSearching,
      onMenuTap: _handleMenuTap,
      onExit: _goToCameraMode,
      onCloseDishPhotos: _closeDishPhotos,
    );
  }
}

import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:translator/translator.dart';

import '../../../core/services/pexels_service.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/services/image_service.dart';
import '../../../core/services/menu_phrase_service.dart';
import '../../../core/services/menu_structure_service.dart';
import '../../../core/services/menu_column_service.dart';
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
  final MenuStructureService _menuStructureService = MenuStructureService();
  final TextEditingController _searchController = TextEditingController();
  final ImageService _imageService = ImageService();
  final CameraService _cameraService = CameraService();
  final ImagePicker _imagePicker = ImagePicker();

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

  List<ParsedMenuItem> _menuItems = [];
  ParsedMenuItem? selectedItem;

  // --------------------------------------------------
  // APP MODE
  // --------------------------------------------------

  AppMode _mode = AppMode.camera;

  // --------------------------------------------------
  // UI STATE
  // --------------------------------------------------

  bool isScanning = false;

  bool isSearching = false;

  bool isTranslating = false;
  String? dishTranslation;

  final GoogleTranslator _translator = GoogleTranslator();
  int _translationRequestId = 0;

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
        _menuItems = [];
        selectedItem = null;
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

      // 1. Recognize text using Google ML Kit.
      final RecognizedText recognizedText = await _ocrService.recognizeText(
        imageFile,
      );

      // 2. Extract individual OCR words.
      final words = _ocrService.extractElements(recognizedText);

      // 3. Group words into phrases.
      final phrases = _menuPhraseService.groupIntoPhrases(words);

      debugPrint('====== PRICE OCR DEBUG ======');

      for (final phrase in phrases) {
        final text = phrase.text.trim();

        if (_menuPhraseService.isPrice(text)) {
          debugPrint(
            'PRICE CANDIDATE: "$text" '
            '| BOX: ${phrase.boundingBox}',
          );
        }
      }

      debugPrint('====== MISSING DISH DEBUG ======');

      for (final phrase in phrases) {
        final text = phrase.text.toUpperCase();

        if (text.contains('CRÈME') ||
            text.contains('BRÛLÉE') ||
            text.contains('FRENCH TOAST') ||
            text.contains('SALUMI') ||
            text.contains('FORMAGGI') ||
            text.contains('SOLO') ||
            text.contains('FEAST')) {
          debugPrint(
            'TEXT: ${phrase.text} | '
            'BOX: ${phrase.boundingBox}',
          );
        }
      }

      final columns = MenuColumnService().detectColumns(phrases);

      debugPrint('Detected ${columns.length} menu column(s)');

      for (var i = 0; i < columns.length; i++) {
        final column = columns[i];

        debugPrint(
          'Column ${i + 1}: '
          '${column.phrases.length} phrases '
          '(${column.left.toStringAsFixed(1)} - '
          '${column.right.toStringAsFixed(1)})',
        );
      }

      // 4. Identify dish names, prices, descriptions.
      final menuItems = _menuStructureService.parse(phrases);

      // 5. ONLY dish names should be selectable.
      final dishNameElements = menuItems.map((item) => item.name).toList();

      if (!mounted) return;

      setState(() {
        extractedText = recognizedText.text;

        // This controls the yellow rectangles
        // and the tappable OCR regions.
        _textElements = dishNameElements;

        // Save all parsed dishes, prices, and descriptions.
        _menuItems = menuItems;
        selectedItem = null;
      });

      // Debug output for algorithm development.
      debugPrint('========== PARSED MENU ==========');

      for (final item in menuItems) {
        debugPrint('DISH: ${item.name.text}');
        debugPrint('PRICE: ${item.price ?? "Unknown"}');
        debugPrint('DESCRIPTION: ${item.description}');
        debugPrint('---------------------------------');
      }
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

      _translationRequestId++;
      isTranslating = false;
      dishTranslation = null;

      selectedItem = null;

      for (final item in _menuItems) {
        if (identical(item.name, element) ||
            (item.name.text == element.text &&
                item.name.boundingBox == element.boundingBox)) {
          selectedItem = item;
          break;
        }
      }
    });

    _searchController.text = dishName;

    _searchDish(dishName);
  }

  // ==================================================
  // CLOSE DISH PHOTOS
  // ==================================================

  void _closeDishPhotos() {
    setState(() {
      _translationRequestId++;
      isTranslating = false;
      dishTranslation = null;

      selectedDish = '';
      dishImages = [];
      highlightedElement = null;
      selectedItem = null;
    });
  }

  // ==================================================
  // OPEN ALBUM
  // ==================================================

  Future<void> _pickMenuFromGallery() async {
    if (isScanning) return;

    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedImage == null || !mounted) return;

      // 1. Load selected photo.
      final rawImageFile = File(pickedImage.path);

      // 2. Normalize image orientation.
      final imageFile = await _imageService.normalizeOrientation(rawImageFile);

      // 3. Get image dimensions.
      final imageSize = await _imageService.getImageSize(imageFile);

      if (!mounted) return;

      // 4. Switch to menu mode BEFORE disposing
      // the camera controller.
      setState(() {
        _image = imageFile;
        _imageSize = imageSize;
        _textElements = [];
        extractedText = '';
        selectedDish = '';
        dishImages = [];
        highlightedElement = null;
        isScanning = true;
        _mode = AppMode.menu;
        _menuItems = [];
        selectedItem = null;
      });

      // 5. Release the camera.
      await _cameraService.dispose();

      // 6. Run the existing OCR + smart menu parser.
      if (!mounted) return;
      await _extractText(imageFile);
    } catch (e) {
      debugPrint('Gallery error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to process photo: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isScanning = false;
        });
      }
    }
  }

  Future<void> _translateSelectedDish() async {
    if (isTranslating || selectedDish.trim().isEmpty) {
      return;
    }

    final requestId = ++_translationRequestId;
    final dishName = selectedDish.trim();
    final description = selectedItem?.description.trim() ?? '';

    setState(() {
      isTranslating = true;
      dishTranslation = null;
    });

    try {
      final nameResult = await _translator.translate(dishName, to: 'zh-cn');

      String translatedText = nameResult.text;

      if (description.isNotEmpty) {
        final descriptionResult = await _translator.translate(
          description,
          to: 'zh-cn',
        );

        translatedText += '\n${descriptionResult.text}';
      }

      if (!mounted || requestId != _translationRequestId) {
        return;
      }

      setState(() {
        dishTranslation = translatedText;
      });
    } catch (error) {
      debugPrint('Translation failed: $error');

      if (!mounted || requestId != _translationRequestId) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Translation failed. Please try again.')),
      );
    } finally {
      if (mounted && requestId == _translationRequestId) {
        setState(() {
          isTranslating = false;
        });
      }
    }
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
        onPickImage: _pickMenuFromGallery,
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
      dishPrice: selectedItem?.price,
      dishDescription: selectedItem?.description,
      onTranslate: _translateSelectedDish,
      isTranslating: isTranslating,
      dishTranslation: dishTranslation,
    );
  }
}

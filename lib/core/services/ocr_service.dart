import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

class OcrService {
  // --------------------------------------------------
  // CONTROLLERS
  // --------------------------------------------------

  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<RecognizedText> recognizeText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);

    final RecognizedText recognizedText = await _textRecognizer.processImage(
      inputImage,
    );
    return recognizedText;
  }

  List<TextElement> extractElements(RecognizedText recognizedText) {
    final List<TextElement> elements = [];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        elements.addAll(line.elements);
      }
    }

    return elements;
  }

  void dispose() {
    _textRecognizer.close();
  }
}

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'dart:ui' show Rect;
import 'dart:math' show min, max;

class MenuPhrase {
  final String text;
  final Rect boundingBox;

  MenuPhrase({required this.text, required this.boundingBox});
}

class MenuPhraseService {
  List<MenuPhrase> groupIntoPhrases(List<TextElement> elements) {
    final List<MenuPhrase> groupedPhrases = [];
    int n = elements.length;

    // First element is always added to the groupedPhrases list
    for (int i = 0; i < n; i++) {
      final currentElement = elements[i];

      if (onlyHasPunctuation(currentElement.text)) {
        continue;
      }

      if (groupedPhrases.isEmpty) {
        groupedPhrases.add(
          MenuPhrase(
            text: currentElement.text,
            boundingBox: currentElement.boundingBox,
          ),
        );
        continue;
      }

      final previousElement = groupedPhrases.last;

      if (hasStrongPunctuation(previousElement.text)) {
        groupedPhrases.add(
          MenuPhrase(
            text: currentElement.text,
            boundingBox: currentElement.boundingBox,
          ),
        );
        continue;
      }

      final textHeight =
          (currentElement.boundingBox.height +
              previousElement.boundingBox.height) /
          2;

      final similarHeight =
          (currentElement.boundingBox.height -
                  previousElement.boundingBox.height)
              .abs() <
          textHeight * 0.5;

      final maxGap = textHeight * 0.6;

      // Check if the current element is on the same line as the previous one
      final gap =
          currentElement.boundingBox.left - previousElement.boundingBox.right;
      final sameLine =
          (currentElement.boundingBox.top - previousElement.boundingBox.top)
                  .abs() <
              textHeight * 0.5 &&
          (currentElement.boundingBox.bottom -
                      previousElement.boundingBox.bottom)
                  .abs() <
              textHeight * 0.5;
      final closeEnough =
          gap >= 0 &&
          gap < maxGap &&
          (similarHeight || sameLine); // Adjust this threshold as needed

      if (closeEnough) {
        final mergedText = '${previousElement.text} ${currentElement.text}';
        final mergedBoundingBox = Rect.fromLTRB(
          min(
            previousElement.boundingBox.left,
            currentElement.boundingBox.left,
          ),
          min(previousElement.boundingBox.top, currentElement.boundingBox.top),
          max(
            previousElement.boundingBox.right,
            currentElement.boundingBox.right,
          ),
          max(
            previousElement.boundingBox.bottom,
            currentElement.boundingBox.bottom,
          ),
        );
        groupedPhrases[groupedPhrases.length - 1] = MenuPhrase(
          text: mergedText,
          boundingBox: mergedBoundingBox,
        );
      } else {
        groupedPhrases.add(
          MenuPhrase(
            text: currentElement.text,
            boundingBox: currentElement.boundingBox,
          ),
        );
      }
    }
    return groupedPhrases;
  }

  bool hasStrongPunctuation(String text) {
    final punctuationPattern = RegExp(r'[.,;:!?]');
    return punctuationPattern.hasMatch(text);
  }

  bool hasStrongPrice(String text) {
    final pricePattern = RegExp(r'\$\d+(\.\d{2})?');
    return pricePattern.hasMatch(text);
  }

  bool onlyHasPunctuation(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r'^[^\w\s]+$').hasMatch(trimmed);
  }
}

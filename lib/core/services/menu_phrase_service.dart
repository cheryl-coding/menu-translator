import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MenuPhrase {
  final String text;
  final Rect boundingBox;

  MenuPhrase({required this.text, required this.boundingBox});
}

class MenuPhraseService {
  final RegExp _pricePattern = RegExp(r'^(?:[$€£]\s*)?\d{1,3}(?:[.,]\d{2})?$');

  bool isPrice(String text) {
    return _pricePattern.hasMatch(text.trim());
  }

  ({String name, String? price}) extractPrice(String text) {
    final cleaned = text.trim();

    // Allow common OCR errors in a trailing price:
    // I7 -> 17, l8 -> 18, O9 -> 09.
    final pattern = RegExp(
      r'^(.+?)\s+([$€£]?\s*[0-9IlOo]{1,3}(?:[.,][0-9IlOo]{2})?)$',
    );

    final match = pattern.firstMatch(cleaned);

    if (match == null) {
      return (name: cleaned, price: null);
    }

    final name = match.group(1)!.trim();
    var price = match.group(2)!.trim();

    price = price
        .replaceAll(RegExp(r'[Il]'), '1')
        .replaceAll(RegExp(r'[Oo]'), '0');

    return (name: name, price: price);
  }

  bool onlyHasPunctuation(String text) {
    final cleaned = text.trim();

    if (cleaned == '&' || cleaned == '+') {
      return false;
    }

    if (cleaned.isEmpty) return true;

    return RegExp(r'^[^\w\s]+$').hasMatch(cleaned);
  }

  bool hasStrongPunctuation(String text) {
    return RegExp(r'[;:!?]').hasMatch(text);
  }

  bool hasStrongPrice(String text) {
    return RegExp(r'[$€£]\s*\d+(?:[.,]\d{2})?').hasMatch(text);
  }

  List<MenuPhrase> groupIntoPhrases(List<TextElement> elements) {
    final words = elements.where((element) {
      final text = element.text.trim();
      return text.isNotEmpty && !onlyHasPunctuation(text);
    }).toList();

    if (words.isEmpty) return [];

    words.sort((a, b) {
      final dy = a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy);
      return dy != 0 ? dy : a.boundingBox.left.compareTo(b.boundingBox.left);
    });

    final lines = <List<TextElement>>[];

    for (final word in words) {
      List<TextElement>? bestLine;
      var bestDistance = double.infinity;

      for (final line in lines) {
        final centers = line.map((w) => w.boundingBox.center.dy).toList();

        final lineCenter = centers.reduce((a, b) => a + b) / centers.length;

        final heights = line.map((w) => w.boundingBox.height).toList()..sort();

        final lineHeight = heights[heights.length ~/ 2];

        final distance = (word.boundingBox.center.dy - lineCenter).abs();

        final tolerance = math.min(word.boundingBox.height, lineHeight) * 0.45;

        if (distance <= tolerance && distance < bestDistance) {
          bestLine = line;
          bestDistance = distance;
        }
      }

      if (bestLine == null) {
        lines.add([word]);
      } else {
        bestLine.add(word);
      }
    }

    final phrases = <MenuPhrase>[];

    for (final line in lines) {
      line.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

      var text = '';
      Rect? box;

      void flush() {
        if (text.isNotEmpty && box != null) {
          phrases.add(MenuPhrase(text: text, boundingBox: box!));
        }
        text = '';
        box = null;
      }

      for (final word in line) {
        final wordText = word.text.trim();
        final wordBox = word.boundingBox;

        if (box == null) {
          text = wordText;
          box = wordBox;
          continue;
        }

        final gap = wordBox.left - box!.right;

        final referenceHeight = math.max(
          1.0,
          math.min(box!.height, wordBox.height),
        );

        final shouldMerge =
            gap >= -referenceHeight * 0.2 &&
            gap <= referenceHeight * 2.2 &&
            !isPrice(wordText) &&
            !isPrice(text);

        if (shouldMerge) {
          text = '$text $wordText';
          box = box!.expandToInclude(wordBox);
        } else {
          flush();
          text = wordText;
          box = wordBox;
        }
      }

      flush();
    }

    final result = <MenuPhrase>[];

    for (final phrase in phrases) {
      final extracted = extractPrice(phrase.text);

      if (extracted.price == null || extracted.name.isEmpty) {
        result.add(phrase);
        continue;
      }

      // Approximate character positions if OCR
      // supplied one box for both name and price.
      final nameLength = extracted.name.length;
      final fullLength = phrase.text.trim().length;

      final fraction = nameLength / math.max(1, fullLength);

      final splitX =
          phrase.boundingBox.left + phrase.boundingBox.width * fraction;

      result.add(
        MenuPhrase(
          text: extracted.name,
          boundingBox: Rect.fromLTRB(
            phrase.boundingBox.left,
            phrase.boundingBox.top,
            splitX,
            phrase.boundingBox.bottom,
          ),
        ),
      );

      result.add(
        MenuPhrase(
          text: extracted.price!,
          boundingBox: Rect.fromLTRB(
            splitX,
            phrase.boundingBox.top,
            phrase.boundingBox.right,
            phrase.boundingBox.bottom,
          ),
        ),
      );
    }

    result.sort((a, b) {
      final dy = a.boundingBox.top.compareTo(b.boundingBox.top);
      return dy != 0 ? dy : a.boundingBox.left.compareTo(b.boundingBox.left);
    });

    return result;
  }
}

import 'package:flutter/material.dart';
import '../../../core/services/menu_phrase_service.dart';

// ====================================================
// OCR HIGHLIGHT PAINTER
// ====================================================

class MenuHighlightPainter extends CustomPainter {
  final Size imageSize;
  final List<MenuPhrase> textElements;
  final MenuPhrase? highlightedElement;

  MenuHighlightPainter({
    required this.imageSize,
    required this.textElements,
    required this.highlightedElement,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (textElements.isEmpty) {
      return;
    }

    // ML Kit gives us coordinates
    // based on the ORIGINAL image.
    //
    // We convert those coordinates
    // to the displayed image size.

    final double scaleX = size.width / imageSize.width;

    final double scaleY = size.height / imageSize.height;

    for (final element in textElements) {
      final Rect box = element.boundingBox;

      final Rect scaledRect = Rect.fromLTRB(
        box.left * scaleX,
        box.top * scaleY,
        box.right * scaleX,
        box.bottom * scaleY,
      );

      final bool isSelected = identical(element, highlightedElement);
      // Transparent yellow fill.
      final Paint fillPaint = Paint()
        ..color = isSelected
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.yellow.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill;

      // Yellow outline.
      final Paint borderPaint = Paint()
        ..color = isSelected ? Colors.blue : Colors.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawRect(scaledRect, fillPaint);

      canvas.drawRect(scaledRect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MenuHighlightPainter oldDelegate) {
    return oldDelegate.imageSize != imageSize ||
        oldDelegate.textElements != textElements ||
        oldDelegate.highlightedElement != highlightedElement;
  }
}

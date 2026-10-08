import 'package:flutter/material.dart';
import '../../../core/services/menu_phrase_service.dart';

class MenuCoordinateHelper {
  static Rect scaleRect({
    required Rect originalRect,
    required Size originalImageSize,
    required Size displayedSize,
  }) {
    final scaleX = displayedSize.width / originalImageSize.width;

    final scaleY = displayedSize.height / originalImageSize.height;

    return Rect.fromLTRB(
      originalRect.left * scaleX,
      originalRect.top * scaleY,
      originalRect.right * scaleX,
      originalRect.bottom * scaleY,
    );
  }

  static MenuPhrase? findTappedElement({
    required Offset tapPosition,
    required List<MenuPhrase> elements,
    required Size originalImageSize,
    required Size displayedSize,
  }) {
    for (final element in elements) {
      final displayedBox = scaleRect(
        originalRect: element.boundingBox,
        originalImageSize: originalImageSize,
        displayedSize: displayedSize,
      );

      if (displayedBox.contains(tapPosition)) {
        return element;
      }
    }

    return null;
  }
}

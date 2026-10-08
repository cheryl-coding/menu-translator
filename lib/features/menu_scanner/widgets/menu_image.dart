import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/services/menu_phrase_service.dart';

import '../painters/menu_highlight_painter.dart';

class MenuImage extends StatelessWidget {
  final File image;
  final Size imageSize;
  final List<MenuPhrase> textElements;
  final MenuPhrase? highlightedElement;

  final void Function(Offset tapPosition, Size displayedSize) onTap;

  const MenuImage({
    super.key,
    required this.image,
    required this.imageSize,
    required this.textElements,
    required this.highlightedElement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Scanned Menu',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        // ------------------------------------------
        // ZOOMABLE IMAGE
        // ------------------------------------------
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            height: 500,
            color: Colors.black,

            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,

              panEnabled: true,
              scaleEnabled: true,

              boundaryMargin: const EdgeInsets.all(100),

              child: Center(
                child: AspectRatio(
                  aspectRatio: imageSize.width / imageSize.height,

                  // IMPORTANT:
                  // Image + highlights are
                  // children of the SAME
                  // InteractiveViewer.
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final Size displayedSize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          onTap(details.localPosition, displayedSize);
                        },

                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // --------------------------------
                            // MENU IMAGE
                            // --------------------------------
                            Image.file(image, fit: BoxFit.fill),

                            // --------------------------------
                            // OCR HIGHLIGHTS
                            // --------------------------------
                            CustomPaint(
                              painter: MenuHighlightPainter(
                                imageSize: imageSize,
                                textElements: textElements,
                                highlightedElement: highlightedElement,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

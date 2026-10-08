import 'dart:io';

import 'package:flutter/material.dart';

import '../models/dish_image.dart';
import '../painters/menu_highlight_painter.dart';
import '../../../core/services/menu_phrase_service.dart';

class MenuMode extends StatelessWidget {
  final File image;
  final Size imageSize;

  final List<MenuPhrase> textElements;
  final MenuPhrase? highlightedElement;

  final String selectedDish;
  final List<DishImage> dishImages;

  final bool isSearching;

  final void Function(Offset tapPosition, Size displayedSize) onMenuTap;

  final VoidCallback onExit;
  final VoidCallback onCloseDishPhotos;

  const MenuMode({
    super.key,
    required this.image,
    required this.imageSize,
    required this.textElements,
    required this.highlightedElement,
    required this.selectedDish,
    required this.dishImages,
    required this.isSearching,
    required this.onMenuTap,
    required this.onExit,
    required this.onCloseDishPhotos,
  });

  bool get _showDishPhotos {
    return selectedDish.isNotEmpty || dishImages.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: SafeArea(
        child: Stack(
          children: [
            // ==========================================
            // MENU IMAGE
            // ==========================================
            Positioned.fill(child: _buildMenuImage()),

            // ==========================================
            // EXIT BUTTON
            // ==========================================
            Positioned(top: 12, left: 12, child: _buildExitButton()),

            // ==========================================
            // DISH PHOTO PANEL
            //
            // This slides upward when a dish is selected.
            // ==========================================
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,

              left: 0,
              right: 0,

              bottom: _showDishPhotos ? 0 : -230,

              height: 230,

              child: _buildDishPhotos(),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================
  // MENU IMAGE
  // ==================================================

  Widget _buildMenuImage() {
    return Container(
      color: Colors.black,

      child: Center(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,

          panEnabled: true,
          scaleEnabled: true,

          boundaryMargin: const EdgeInsets.all(100),

          child: AspectRatio(
            aspectRatio: imageSize.width / imageSize.height,

            child: LayoutBuilder(
              builder: (context, constraints) {
                final Size displayedSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,

                  // ====================================
                  // TAP OCR BOX
                  // ====================================
                  onTapUp: (details) {
                    onMenuTap(details.localPosition, displayedSize);
                  },

                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ==================================
                      // ORIGINAL MENU IMAGE
                      // ==================================
                      Image.file(image, fit: BoxFit.fill),

                      // ==================================
                      // OCR BOXES
                      // ==================================
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
    );
  }

  // ==================================================
  // EXIT BUTTON
  // ==================================================

  Widget _buildExitButton() {
    return Container(
      width: 48,
      height: 48,

      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        shape: BoxShape.circle,
      ),

      child: IconButton(
        onPressed: onExit,

        icon: const Icon(Icons.close, color: Colors.white),
      ),
    );
  }

  // ==================================================
  // DISH PHOTOS
  // ==================================================

  Widget _buildDishPhotos() {
    return Material(
      color: Colors.white,

      elevation: 16,

      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============================================
          // DRAG HANDLE
          // ============================================
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),

              width: 42,
              height: 4,

              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // ============================================
          // HEADER
          // ============================================
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),

            child: Row(
              children: [
                // Dish name
                Expanded(
                  child: Text(
                    selectedDish.isEmpty ? 'Dish Photos' : selectedDish,

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Close photos
                IconButton(
                  onPressed: onCloseDishPhotos,

                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ============================================
          // PHOTO CONTENT
          // ============================================
          Expanded(child: _buildPhotoContent()),
        ],
      ),
    );
  }

  // ==================================================
  // PHOTO CONTENT
  // ==================================================

  Widget _buildPhotoContent() {
    // ----------------------------------------------
    // LOADING
    // ----------------------------------------------
    if (isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    // ----------------------------------------------
    // NO RESULTS
    // ----------------------------------------------
    if (dishImages.isEmpty) {
      return const Center(child: Text('No pictures found.'));
    }

    // ----------------------------------------------
    // HORIZONTAL PHOTOS
    // ----------------------------------------------
    return ListView.builder(
      scrollDirection: Axis.horizontal,

      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),

      itemCount: dishImages.length,

      itemBuilder: (context, index) {
        final dish = dishImages[index];

        return Container(
          width: 150,

          margin: const EdgeInsets.only(right: 12),

          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),

            child: Image.network(
              dish.url,

              fit: BoxFit.cover,

              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                return Container(
                  color: Colors.grey.shade200,

                  child: const Center(child: CircularProgressIndicator()),
                );
              },

              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade200,

                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 36,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

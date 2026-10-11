import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/services/menu_phrase_service.dart';
import '../models/dish_image.dart';
import '../painters/menu_highlight_painter.dart';

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

  // Optional dish metadata.
  final String? dishPrice;
  final String? dishDescription;
  final String? dishTranslation;

  // Translation controls.
  final VoidCallback? onTranslate;
  final bool isTranslating;

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
    this.dishPrice,
    this.dishDescription,
    this.dishTranslation,
    this.onTranslate,
    this.isTranslating = false,
  });

  bool get _showDishCard =>
      selectedDish.isNotEmpty || dishImages.isNotEmpty || isSearching;

  bool get _hasTranslation =>
      dishTranslation != null && dishTranslation!.trim().isNotEmpty;

  bool get _hasDescription =>
      dishDescription != null && dishDescription!.trim().isNotEmpty;

  bool get _hasPrice => dishPrice != null && dishPrice!.trim().isNotEmpty;

  // ==================================================
  // MAIN SCREEN
  // ==================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildMenuImage()),

            Positioned(top: 12, left: 12, child: _buildExitButton()),

            if (_showDishCard)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _buildDishCard(context),
              ),
          ],
        ),
      ),
    );
  }

  // ==================================================
  // MENU IMAGE WITH OCR HIGHLIGHTS
  // ==================================================

  Widget _buildMenuImage() {
    return Center(
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 5.0,
        boundaryMargin: const EdgeInsets.all(100),
        child: AspectRatio(
          aspectRatio: imageSize.width / imageSize.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final displayedSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  onMenuTap(details.localPosition, displayedSize);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(image, fit: BoxFit.fill),
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
    );
  }

  // ==================================================
  // EXIT BUTTON
  // ==================================================

  Widget _buildExitButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onExit,
        tooltip: 'Back to camera',
        icon: const Icon(Icons.close, color: Colors.white),
      ),
    );
  }

  // ==================================================
  // FIXED BOTTOM DISH CARD
  // ==================================================

  Widget _buildDishCard(BuildContext context) {
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical -
        24;

    final cardHeight = (availableHeight * 0.40).clamp(0.0, 340.0).toDouble();

    return Material(
      color: const Color(0xFFFAF8F4),
      elevation: 16,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: cardHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dish name, translation button, close button.
            _buildDishHeader(),

            // Scrollable description and translation.
            if (_hasDescription || _hasTranslation)
              Flexible(flex: 2, child: _buildDishDetails()),

            // Dish photos.
            Expanded(flex: 4, child: _buildPhotoGallery()),

            // Price.
            _buildPriceFooter(),
          ],
        ),
      ),
    );
  }

  // ==================================================
  // DISH HEADER
  // ==================================================

  Widget _buildDishHeader() {
    // The translation service returns:
    // Line 1: translated dish name
    // Line 2: translated description (if available)
    final translatedName = dishTranslation?.trim().split('\n').first.trim();

    final displayName = translatedName != null && translatedName.isNotEmpty
        ? translatedName
        : selectedDish;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              displayName.isEmpty ? 'Dish Photos' : displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                height: 1.15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF252525),
              ),
            ),
          ),

          const SizedBox(width: 4),

          _buildTranslateButton(),

          IconButton(
            onPressed: onCloseDishPhotos,
            tooltip: 'Close dish card',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, color: Color(0xFF555555)),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // TRANSLATE BUTTON
  // ==================================================

  Widget _buildTranslateButton() {
    final isTranslated = _hasTranslation;

    return TextButton(
      onPressed: isTranslating ? null : onTranslate,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF555555),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        minimumSize: const Size(36, 36),
        visualDensity: VisualDensity.compact,
      ),
      child: isTranslating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF555555),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isTranslated ? Icons.check_circle_outline : Icons.translate,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  isTranslated ? 'Translated' : 'Translate',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  // ==================================================
  // DISH DESCRIPTION + TRANSLATION
  // ==================================================

  Widget _buildDishDetails() {
    final translatedParts = dishTranslation?.trim().split('\n') ?? [];

    // Skip the first line, which is the translated dish name.
    final translatedDescription = translatedParts.length > 1
        ? translatedParts.skip(1).join('\n').trim()
        : '';

    final displayDescription = translatedDescription.isNotEmpty
        ? translatedDescription
        : dishDescription ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Text(
        displayDescription,
        style: const TextStyle(
          fontSize: 12,
          height: 1.4,
          color: Color(0xFF66615C),
        ),
      ),
    );
  }

  // ==================================================
  // HORIZONTAL PHOTO GALLERY
  // ==================================================

  Widget _buildPhotoGallery() {
    if (isSearching) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text(
              'Finding dish photos...',
              style: TextStyle(fontSize: 12, color: Color(0xFF77736E)),
            ),
          ],
        ),
      );
    }

    if (dishImages.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0EDE7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.restaurant_outlined,
                size: 30,
                color: Color(0xFFAAA49C),
              ),
              SizedBox(height: 6),
              Text(
                'No dish photos found',
                style: TextStyle(fontSize: 12, color: Color(0xFF77736E)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: dishImages.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final dish = dishImages[index];

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 1.3,
            child: Image.network(
              dish.url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) {
                  return child;
                }

                return const ColoredBox(
                  color: Color(0xFFF0EDE7),
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(
                  color: Color(0xFFF0EDE7),
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey,
                      size: 30,
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

  // ==================================================
  // PRICE FOOTER
  // ==================================================

  Widget _buildPriceFooter() {
    if (!_hasPrice) {
      return const SizedBox(height: 12);
    }

    final formattedPrice =
        '\$${dishPrice!.trim().replaceFirst(RegExp(r'^\$'), '')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Menu price',
            style: TextStyle(fontSize: 12, color: Color(0xFF77736E)),
          ),
          Text(
            formattedPrice,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF252525),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/dish_image.dart';

class DishPhotos extends StatelessWidget {
  final String selectedDish;
  final List<DishImage> dishImages;
  final bool isSearching;

  final VoidCallback onClose;

  const DishPhotos({
    super.key,
    required this.selectedDish,
    required this.dishImages,
    required this.isSearching,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedDish.isEmpty && dishImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),

      child:
          // ------------------------------------------
          // MAIN CONTENT
          // ------------------------------------------
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------
              // HEADER
              // ------------------------------------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),

                    Expanded(
                      child: Text(
                        selectedDish.isEmpty
                            ? 'No Dish Pictures'
                            : selectedDish,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ------------------------------------------
              // IMAGES
              // ------------------------------------------
              Expanded(
                child: isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : dishImages.isEmpty
                    ? const Center(child: Text('No pictures found.'))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,

                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),

                        itemCount: dishImages.length,

                        itemBuilder: (context, index) {
                          final dish = dishImages[index];

                          return Container(
                            width: 130,

                            margin: const EdgeInsets.only(right: 12),

                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),

                              child: Image.network(
                                dish.url,
                                fit: BoxFit.cover,

                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) {
                                        return child;
                                      }

                                      return Container(
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    },

                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 32,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
    );
  }
}

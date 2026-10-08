import 'dart:ui' show Rect;

class MenuItem {
  final String name;
  final double? price;
  final String? description;

  final Rect nameBoundingBox;
  final Rect? priceBoundingBox;
  final Rect? descriptionBoundingBox;

  MenuItem({
    required this.name,
    required this.nameBoundingBox,
    this.price,
    this.priceBoundingBox,
    this.description,
    this.descriptionBoundingBox,
  });
}

import 'dart:math' as math;

import 'menu_phrase_service.dart';

class MenuColumn {
  final double left;
  final double right;
  final List<MenuPhrase> phrases;

  const MenuColumn({
    required this.left,
    required this.right,
    required this.phrases,
  });
}

class MenuColumnService {
  static const int maxColumns = 3;
  static const int minPhrases = 8;

  // Minimum share of phrases required on each
  // side of a proposed split.
  static const double minSideRatio = 0.15;

  // Maximum fraction of phrases allowed to
  // cross a proposed separator.
  static const double maxCrossingRatio = 0.12;

  // ==================================================
  // PUBLIC API
  // ==================================================

  List<MenuColumn> detectColumns(List<MenuPhrase> phrases) {
    if (phrases.isEmpty) return [];

    final groups = <List<MenuPhrase>>[
      [...phrases],
    ];

    // Repeatedly split the region with the
    // strongest available separator.
    while (groups.length < maxColumns) {
      int? bestGroupIndex;
      _ColumnSplit? bestSplit;

      for (var i = 0; i < groups.length; i++) {
        final group = groups[i];

        if (group.length < minPhrases) {
          continue;
        }

        final split = _findBestSplit(group);

        if (split == null) continue;

        if (bestSplit == null || split.score > bestSplit.score) {
          bestSplit = split;
          bestGroupIndex = i;
        }
      }

      if (bestSplit == null || bestGroupIndex == null) {
        break;
      }

      final group = groups.removeAt(bestGroupIndex);

      final left = <MenuPhrase>[];
      final right = <MenuPhrase>[];

      for (final phrase in group) {
        if (phrase.boundingBox.center.dx < bestSplit.boundary) {
          left.add(phrase);
        } else {
          right.add(phrase);
        }
      }

      if (left.isEmpty || right.isEmpty) {
        groups.insert(bestGroupIndex, group);
        break;
      }

      groups.insert(bestGroupIndex, right);
      groups.insert(bestGroupIndex, left);
    }

    final columns = groups
        .where((group) => group.isNotEmpty)
        .map(_makeColumn)
        .toList();

    columns.sort((a, b) => a.left.compareTo(b.left));

    return columns;
  }

  // ==================================================
  // FIND BEST SPLIT IN A REGION
  // ==================================================

  _ColumnSplit? _findBestSplit(List<MenuPhrase> phrases) {
    if (phrases.length < minPhrases) {
      return null;
    }

    final minX = phrases.map((p) => p.boundingBox.left).reduce(math.min);

    final maxX = phrases.map((p) => p.boundingBox.right).reduce(math.max);

    final width = maxX - minX;

    if (width <= 0) return null;

    _ColumnSplit? best;

    // Test candidate vertical separators.
    for (var step = 15; step <= 85; step++) {
      final x = minX + width * step / 100;

      var leftCount = 0;
      var rightCount = 0;
      var crossingCount = 0;

      double nearestLeft = minX;
      double nearestRight = maxX;

      for (final phrase in phrases) {
        final box = phrase.boundingBox;

        if (box.right < x) {
          leftCount++;

          nearestLeft = math.max(nearestLeft, box.right);
        } else if (box.left > x) {
          rightCount++;

          nearestRight = math.min(nearestRight, box.left);
        } else {
          crossingCount++;
        }
      }

      final total = phrases.length;

      if (leftCount < total * minSideRatio ||
          rightCount < total * minSideRatio) {
        continue;
      }

      final crossingRatio = crossingCount / total;

      if (crossingRatio > maxCrossingRatio) {
        continue;
      }

      // Whitespace between text on both sides.
      final gap = math.max(0.0, nearestRight - nearestLeft);

      final normalizedGap = (gap / width).clamp(0.0, 1.0);

      // Balanced groups are preferable, but
      // whitespace is more important.
      final balance =
          math.min(leftCount, rightCount) / math.max(leftCount, rightCount);

      // Favor clean, wide separators.
      final score =
          normalizedGap * 0.55 + (1 - crossingRatio) * 0.35 + balance * 0.10;

      // Avoid splitting within tightly packed
      // text regions.
      if (normalizedGap < 0.025) {
        continue;
      }

      if (best == null || score > best.score) {
        best = _ColumnSplit(boundary: x, score: score);
      }
    }

    // Reject separators without enough evidence.
    if (best == null || best.score < 0.42) {
      return null;
    }

    return best;
  }

  // ==================================================
  // CREATE COLUMN
  // ==================================================

  MenuColumn _makeColumn(List<MenuPhrase> phrases) {
    final left = phrases.map((p) => p.boundingBox.left).reduce(math.min);

    final right = phrases.map((p) => p.boundingBox.right).reduce(math.max);

    final sorted = [...phrases]
      ..sort((a, b) {
        final dy = a.boundingBox.top.compareTo(b.boundingBox.top);

        return dy != 0 ? dy : a.boundingBox.left.compareTo(b.boundingBox.left);
      });

    return MenuColumn(left: left, right: right, phrases: sorted);
  }
}

// ==================================================
// INTERNAL SPLIT RESULT
// ==================================================

class _ColumnSplit {
  final double boundary;
  final double score;

  const _ColumnSplit({required this.boundary, required this.score});
}

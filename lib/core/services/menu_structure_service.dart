import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'menu_phrase_service.dart';
import 'menu_column_service.dart';

class ParsedMenuItem {
  final MenuPhrase name;
  final String? price;
  final String description;

  const ParsedMenuItem({required this.name, this.price, this.description = ''});
}

class MenuStructureService {
  final MenuPhraseService _phraseService = MenuPhraseService();
  final MenuColumnService _columnService = MenuColumnService();

  // ==================================================
  // PUBLIC API
  // ==================================================

  List<ParsedMenuItem> parse(List<MenuPhrase> phrases) {
    if (phrases.isEmpty) return [];

    final columns = _columnService.detectColumns(phrases);
    final results = <ParsedMenuItem>[];

    for (final column in columns) {
      results.addAll(_parseColumn(column.phrases));
    }

    results.sort((a, b) {
      final dy = a.name.boundingBox.top.compareTo(b.name.boundingBox.top);

      return dy != 0
          ? dy
          : a.name.boundingBox.left.compareTo(b.name.boundingBox.left);
    });

    final uniqueItems = _removeDuplicateItems(results);

    return _fillMissingPricesGlobally(uniqueItems, phrases);
  }

  // ==================================================
  // PARSE COLUMN
  // ==================================================

  List<ParsedMenuItem> _parseColumn(List<MenuPhrase> phrases) {
    if (phrases.isEmpty) return [];

    final sorted = [...phrases]
      ..sort((a, b) {
        final dy = a.boundingBox.top.compareTo(b.boundingBox.top);

        return dy != 0 ? dy : a.boundingBox.left.compareTo(b.boundingBox.left);
      });

    final prices = sorted.where((p) => _phraseService.isPrice(p.text)).toList();

    final texts = sorted.where((p) => !_phraseService.isPrice(p.text)).toList();

    if (texts.isEmpty) return [];

    final used = <MenuPhrase>{};
    final items = <ParsedMenuItem>[];

    // ================================================
    // PASS 1: PRICE-BASED DISH DETECTION
    // ================================================

    for (final price in prices) {
      final heading = _findHeadingForPrice(price, texts, used);

      if (heading == null) continue;

      items.add(ParsedMenuItem(name: heading, price: price.text));

      _markUsed(heading, texts, used);
    }

    // ================================================
    // LEARN HEADING STYLE
    // ================================================

    final style = _learnHeadingStyle(texts, items);

    // ================================================
    // PASS 2: DISHES WITHOUT MATCHED PRICES
    // ================================================

    final candidates = texts.where((phrase) {
      return !used.contains(phrase) && _isHeadingCandidate(phrase.text);
    }).toList();

    candidates.sort((a, b) {
      final scoreA = _headingScore(a, texts, items, style);

      final scoreB = _headingScore(b, texts, items, style);

      return scoreB.compareTo(scoreA);
    });

    for (final candidate in candidates) {
      if (used.contains(candidate)) continue;

      final score = _headingScore(candidate, texts, items, style);

      if (score < 5) continue;

      if (_isStrongDescription(candidate, items, style)) {
        continue;
      }

      items.add(ParsedMenuItem(name: candidate));

      used.add(candidate);
    }

    // ================================================
    // PASS 3: MULTI-LINE DISH NAMES
    // ================================================

    final merged = _mergeHeadingLines(items, texts, used);

    merged.sort((a, b) {
      return a.name.boundingBox.top.compareTo(b.name.boundingBox.top);
    });

    // ================================================
    // PASS 4: DESCRIPTIONS
    // ================================================

    final itemsWithDescriptions = _attachDescriptions(merged, texts, used);

    return _fillMissingPrices(itemsWithDescriptions, prices);
  }

  // ==================================================
  // FIND HEADING NEAR PRICE
  // ==================================================

  MenuPhrase? _findHeadingForPrice(
    MenuPhrase price,
    List<MenuPhrase> phrases,
    Set<MenuPhrase> used,
  ) {
    final priceBox = price.boundingBox;

    MenuPhrase? best;
    var bestScore = double.negativeInfinity;

    for (final phrase in phrases) {
      if (used.contains(phrase)) continue;
      if (!_isHeadingCandidate(phrase.text)) continue;

      final box = phrase.boundingBox;

      final height = math.max(1.0, math.max(box.height, priceBox.height));

      final dy = (box.center.dy - priceBox.center.dy).abs();

      final gap = priceBox.left - box.right;

      if (dy > height * 0.9) continue;

      if (gap < -height * 0.5 || gap > height * 12) {
        continue;
      }

      final verticalScore = 1 - dy / height;
      final horizontalScore = 1 - gap.abs() / (height * 12);

      final score = verticalScore * 3 + horizontalScore;

      if (score > bestScore) {
        bestScore = score;
        best = phrase;
      }
    }

    return best;
  }

  // ==================================================
  // LEARN HEADING STYLE
  // ==================================================

  _HeadingStyle _learnHeadingStyle(
    List<MenuPhrase> phrases,
    List<ParsedMenuItem> items,
  ) {
    final heights =
        phrases.map((p) => p.boundingBox.height).where((h) => h > 0).toList()
          ..sort();

    final headingHeights =
        items
            .where((item) => item.price != null)
            .map((item) => item.name.boundingBox.height)
            .where((h) => h > 0)
            .toList()
          ..sort();

    final typicalHeight = _median(heights);

    final headingHeight = headingHeights.isNotEmpty
        ? _median(headingHeights)
        : typicalHeight;

    return _HeadingStyle(
      headingHeight: headingHeight,
      typicalTextHeight: typicalHeight,
      referenceLefts: items
          .where((item) => item.price != null)
          .map((item) => item.name.boundingBox.left)
          .toList(),
    );
  }

  double _median(List<double> sorted) {
    if (sorted.isEmpty) return 1;

    final middle = sorted.length ~/ 2;

    if (sorted.length.isOdd) {
      return sorted[middle];
    }

    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  // ==================================================
  // HEADING SCORE
  // ==================================================

  int _headingScore(
    MenuPhrase candidate,
    List<MenuPhrase> phrases,
    List<ParsedMenuItem> existing,
    _HeadingStyle style,
  ) {
    if (!_isHeadingCandidate(candidate.text)) {
      return -100;
    }

    var score = 0;

    final box = candidate.boundingBox;
    final height = math.max(1.0, box.height);

    final words = candidate.text.trim().split(RegExp(r'\s+'));

    final ratio = height / math.max(1.0, style.headingHeight);

    if (ratio >= 0.82 && ratio <= 1.35) {
      score += 3;
    } else if (ratio >= 0.70 && ratio <= 1.5) {
      score += 1;
    }

    if (height >= style.typicalTextHeight * 1.12) {
      score += 1;
    }

    if (style.referenceLefts.any((left) {
      return (left - box.left).abs() < height * 2.5;
    })) {
      score += 2;
    }

    if (_hasDescriptionBelow(candidate, phrases)) {
      score += 2;
    }

    if (words.isNotEmpty && words.length <= 6) {
      score += 1;
    }

    final nearbyHeading = existing.any((item) {
      final other = item.name.boundingBox;

      final dy = (other.center.dy - box.center.dy).abs();

      final similarHeight = (other.height - height).abs() < height * 0.25;

      return dy > height && dy < height * 18 && similarHeight;
    });

    if (nearbyHeading) {
      score += 1;
    }

    if (words.length >= 8) {
      score -= 3;
    }

    if (candidate.text.contains(',') && words.length > 4) {
      score -= 3;
    }

    if (height < style.headingHeight * 0.72) {
      score -= 3;
    }

    return score;
  }

  // ==================================================
  // DESCRIPTION BELOW
  // ==================================================

  bool _hasDescriptionBelow(MenuPhrase heading, List<MenuPhrase> phrases) {
    final box = heading.boundingBox;

    for (final phrase in phrases) {
      if (identical(phrase, heading)) continue;

      final other = phrase.boundingBox;
      final gap = other.top - box.bottom;

      if (gap < -box.height * 0.1 || gap > box.height * 2.5) {
        continue;
      }

      final aligned = (other.left - box.left).abs() < box.height * 5;

      final smaller = other.height < box.height * 0.9;

      if (aligned && smaller) {
        return true;
      }
    }

    return false;
  }

  // ==================================================
  // DESCRIPTION PROTECTION
  // ==================================================

  bool _isStrongDescription(
    MenuPhrase candidate,
    List<ParsedMenuItem> items,
    _HeadingStyle style,
  ) {
    final box = candidate.boundingBox;

    if (box.height < style.headingHeight * 0.65) {
      return true;
    }

    if (_looksLikeDescription(candidate.text)) {
      return true;
    }

    for (final item in items) {
      final heading = item.name.boundingBox;

      final gap = box.top - heading.bottom;

      if (gap < 0 || gap > heading.height * 2.5) {
        continue;
      }

      final aligned = (box.left - heading.left).abs() < heading.height * 5;

      final smaller = box.height < heading.height * 0.78;

      if (aligned && smaller) {
        return true;
      }
    }

    return false;
  }

  // ==================================================
  // MULTI-LINE HEADING MERGING
  // ==================================================

  List<ParsedMenuItem> _mergeHeadingLines(
    List<ParsedMenuItem> items,
    List<MenuPhrase> phrases,
    Set<MenuPhrase> used,
  ) {
    final results = <ParsedMenuItem>[];

    for (final item in items) {
      var heading = item.name;
      final box = heading.boundingBox;

      final candidates = phrases.where((p) {
        if (used.contains(p)) return false;
        if (!_isHeadingCandidate(p.text)) return false;

        final other = p.boundingBox;
        final gap = box.top - other.bottom;

        if (gap < -box.height * 0.1 || gap > box.height * 0.45) {
          return false;
        }

        final aligned = (other.left - box.left).abs() < box.height * 1.5;

        final ratio = other.height / math.max(1.0, box.height);

        return aligned && ratio >= 0.88 && ratio <= 1.12;
      }).toList();

      if (candidates.isNotEmpty) {
        candidates.sort((a, b) {
          return b.boundingBox.bottom.compareTo(a.boundingBox.bottom);
        });

        final previous = candidates.first;

        final combined = '${previous.text} ${heading.text}';

        if (combined.split(RegExp(r'\s+')).length <= 8) {
          heading = MenuPhrase(
            text: combined,
            boundingBox: previous.boundingBox.expandToInclude(
              heading.boundingBox,
            ),
          );

          used.add(previous);
        }
      }

      results.add(ParsedMenuItem(name: heading, price: item.price));
    }

    return results;
  }

  // ==================================================
  // ATTACH DESCRIPTIONS
  // ==================================================

  List<ParsedMenuItem> _attachDescriptions(
    List<ParsedMenuItem> items,
    List<MenuPhrase> phrases,
    Set<MenuPhrase> used,
  ) {
    final results = <ParsedMenuItem>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final box = item.name.boundingBox;

      final nextTop = i + 1 < items.length
          ? items[i + 1].name.boundingBox.top
          : double.infinity;

      final descriptions =
          phrases.where((p) {
            if (used.contains(p)) return false;

            if (_isSectionHeading(p.text) || _isNonDishText(p.text)) {
              return false;
            }

            final other = p.boundingBox;

            if (other.top < box.bottom || other.top >= nextTop) {
              return false;
            }

            if (other.top - box.bottom > box.height * 5) {
              return false;
            }

            if ((other.left - box.left).abs() > box.height * 6) {
              return false;
            }

            if (other.height > box.height * 1.05) {
              return false;
            }

            return true;
          }).toList()..sort((a, b) {
            return a.boundingBox.top.compareTo(b.boundingBox.top);
          });

      results.add(
        ParsedMenuItem(
          name: item.name,
          price: item.price,
          description: descriptions.map((p) => p.text).join(' '),
        ),
      );
    }

    return results;
  }

  // ==================================================
  // MARK USED
  // ==================================================

  void _markUsed(
    MenuPhrase heading,
    List<MenuPhrase> phrases,
    Set<MenuPhrase> used,
  ) {
    for (final phrase in phrases) {
      final intersection = phrase.boundingBox.intersect(heading.boundingBox);

      if (intersection.isEmpty) continue;

      final area = phrase.boundingBox.width * phrase.boundingBox.height;

      if (area <= 0) continue;

      final overlap = intersection.width * intersection.height;

      if (overlap / area > 0.7) {
        used.add(phrase);
      }
    }
  }

  // ==================================================
  // REMOVE DUPLICATES
  // ==================================================

  List<ParsedMenuItem> _removeDuplicateItems(List<ParsedMenuItem> items) {
    final results = <ParsedMenuItem>[];

    for (final item in items) {
      final duplicate = results.any((existing) {
        final sameName =
            existing.name.text.trim().toUpperCase() ==
            item.name.text.trim().toUpperCase();

        final a = existing.name.boundingBox;
        final b = item.name.boundingBox;

        final distance = (a.center - b.center).distance;

        final nearby = distance < math.max(a.height, b.height) * 3;

        return sameName && nearby;
      });

      if (!duplicate) {
        results.add(item);
      }
    }

    return results;
  }

  // ==================================================
  // HEADING VALIDATION
  // ==================================================

  bool _isHeadingCandidate(String text) {
    final value = text.trim();

    if (value.length < 3) return false;

    if (!RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(value)) {
      return false;
    }

    if (_isSectionHeading(value)) return false;
    if (_isAddOn(value)) return false;
    if (_isNonDishText(value)) return false;
    if (_looksLikeDescription(value)) return false;

    return true;
  }

  // ==================================================
  // SECTION HEADINGS
  // ==================================================

  bool _isSectionHeading(String text) {
    var value = text.toUpperCase();

    // Normalize observed OCR character errors.
    value = value.replaceAll('Ụ', 'U').replaceAll('Ọ', 'O');

    value = value.replaceAll(RegExp(r'[^A-Z]'), '');

    const sections = {
      'APPETIZER',
      'APPETIZERS',
      'STARTER',
      'STARTERS',
      'MAINDISH',
      'MAINDISHES',
      'HOUSE',
      'SPECIALTY',
      'SPECIALTIES',
      'SYROOIATIY',
      'HOUSESPECIALTY',
      'HOUSESPECIALTIES',
      'SOUPCURRY',
      'SOUPS',
      'CURRIES',
      'NOODLES',
      'FRIEDRICE',
      'DRINK',
      'DRINKS',
      'DESSERT',
      'DESSERTS',
      'ANTIPASTI',
      'CONTORNI',
      'INSALATA',
      'SECONDI',
      'DOLCI',
      'SMALLPLATES',
      'LARGEPLATES',
      'SIDES',
      'SALADS',
    };

    if (sections.contains(value)) return true;

    if (value.startsWith('APPETI') && value.length <= 12) {
      return true;
    }

    if (value.startsWith('HOUSE') && value.length <= 18) {
      return true;
    }

    if (value.startsWith('SPECIALT') && value.length <= 14) {
      return true;
    }

    return false;
  }

  // ==================================================
  // ADD-ONS
  // ==================================================

  bool _isAddOn(String text) {
    final value = text.trim().toUpperCase().replaceFirst(
      RegExp(r'^[^A-Z]+'),
      '',
    );

    return value.startsWith('SIDE OF ') ||
        value.startsWith('ADD ') ||
        value.startsWith('EXTRA ') ||
        value.startsWith('ORGANIC CHICKEN');
  }

  // ==================================================
  // DESCRIPTIONS
  // ==================================================

  bool _looksLikeDescription(String text) {
    final value = text.trim().toUpperCase();

    if (value.isEmpty) return true;

    if (','.allMatches(value).length >= 2) {
      return true;
    }

    const prefixes = [
      'TOPPED WITH',
      'SERVED WITH',
      'WITH CHICKEN',
      'WITH PORK',
      'OR BEEF',
      'OR SHRIMP',
      'OR PORK',
      'CHICKEN OR',
      'FRIED OR STEAMED',
      'THAI SPICY',
      'THAI HOT',
      'THAI FRIED',
      'CHINESE BROCCOLI WITH',
      'FRIED RICE CHICKEN',
      'SPICY BASIL GROUND',
      'VERY FRAGRANT',
      'AROMATICS',
      'AN AROMATIC',
      'CRISPY PORK WITH',
      'CRISPY PORK WTTH',
      'MARINATED ',
      'PICKLED ',
      'REFRIED BEANS',
      'AGED BALSAMIC',
      '2 ORGANIC EGGS',
      '8 OZ.',
    ];

    for (final prefix in prefixes) {
      if (value.startsWith(prefix)) {
        return true;
      }
    }

    if (RegExp(r'^(PAIR|PAIRED|PA[IL1]R)\b').hasMatch(value)) {
      return true;
    }

    return false;
  }

  // ==================================================
  // NON-DISH TEXT
  // ==================================================

  bool _isNonDishText(String text) {
    final value = text.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

    if (value.isEmpty) return true;

    // Web/image metadata.
    if (RegExp(r'(PHOTO FOR|YELP\.COM|HTTPS?://|WWW\.)').hasMatch(value)) {
      return true;
    }

    // Add-ons.
    if (RegExp(r'^[^A-Z]{0,2}(ADD|EXTRA|SIDE OF)\b').hasMatch(value)) {
      return true;
    }

    // Quantity-only descriptions.
    if (RegExp(r'^\(?\d+\s*(PIECES?|PCS?)\)?$').hasMatch(value)) {
      return true;
    }

    // Protein choices and substitutions.
    if (RegExp(r'^(OR |CHICKEN OR |BEEF OR |PORK OR )').hasMatch(value)) {
      return true;
    }

    // Standalone fragments.
    const fragments = {
      'BEEF',
      'OR MORE',
      'COMBINATION',
      "KWAN'S",
      'SOLO',
      'FEAST',
    };

    if (fragments.contains(value)) {
      return true;
    }

    // Footer or metadata.
    if (value.contains('GRATUITY') ||
        value.contains('FOLLOW & TAG') ||
        value.contains('MENU SUBJECT TO')) {
      return true;
    }

    return false;
  }
}

// ==================================================
// HEADING STYLE REFERENCE
// ==================================================

class _HeadingStyle {
  final double headingHeight;
  final double typicalTextHeight;
  final List<double> referenceLefts;

  const _HeadingStyle({
    required this.headingHeight,
    required this.typicalTextHeight,
    required this.referenceLefts,
  });
}

List<ParsedMenuItem> _fillMissingPrices(
  List<ParsedMenuItem> items,
  List<MenuPhrase> prices,
) {
  final usedPrices = <MenuPhrase>{};

  // Reserve prices already associated with dishes.
  for (final item in items) {
    if (item.price == null) continue;

    final matching = prices.where((price) => price.text == item.price).toList();

    if (matching.isEmpty) continue;

    matching.sort((a, b) {
      final distanceA =
          (a.boundingBox.center.dy - item.name.boundingBox.center.dy).abs();

      final distanceB =
          (b.boundingBox.center.dy - item.name.boundingBox.center.dy).abs();

      return distanceA.compareTo(distanceB);
    });

    usedPrices.add(matching.first);
  }

  final results = <ParsedMenuItem>[];

  for (final item in items) {
    if (item.price != null) {
      results.add(item);
      continue;
    }

    final dishBox = item.name.boundingBox;

    MenuPhrase? bestPrice;
    var bestScore = double.infinity;

    for (final price in prices) {
      if (usedPrices.contains(price)) continue;

      final priceBox = price.boundingBox;

      // Price should appear to the right of the dish.
      if (priceBox.center.dx <= dishBox.center.dx) {
        continue;
      }

      final height = math.max(dishBox.height, priceBox.height);

      if (height <= 0) continue;

      final verticalDistance = (dishBox.center.dy - priceBox.center.dy).abs();

      // Allow modest OCR vertical misalignment.
      if (verticalDistance > height * 1.3) {
        continue;
      }

      final horizontalGap = priceBox.left - dishBox.right;

      if (horizontalGap < -height * 0.5 || horizontalGap > height * 12) {
        continue;
      }

      final score =
          verticalDistance / height + horizontalGap.abs() / (height * 12);

      if (score < bestScore) {
        bestScore = score;
        bestPrice = price;
      }
    }

    if (bestPrice != null) {
      usedPrices.add(bestPrice);

      results.add(
        ParsedMenuItem(
          name: item.name,
          price: bestPrice.text,
          description: item.description,
        ),
      );
    } else {
      results.add(item);
    }
  }

  return results;
}

List<ParsedMenuItem> _fillMissingPricesGlobally(
  List<ParsedMenuItem> items,
  List<MenuPhrase> allPhrases,
) {
  // Collect prices from ALL columns.
  final prices = allPhrases
      .where((p) => MenuPhraseService().isPrice(p.text))
      .toList();

  final usedPrices = <MenuPhrase>{};

  // Reserve prices already assigned to dishes.
  for (final item in items) {
    if (item.price == null) continue;

    final candidates = prices
        .where(
          (p) => p.text.trim() == item.price!.trim() && !usedPrices.contains(p),
        )
        .toList();

    if (candidates.isEmpty) continue;

    candidates.sort((a, b) {
      final da =
          (a.boundingBox.center - item.name.boundingBox.center).distanceSquared;
      final db =
          (b.boundingBox.center - item.name.boundingBox.center).distanceSquared;

      return da.compareTo(db);
    });

    usedPrices.add(candidates.first);
  }

  final updated = <ParsedMenuItem>[];

  for (final item in items) {
    if (item.price != null) {
      updated.add(item);
      continue;
    }

    final dishBox = item.name.boundingBox;

    MenuPhrase? bestPrice;
    double bestScore = double.infinity;

    for (final price in prices) {
      if (usedPrices.contains(price)) continue;

      final priceBox = price.boundingBox;

      final rowHeight = math.max(dishBox.height, priceBox.height);

      if (rowHeight <= 0) continue;

      final verticalDistance = (dishBox.center.dy - priceBox.center.dy).abs();

      // Price must be on approximately the same row.
      if (verticalDistance > rowHeight * 1.5) {
        continue;
      }

      final horizontalGap = priceBox.left - dishBox.right;

      // Allow minor overlap due to OCR bounding boxes.
      if (horizontalGap < -rowHeight * 0.5) {
        continue;
      }

      // Limit how far right a price can be.
      if (horizontalGap > rowHeight * 14) {
        continue;
      }

      final score =
          verticalDistance / rowHeight + horizontalGap.abs() / (rowHeight * 14);

      if (score < bestScore) {
        bestScore = score;
        bestPrice = price;
      }
    }

    if (bestPrice != null) {
      usedPrices.add(bestPrice);

      debugPrint(
        'PRICE RECOVERED: ${item.name.text} '
        '-> ${bestPrice.text}',
      );

      updated.add(
        ParsedMenuItem(
          name: item.name,
          price: bestPrice.text,
          description: item.description,
        ),
      );
    } else {
      updated.add(item);
    }
  }

  return updated;
}

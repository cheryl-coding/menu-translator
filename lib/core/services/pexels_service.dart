import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../features/menu_scanner/models/dish_image.dart';

class PexelsService {
  // --------------------------------------------------
  // API
  // --------------------------------------------------

  final String _pexelsApiKey = dotenv.env['PEXELS_API_KEY'] ?? '';

  Future<List<DishImage>> searchDish(String dishName) async {
    if (_pexelsApiKey.isEmpty) {
      throw Exception('PEXELS_API_KEY is missing from your .env file.');
    }

    final Uri uri = Uri.https('api.pexels.com', '/v1/search', {
      'query': dishName,
      'per_page': '10',
    });

    final response = await http.get(
      uri,
      headers: {'Authorization': _pexelsApiKey},
    );

    if (response.statusCode != 200) {
      throw Exception('Pexels returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    final List<dynamic> photos = data['photos'] ?? [];

    final results = photos.map<DishImage>((photo) {
      final src = photo['src'];

      return DishImage(
        title: dishName,
        url: src['medium'] ?? src['original'],
        pexelsUrl: photo['url'] ?? '',
        photographer: photo['photographer'] ?? '',
      );
    }).toList();
    return results;
  }
}

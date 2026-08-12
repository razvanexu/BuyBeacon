import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:buy_beacon/models/category_option.dart';
import 'package:buy_beacon/models/product.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/shop_location.dart';

class ApiService {
  //singleton instance
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  ApiService._internal();

  // The Spring Boot backend's base URL. Override at build/run time with
  // --dart-define=API_BASE_URL=http://<your-machine-ip>:8080 instead of
  // editing this default (e.g. 10.0.2.2 is the Android emulator's alias
  // for the host machine's localhost; a physical device needs the host's
  // LAN IP).
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.180:8080',
  );

  Future<List<ShopLocation>> findShops(
    List<Product> products, {
    double? latitude,
    double? longitude,
  }) async {
    if (products.isEmpty) {
      log('findShops called with no products. Returning empty list.', name: 'ApiService');
      return [];
    }
    //endpoint
    final url = Uri.parse('$_baseUrl/api/shops/find');

    //extract product names
    final productNames = products.map((p) => p.name).toList();

    //create and encode request body to json
    final body = jsonEncode({
      'products': productNames,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });

    log('Sending POST ${url.path} with ${productNames.length} product(s).', name: 'ApiService');
    if (kDebugMode) {
      log('  Body: $body', name: 'ApiService');
    }

    try {
      final response = await http
          .post(url, headers: {'Content-type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));

      log(
        'Received HTTP Response: ${response.statusCode}',
        name: 'ApiService',
      );
      if (kDebugMode) {
        log('  Body: ${response.body}', name: 'ApiService');
      }

      if (response.statusCode == 200) {
        //if success code, parse json
        try {
          final List<dynamic> decodedJson = jsonDecode(response.body);
          log(
            'Received successful response with ${decodedJson.length} locations.',
            name: 'ApiService',
          );

          final locations = decodedJson
              .map((json) {
                try {
                  return ShopLocation.fromMap(json);
                } catch (e, stackTrace) {
                  log(
                    'Error parsing a single ShopLocation object: $json',
                    name: 'ApiService',
                    error: e,
                    stackTrace: stackTrace,
                  );
                  return null;
                }
              })
              .where((location) => location != null)
              .cast<ShopLocation>()
              .toList();

          log('Successfully parsed ${locations.length} locations.', name: 'ApiService');
          return locations;
        } catch (e, stackTrace) {
          log(
            'Error decoding or parsing the JSON response body.',
            name: 'ApiService',
            error: e,
            stackTrace: stackTrace,
          );
          rethrow;
        }
      } else {
        log(
          'API request failed with status: ${response.statusCode}.',
          name: 'ApiService',
          error: 'Response body: ${response.body}',
        );
        throw ApiException('API request failed with status: ${response.statusCode}');
      }
    } on TimeoutException catch (e, stackTrace) {
      log(
        'The request to the backend timed out.',
        error: e,
        stackTrace: stackTrace,
        name: 'ApiService',
      );
      rethrow;
    } catch (e, stackTrace) {
      log(
        'An exception occurred calling findShops API.',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Looks up the crowdsourced category for a product. Returns null if the
  /// product has no submissions yet (i.e. the frontend should prompt the user
  /// to pick one via [saveProductCategory]).
  Future<String?> getProductCategory(String product) async {
    final url = Uri.parse(
      '$_baseUrl/api/products/category',
    ).replace(queryParameters: {'product': product});

    log('Sending GET ${url.path} for product "$product".', name: 'ApiService');

    final response = await http.get(url).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw ApiException('getProductCategory failed with status: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final known = decoded['known'] as bool;
    return known ? decoded['category'] as String : null;
  }

  /// Submits a category choice for a product. The backend keeps every
  /// submission and resolves the active category by majority vote, so this
  /// never overwrites a previous submission outright.
  Future<void> saveProductCategory(String product, String category) async {
    final url = Uri.parse('$_baseUrl/api/products/category');
    final body = jsonEncode({'product': product, 'category': category});

    log('Sending POST ${url.path} for product "$product" -> "$category".', name: 'ApiService');

    final response = await http
        .post(url, headers: {'Content-type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw ApiException('saveProductCategory failed with status: ${response.statusCode}');
    }
  }

  /// Fetches the fixed, closed list of categories a user can pick from.
  Future<List<CategoryOption>> getCategoryOptions() async {
    final url = Uri.parse('$_baseUrl/api/products/categories');

    log('Sending GET ${url.path}.', name: 'ApiService');

    final response = await http.get(url).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw ApiException('getCategoryOptions failed with status: ${response.statusCode}');
    }

    final List<dynamic> decoded = jsonDecode(response.body);
    return decoded.map((json) => CategoryOption.fromMap(json)).toList();
  }
}

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

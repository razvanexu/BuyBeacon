import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:frontend/models/product.dart';
import 'package:http/http.dart' as http;

import '../models/shop_location.dart';

class ApiService{
  //singleton instance
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // --- IMPORTANT ---
  // The base URL for your Spring Boot backend.
  // For the Android Emulator, 10.0.2.2 is a special alias that points to
  // the host machine's localhost (i.e., your computer).
  // If using a physical Android device, replace this with your computer's
  // local network IP address (e.g., 'http://192.168.1.100:8080').
  final String _baseUrl = 'http://192.168.0.180:8080';

  Future<List<ShopLocation>> findShops(List<Product> products) async {
    if(products.isEmpty){
      log('findShops called with no products. Returning empty list.', name: 'ApiService');
      return [];
    }
    //endpoint
    final url = Uri.parse('$_baseUrl/api/shops/find');

    //extract product names
    final productNames = products.map((p) => p.name).toList();

    //create and encode request body to json
    final body = jsonEncode({
      'products': productNames});

    // Log the full request object before sending
    final request = http.Request('POST', url)
      ..headers['Content-type'] = 'application/json'
      ..body = body;
    log('Sending HTTP Request: ${request.method} ${request.url}', name: 'ApiService');
    request.headers.forEach((key, value) => log('  Header: $key = $value', name: 'ApiService'));
    log('  Body: ${request.body}', name: 'ApiService');

    log('Sending POST request to $url with body: $body', name: 'ApiService');

    try {
      final response = await http.post(
          url,
          headers: {
            'Content-type': 'application/json'
          },
          body: body
      ).timeout(const Duration(seconds: 30));

      // Log the full response object after receiving
      log('Received HTTP Response:', name: 'ApiService');
      log('  Status Code: ${response.statusCode}', name: 'ApiService');
      response.headers.forEach((key, value) => log('  Header: $key = $value', name: 'ApiService'));
      log('  Body: ${response.body}', name: 'ApiService');

      if (response.statusCode == 200) {
        log('Raw response body: ${response.body}', name: 'ApiService');
        //if success code, parse json
        try {
          final List<dynamic> decodedJson = jsonDecode(response.body);
          log('Received successful response with ${decodedJson
              .length} locations.', name: 'ApiService');

          final locations = decodedJson.map((json) {
            try {
              return ShopLocation.fromMap(json);
            } catch (e, stackTrace) {
              log('Error parsing a single ShopLocation object: $json',
                  name: 'ApiService', error: e, stackTrace: stackTrace);
              return null;
            }
          })
              .where((location) => location != null)
              .cast<ShopLocation>()
              .toList();

          log('Successfully parsed ${locations.length} locations.',
              name: 'ApiService');
          return locations;
        }catch(e, stackTrace) {
            log('Error decoding or parsing the JSON response body.',
                name: 'ApiService', error: e, stackTrace: stackTrace);
            return [];
        }
        //   return decodedJson.map((json) => ShopLocation.fromMap(json)).toList();
        }else{
          log(
            'API request failed with status: ${response.statusCode}.',
            name: 'ApiService',
            error: 'Response body: ${response.body}'
          );
          return [];
      }
    }on TimeoutException catch(e, stackTrace){
      log('The request to the backend timed out.',
          error: e, stackTrace: stackTrace, name: 'ApiService');
      return [];
    }catch(e, stackTrace){
      log(
        'An exception occurred calling findShops API.',
        error: e,
        stackTrace: stackTrace
      );
      return [];
    }
  }
}
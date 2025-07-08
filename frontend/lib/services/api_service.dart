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
  final String _baseUrl = 'http://10.0.2.2:8080';

  Future<List<ShopLocation>> findShops(List<Product> products) async {
    if(products.isEmpty){
      log('findShops called with no products. Returning empty list.', name: 'ApiService');
      return [];
    }
    //endpoint
    final url = Uri.parse('$_baseUrl/api/reminders');

    //extract product names
    final productNames = products.map((p) => p.name).toList();

    //create and encode request body to json
    final body = jsonEncode({
      'products': productNames});

    log('Sending POST request to $url with body: $body', name: 'ApiService');

    try{
      final response = await http.post(
          url,
          headers: {
            'Content-type': 'application/json'
          },
          body: body
      );

      if(response.statusCode == 200){
        //if success code, parse json
        final List<dynamic> decodedJson = jsonDecode(response.body);
        log('Received successful response with ${decodedJson.length} locations.', name: 'ApiService');
        return decodedJson.map((json) => ShopLocation.fromMap(json)).toList();
      }else{
        log(
          'API request failed with status: ${response.statusCode}.',
          name: 'ApiService',
          error: 'Response body: ${response.body}'
        );
        return [];
      }
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
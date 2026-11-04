import 'package:buy_beacon/models/shop_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses discovery source and evidence from backend response', () {
    final shop = ShopLocation.fromMap({
      'storeName': 'Feroneria din cartier',
      'latitude': 44.4,
      'longitude': 26.1,
      'products': ['cuie'],
      'source': 'openstreetmap',
      'matchConfidence': 'CATEGORY_MATCH',
    });

    expect(shop.isOpenStreetMap, isTrue);
    expect(shop.isRetailerCatalogMatch, isFalse);
    expect(shop.evidenceLabel, 'Magazin potrivit după categorie');
  });

  test('remains compatible with responses that omit the new metadata', () {
    final shop = ShopLocation.fromMap({
      'storeName': 'Magazin',
      'latitude': 44,
      'longitude': 26,
      'products': <String>[],
    });

    expect(shop.source, 'unknown');
    expect(shop.matchConfidence, 'CATEGORY_MATCH');
  });
}

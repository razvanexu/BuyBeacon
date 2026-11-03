class ShopLocation {
  final String name;
  final double latitude;
  final double longitude;
  final List<String> products;
  final String source;
  final String matchConfidence;

  ShopLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.products,
    this.source = 'unknown',
    this.matchConfidence = 'CATEGORY_MATCH',
  });

  bool get isOpenStreetMap => source == 'openstreetmap';

  bool get isRetailerCatalogMatch => matchConfidence == 'RETAILER_CATALOG';

  String get evidenceLabel => isRetailerCatalogMatch
      ? 'Produs găsit în catalogul retailerului'
      : 'Magazin potrivit după categorie';

  factory ShopLocation.fromMap(Map<String, dynamic> map) {
    return ShopLocation(
      name: map['storeName'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      products: List<String>.from(map['products'] as List<dynamic>),
      source: map['source'] as String? ?? 'unknown',
      matchConfidence: map['matchConfidence'] as String? ?? 'CATEGORY_MATCH',
    );
  }
}

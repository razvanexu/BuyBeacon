class ShopLocation{
  final String name;
  final double latitude;
  final double longitude;
  final List<String> products;

  ShopLocation({required this.name, required this.latitude, required this.longitude, required this.products});

  factory ShopLocation.fromMap(Map<String, dynamic> map){
    return ShopLocation(
        name: map['storeName'] as String,
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        products: List<String>.from(map['products'] as List<dynamic>)
    );
  }
}
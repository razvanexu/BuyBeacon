class ShopLocation{
  final double latitude;
  final double longitude;

  ShopLocation({required this.latitude, required this.longitude});

  factory ShopLocation.fromMap(Map<String, dynamic> map){
    return ShopLocation(
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double
    );
  }
}
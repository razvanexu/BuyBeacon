import 'package:buy_beacon/models/shop_location.dart';

class ShoppingState {
  final List<ShopLocation> shopLocations;
  final bool isLoading;
  final bool hasConnectionError;

  ShoppingState({
    this.shopLocations = const [],
    this.isLoading = false,
    this.hasConnectionError = false,
  });

  ShoppingState copyWith({
    List<ShopLocation>? shopLocations,
    bool? isLoading,
    bool? hasConnectionError,
  }) {
    return ShoppingState(
      shopLocations: shopLocations ?? this.shopLocations,
      isLoading: isLoading ?? this.isLoading,
      hasConnectionError: hasConnectionError ?? this.hasConnectionError,
    );
  }
}

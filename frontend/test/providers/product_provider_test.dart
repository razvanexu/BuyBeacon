
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/database_service.dart';
import 'package:frontend/services/location_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'product_provider_test.mocks.dart';

@GenerateMocks([DatabaseService, ApiService, LocationService, ProductProvider])
void main(){
  late ProductProvider productProvider;
  late MockDatabaseService mockDatabaseService;
  late MockApiService mockApiService;
  late MockLocationService mockLocationService;

  setUp((){
    mockDatabaseService = MockDatabaseService();
    mockApiService = MockApiService();
    mockLocationService = MockLocationService();

    productProvider = ProductProvider(
      dbService: mockDatabaseService,
      api: mockApiService,
      location: mockLocationService
    );
  });

  test('addProduct should call database, fetch products and update geofences', ()async{
    const productName = 'Test Coffee';

    // ARRANGE

    //When the provider initializes, it calls fetchProducts, which calls getProducts.
    // Mocking initial call.
    when(mockDatabaseService.getProducts()).thenAnswer((_) async => []);
    //initialize location service
    when(mockLocationService.initialize()).thenAnswer((_) async => {});
    //find shops should be empty, initially
    when(mockApiService.findShops(any)).thenAnswer((_) async => []);

    //Setup up the mock for the state after the product is added
    when(mockDatabaseService.addProduct(any)).thenAnswer((_) async => 1);
    //When "getProducts()" is called AFTER adding, return the new list
    when(mockDatabaseService.getProducts()).thenAnswer((_) async => [Product(id: 1, name: productName)]);

    //ACT
    await productProvider.addProduct(productName);

    //ASSERT
    verify(mockDatabaseService.addProduct(argThat(predicate<Product>((p) => p.name == productName)))).called(1);
    //getProducts() is called twice - once on init and once after adding
    verify(mockDatabaseService.getProducts()).called(2);
    expect(productProvider.products.length, 1);
    expect(productProvider.products.first.name, productName);
    verify(mockApiService.findShops(any)).called(1);
  });

  test('addProduct should still succeed locally even if ApiService fails', ()async{
    //ARRANGE
    const productName = 'another product';

    //Mock successfull db operations
    when(mockDatabaseService.addProduct(any)).thenAnswer((_) async => 1);
    when(mockDatabaseService.getProducts()).thenAnswer((_) async => [Product(id: 1, name: productName)]);

    //Mock location service initialization
    when(mockLocationService.initialize()).thenAnswer((_) async => {});

    //mockApiService throws exception when findShops is called
    when(mockApiService.findShops(any)).thenThrow(Exception('Network Error: 503 Service Unavailable'));

    //ACT
    await productProvider.addProduct(productName);

    //ASSERT
    //verify that product was still added successfully
    verify(mockDatabaseService.addProduct(any)).called(1);

    //verify UI was still updated successfully
    expect(productProvider.products.length, 1);
    expect(productProvider.products.first.name, productName);

    //verify that the app attempted to call the ApiService
    verify(mockApiService.findShops(any)).called(1);

    //(Implicit) The test will fail if an unhandled exception is thrown.
  });
}
import 'dart:async';
import 'dart:collection';

import 'package:buy_beacon/models/product.dart';
import 'package:buy_beacon/orchestrators/shopping_orchestrator.dart';
import 'package:buy_beacon/orchestrators/shopping_state.dart';
import 'package:buy_beacon/providers/product_provider.dart';
import 'package:buy_beacon/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'home_screen_test.mocks.dart';

// We now need to mock the orchestrator as well.
@GenerateMocks([ProductProvider, ShoppingOrchestrator])
void main() {
  late MockProductProvider mockProductProvider;
  late MockShoppingOrchestrator mockShoppingOrchestrator;
  late StreamController<ShoppingState> orchestratorStreamController;

  setUp(() {
    mockProductProvider = MockProductProvider();
    mockShoppingOrchestrator = MockShoppingOrchestrator();
    orchestratorStreamController = StreamController<ShoppingState>.broadcast();

    // Set up default behaviors for the mocks.
    when(mockProductProvider.isInitialized).thenReturn(true);
    when(mockProductProvider.products).thenReturn(UnmodifiableListView<Product>([]));
    when(
      mockShoppingOrchestrator.onStateChanged,
    ).thenAnswer((_) => orchestratorStreamController.stream);

    when(mockShoppingOrchestrator.currentState).thenReturn(ShoppingState());
  });

  tearDown(() {
    orchestratorStreamController.close();
  });

  // Helper function to build the HomeScreen with all necessary providers.
  Widget createHomeScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProductProvider>.value(value: mockProductProvider),
        Provider<ShoppingOrchestrator>.value(value: mockShoppingOrchestrator),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  testWidgets('should show loading indicator when provider is not initialized', (
      WidgetTester tester,) async {
    // ARRANGE
    when(mockProductProvider.isInitialized).thenReturn(false);

    // ACT
    await tester.pumpWidget(createHomeScreen());

    // ASSERT
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
      'should display empty message when list is empty', (WidgetTester tester,) async {
    // ARRANGE (default setup is empty list)

    // ACT
    await tester.pumpWidget(createHomeScreen());

    // ASSERT
    expect(find.text('Your shopping list is empty.'), findsOneWidget);
  });

  testWidgets('should display a list of products when products exist', (
      WidgetTester tester,) async {
    // ARRANGE
    final products = [Product(id: 1, name: 'Test Product')];
    when(mockProductProvider.products).thenReturn(UnmodifiableListView(products));

    // ACT
    await tester.pumpWidget(createHomeScreen());

    // ASSERT
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Test Product'), findsOneWidget);
  });

  testWidgets('tapping the add button should call addProduct on the provider', (
      WidgetTester tester,) async {
    // ARRANGE
    when(mockProductProvider.addProduct(any)).thenAnswer((_) async {});
    await tester.pumpWidget(createHomeScreen());
    const productName = 'New Item';

    // ACT
    await tester.enterText(find.byType(TextField), productName);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // ASSERT
    verify(mockProductProvider.addProduct(productName)).called(1);
  });

  testWidgets('tapping the delete icon should call deleteProduct on the provider', (
      WidgetTester tester,) async {
    // ARRANGE
    final productToDelete = Product(id: 5, name: 'Item to delete');
    when(
      mockProductProvider.products,
    ).thenReturn(UnmodifiableListView([productToDelete]));
    when(mockProductProvider.deleteProduct(any)).thenAnswer((_) async {});
    await tester.pumpWidget(createHomeScreen());

    // ACT
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    // ASSERT
    verify(mockProductProvider.deleteProduct(5)).called(1);
  });
}

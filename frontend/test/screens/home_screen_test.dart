import 'dart:async';
import 'dart:collection';

import 'package:buy_beacon/models/category_option.dart';
import 'package:buy_beacon/models/product.dart';
import 'package:buy_beacon/orchestrators/shopping_orchestrator.dart';
import 'package:buy_beacon/orchestrators/shopping_state.dart';
import 'package:buy_beacon/providers/product_provider.dart';
import 'package:buy_beacon/screens/home_screen.dart';
import 'package:buy_beacon/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'home_screen_test.mocks.dart';

// We now need to mock the orchestrator as well.
@GenerateMocks([ProductProvider, ShoppingOrchestrator, LocationService])
void main() {
  late MockProductProvider mockProductProvider;
  late MockShoppingOrchestrator mockShoppingOrchestrator;
  late MockLocationService mockLocationService;
  late StreamController<ShoppingState> orchestratorStreamController;

  setUp(() {
    mockProductProvider = MockProductProvider();
    mockShoppingOrchestrator = MockShoppingOrchestrator();
    mockLocationService = MockLocationService();
    orchestratorStreamController = StreamController<ShoppingState>.broadcast();

    // Set up default behaviors for the mocks.
    when(mockProductProvider.isInitialized).thenReturn(true);
    when(mockProductProvider.products).thenReturn(UnmodifiableListView<Product>([]));
    when(
      mockShoppingOrchestrator.onStateChanged,
    ).thenAnswer((_) => orchestratorStreamController.stream);

    when(mockShoppingOrchestrator.currentState).thenReturn(ShoppingState());
    when(mockLocationService.needsPowerManagerPrompt).thenReturn(false);
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
        ChangeNotifierProvider<LocationService>.value(value: mockLocationService),
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

  testWidgets(
      'tapping the add button should add directly when the category is already known', (
      WidgetTester tester,) async {
    // ARRANGE
    const productName = 'New Item';
    when(mockProductProvider.lookupCategory(productName)).thenAnswer((_) async => 'supermarket');
    when(mockProductProvider.addProduct(any)).thenAnswer((_) async {});
    await tester.pumpWidget(createHomeScreen());

    // ACT
    await tester.enterText(find.byType(TextField), productName);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // ASSERT
    verify(mockProductProvider.addProduct(productName)).called(1);
    expect(find.byType(SimpleDialog), findsNothing);
  });

  testWidgets(
      'tapping the add button should show a category picker when the category is unknown, '
      'and adding with the chosen category after selection', (WidgetTester tester,) async {
    // ARRANGE
    const productName = 'Unobtainium';
    final options = [
      CategoryOption(code: 'hardware_store', label: 'Bricolaj'),
      CategoryOption(code: 'supermarket', label: 'Alimentar'),
    ];
    when(mockProductProvider.lookupCategory(productName)).thenAnswer((_) async => null);
    when(mockProductProvider.getCategoryOptions()).thenAnswer((_) async => options);
    when(
      mockProductProvider.addProductWithCategory(any, any),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(createHomeScreen());

    // ACT
    await tester.enterText(find.byType(TextField), productName);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // ASSERT: dialog is showing with both options.
    expect(find.byType(SimpleDialog), findsOneWidget);
    expect(find.text('Bricolaj'), findsOneWidget);
    expect(find.text('Alimentar'), findsOneWidget);

    // ACT: pick one.
    await tester.tap(find.text('Bricolaj'));
    await tester.pumpAndSettle();

    // ASSERT
    verify(mockProductProvider.addProductWithCategory(productName, 'hardware_store')).called(1);
    verifyNever(mockProductProvider.addProduct(any));
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

  testWidgets('shows the power manager banner when the OEM health check flags it', (
      WidgetTester tester,) async {
    // ARRANGE
    when(mockLocationService.needsPowerManagerPrompt).thenReturn(true);

    // ACT
    await tester.pumpWidget(createHomeScreen());

    // ASSERT
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.text('Fix settings'), findsOneWidget);
  });

  testWidgets('dismissing the power manager banner hides it', (WidgetTester tester,) async {
    // ARRANGE
    when(mockLocationService.needsPowerManagerPrompt).thenReturn(true);
    await tester.pumpWidget(createHomeScreen());
    expect(find.byType(MaterialBanner), findsOneWidget);

    // ACT
    await tester.tap(find.text('Dismiss'));
    await tester.pump();

    // ASSERT
    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets('does not show the power manager banner when not flagged', (
      WidgetTester tester,) async {
    // ACT
    await tester.pumpWidget(createHomeScreen());

    // ASSERT
    expect(find.byType(MaterialBanner), findsNothing);
  });
}

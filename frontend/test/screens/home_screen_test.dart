import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../providers/product_provider_test.mocks.dart';

void main() {
  late MockProductProvider mockProductProvider;

  //helper function to build home screen with all ancestors
  Widget createHomeScreen() {
    return ChangeNotifierProvider<ProductProvider>.value(
      value: mockProductProvider,
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  setUp(() {
    mockProductProvider = MockProductProvider();
  });

  testWidgets(
    'HomeScreen should show loading indicator when provider is not initialized',
    (WidgetTester tester) async {
      //ARRANGE
      when(mockProductProvider.isInitialized).thenReturn(false);
      when(mockProductProvider.products).thenReturn(UnmodifiableListView<Product>([]));

      //ASSERT
      await tester.pumpWidget(createHomeScreen());

      //ACT
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(find.text('Your shopping list is empty.'), findsNothing);
    },
  );

  testWidgets(
    'HomeScreen should display empty message when initialized and list is empty',
    (WidgetTester tester) async {
      //ARANGE
      //mock provider returns and empty product list
      when(mockProductProvider.isInitialized).thenReturn(true);
      when(mockProductProvider.products).thenReturn(UnmodifiableListView([]));

      //ACT
      //build widget tree in test env
      await tester.pumpWidget(createHomeScreen());

      //ASSERT
      //use "Finders" to locate widgets on screen
      final emptyMessageFinder = find.text('Your shopping list is empty.');
      final productListFinder = find.byType(ListView);

      //verify that the empty message is found and the ListView is not
      expect(emptyMessageFinder, findsOneWidget);
      expect(productListFinder, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('HomeScreen should display a list of products when products exist', (
    WidgetTester tester,
  ) async {
    //ARRANGE
    final products = [
      Product(id: 1, name: 'Test product 1'),
      Product(id: 2, name: 'Test product 2'),
    ];
    when(mockProductProvider.isInitialized).thenReturn(true);
    when(mockProductProvider.products).thenReturn(UnmodifiableListView(products));

    //ACT
    await tester.pumpWidget(createHomeScreen());

    //ASSERT
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Test product 1'), findsOneWidget);
    expect(find.text('Test product 2'), findsOneWidget);
    expect(find.text('Your shopping list is empty.'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Tapping the add button should call addProduct on the provider', (
    WidgetTester tester,
  ) async {
    //ARRANGE
    when(mockProductProvider.isInitialized).thenReturn(true);
    when(mockProductProvider.products).thenReturn(UnmodifiableListView<Product>([]));
    when(mockProductProvider.addProduct(any)).thenAnswer((_) async {});

    await tester.pumpWidget(createHomeScreen());
    const productName = 'New Item';
    final textField = find.byType(TextField);
    final addButton = find.byIcon(Icons.add);

    //ACT
    await tester.enterText(textField, productName);
    await tester.tap(addButton);
    await tester.pump();

    //ASSERT
    verify(mockProductProvider.addProduct(productName)).called(1);
    final textFieldWidget = tester.widget<TextField>(textField);
    expect(textFieldWidget.controller!.text, isEmpty);
  });

  testWidgets('Tapping the delete icon should call deleteProduct on the provider', (
    WidgetTester tester,
  ) async {
    //ARRANGE
    final productToDelete = Product(id: 5, name: 'Item to delete');
    when(mockProductProvider.isInitialized).thenReturn(true);
    when(
      mockProductProvider.products,
    ).thenReturn(UnmodifiableListView([productToDelete]));
    when(mockProductProvider.deleteProduct(any)).thenAnswer((_) async {});

    await tester.pumpWidget(createHomeScreen());

    final deleteButton = find.byIcon(Icons.delete_outline);
    expect(deleteButton, findsOneWidget);

    //ACT
    await tester.tap(deleteButton);
    await tester.pump();

    //ASSERT
    verify(mockProductProvider.deleteProduct(5)).called(1);
  });

  testWidgets('Adding a duplicate product should call provider but not change the list', (
    WidgetTester tester,
  ) async {
    //ARRANGE
    final existingProduct = Product(id: 1, name: 'Existing item');

    when(mockProductProvider.isInitialized).thenReturn(true);
    when(
      mockProductProvider.products,
    ).thenReturn(UnmodifiableListView([existingProduct]));
    when(mockProductProvider.addProduct(any)).thenAnswer((_) async {});

    await tester.pumpWidget(createHomeScreen());

    //ACT
    await tester.enterText(find.byType(TextField), 'Existing item');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    //ASSERT
    verify(mockProductProvider.addProduct('Existing item')).called(1);

    final listTiles = tester.widgetList<ListTile>(find.byType(ListTile));
    expect(listTiles.length, 1);

    final textFieldWidget = tester.widget<TextField>(find.byType(TextField));
    expect(textFieldWidget.controller!.text, isEmpty);
  });
}

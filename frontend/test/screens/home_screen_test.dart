import 'dart:collection';

import 'package:frontend/models/product.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../providers/product_provider_test.mocks.dart';

void main(){
  late MockProductProvider mockProductProvider;

  //helper function to build home screen with all ancestors
  Widget createHomeScreen(){
    return ChangeNotifierProvider<ProductProvider>.value(
        value: mockProductProvider,
        child: const MaterialApp(
          home: HomeScreen(),
        ),
    );
  }
  
  setUp((){
    mockProductProvider = MockProductProvider();
  });

  testWidgets('HomeScreen should display empty message when there are no products', (WidgetTester tester) async {
    //ARANGE
    //mock provider returns and empty product list
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
  });

  testWidgets('HomeScreen should display a list of products when products exist', (WidgetTester tester) async{
    //ARRANGE
    final products = [
      Product(id: 1, name: 'Test product 1'),
      Product(id: 2, name: 'Test product 2')
    ];
    when(mockProductProvider.products).thenReturn(UnmodifiableListView(products));

    //ACT
    await tester.pumpWidget(createHomeScreen());

    //ASSERT
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Test product 1'), findsOneWidget);
    expect(find.text('Test product 2'), findsOneWidget);
    expect(find.text('Your shopping list is empty.'), findsNothing);
  });
}
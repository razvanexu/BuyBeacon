import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend/main.dart' as app;

void main(){
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('end-to-end test', (){
    testWidgets('tap the add button, verify product is added',
        (WidgetTester tester) async{

          //ARRANGE
          //start the app
          app.main();

          //await for app to complete loading and settle
          await tester.pumpAndSettle();

          //find the widgets neede for interaction
          final textField = find.byType(TextField);
          final addButton = find.byType(ElevatedButton);

          //Verify initial state - list is initially empty
          expect(find.text('Your shopping list is empty.'), findsOneWidget);

          //ACT
          //Simulate user input
          //Enter text into text field
          await tester.enterText(textField, 'Integration Test Product');
          await tester.pumpAndSettle(); //wait for the UI to settle (animations, etc)

          //tap the add button
          await tester.tap(addButton);

          //wait for all async operations to finish (API cals, db write and read, UI rebuild)
          await tester.pumpAndSettle();

          //ASSERT
          //Verify final state. New product should be visible in listview
          expect(find.byType(ListView), findsOneWidget);
          expect(find.text('Integration Test Product'), findsOneWidget);
          
          //empty message should be gone
          expect(find.text('Your shopping list is empty.'), findsNothing);
      });
    });
  }
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:logging/logging.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  final log = Logger('AppIntegrationTest');

  group('end-to-end test', () {
    testWidgets('Add, attempt duplicate, and delete a product', (
      WidgetTester tester,
    ) async {
      //ARRANGE
      //start the app
      app.main();

      //await for app to complete loading and settle
      await tester.pumpAndSettle(const Duration(seconds: 5));

      //clear existing products from the list
      final allListTiles = tester.widgetList<ListTile>(find.byType(ListTile));
      final initialItemCount = allListTiles.length;

      //find the widgets needed for interaction
      final textField = find.byType(TextField);
      final addButton = find.byIcon(Icons.add);

      //delete all items
      if (initialItemCount > 0) {
        log.info('Found $initialItemCount existing products. Clearing list...');

        for (int i = 0; i < initialItemCount; i++) {
          await tester.tap(find.byIcon(Icons.delete_outline).first);
          await tester.pumpAndSettle(Duration(seconds: 3));
        }
        log.info('Finished clearing list');
      }
      //Verify clean state - list is cleared
      expect(find.text('Your shopping list is empty.'), findsOneWidget);

      //ACT & Assert
      //Simulate user input
      //Enter text into text field
      const newProductText = 'Integration Test Product';
      await tester.enterText(textField, newProductText);
      await tester.pumpAndSettle(); //wait for the UI to settle (animations, etc)

      //tap the add button
      await tester.tap(addButton);

      //wait for all async operations to finish (API cals, db write and read, UI rebuild)
      await tester.pumpAndSettle(const Duration(seconds: 5));

      //Verify final state. New product should be visible in listview
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text(newProductText), findsOneWidget);
      expect(find.text('Your shopping list is empty.'), findsNothing);

      //ACT & ASSERT: Attempt to add duplicate
      await tester.enterText(textField, newProductText);
      await tester.pumpAndSettle();
      await tester.tap(addButton);
      await tester.pumpAndSettle(Duration(seconds: 5));

      final listTiles = tester.widgetList<ListTile>(find.byType(ListTile));
      expect(listTiles.length, 1, reason: 'List should not contain duplicate products');

      //ACT & ASSERT : Delete product
      final deleteButton = find.byIcon(Icons.delete_outline);
      expect(deleteButton, findsOneWidget);

      await tester.tap(deleteButton);
      await tester.pumpAndSettle(Duration(seconds: 5));

      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pump();

      //verify the list is empty again
      expect(find.text('Your shopping list is empty.'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });
  });
}

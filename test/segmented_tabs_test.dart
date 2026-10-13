import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waterflyiii/pages/home/transactions.dart';

void main() {
  testWidgets(
    '_SegmentedTabs displays Todos, Gastos, Ingresos, Traspasos and handles taps',
    (WidgetTester tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return SegmentedTabs(
                  selected: selectedIndex,
                  onChanged: (int index) {
                    setState(() {
                      selectedIndex = index;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Gastos'), findsOneWidget);
      expect(find.text('Ingresos'), findsOneWidget);
      expect(find.text('Traspasos'), findsOneWidget);

      await tester.tap(find.text('Gastos'));
      await tester.pump();
      expect(selectedIndex, 1);

      await tester.tap(find.text('Traspasos'));
      await tester.pump();
      expect(selectedIndex, 3);

      await tester.tap(find.text('Ingresos'));
      await tester.pump();
      expect(selectedIndex, 2);

      await tester.tap(find.text('Todos'));
      await tester.pump();
      expect(selectedIndex, 0);
    },
  );
}

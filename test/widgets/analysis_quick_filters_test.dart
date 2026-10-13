import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waterflyiii/pages/home/analysis.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/monthly_bars.dart';

void main() {
  group('AnalysisQuickFilters widget', () {
    testWidgets('renders Gastos and Ingresos chips and handles switching', (
      WidgetTester tester,
    ) async {
      AnalysisCategoryType current = AnalysisCategoryType.expense;

      await tester.pumpWidget(
        MaterialApp(
          theme: FtTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return AnalysisQuickFilters(
                  selected: current,
                  onSelected: (AnalysisCategoryType type) {
                    setState(() {
                      current = type;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify both chips are rendered
      expect(find.text('Gastos'), findsOneWidget);
      expect(find.text('Ingresos'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(2));

      // Verify centered alignment
      final Row row = tester.widget<Row>(find.byType(Row).first);
      expect(row.mainAxisAlignment, equals(MainAxisAlignment.center));

      // Initial state: Gastos is selected
      ChoiceChip expenseChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Gastos'),
      );
      ChoiceChip incomeChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Ingresos'),
      );
      expect(expenseChip.selected, isTrue);
      expect(incomeChip.selected, isFalse);

      // Tap Ingresos
      await tester.tap(find.text('Ingresos'));
      await tester.pumpAndSettle();

      expect(current, equals(AnalysisCategoryType.income));
      expenseChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Gastos'),
      );
      incomeChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Ingresos'),
      );
      expect(expenseChip.selected, isFalse);
      expect(incomeChip.selected, isTrue);

      // Tap Gastos again
      await tester.tap(find.text('Gastos'));
      await tester.pumpAndSettle();

      expect(current, equals(AnalysisCategoryType.expense));
      expenseChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Gastos'),
      );
      incomeChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Ingresos'),
      );
      expect(expenseChip.selected, isTrue);
      expect(incomeChip.selected, isFalse);
    });
  });

  group('MonthlyBars incomeOnly mode', () {
    testWidgets(
      'renders incomeOnly mode without error and triggers callbacks',
      (WidgetTester tester) async {
        int selected = 5;
        final List<MonthBarData> data = List<MonthBarData>.generate(
          6,
          (int i) => MonthBarData(
            label: 'M${i + 1}',
            income: (i + 1) * 150.0,
            expense: 0.0,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: FtTheme.light(),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return MonthlyBars(
                    data: data,
                    selectedIndex: selected,
                    incomeOnly: true,
                    onSelect: (int i) => setState(() => selected = i),
                  );
                },
              ),
            ),
          ),
        );

        expect(find.byType(MonthlyBars), findsOneWidget);
        expect(find.text('M1'), findsOneWidget);
        expect(find.text('M6'), findsOneWidget);

        await tester.tap(find.text('M3'));
        await tester.pumpAndSettle();
        expect(selected, equals(2));
      },
    );
  });
}

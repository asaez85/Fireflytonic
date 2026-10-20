import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/home/transactions/filter.dart';
import 'package:waterflyiii/pages/home/transactions/widgets/accounts_filter_sheet.dart';
import 'package:waterflyiii/pages/home/transactions/widgets/amount_filter_sheet.dart';
import 'package:waterflyiii/pages/home/transactions/widgets/date_filter_sheet.dart';

void main() {
  group('TransactionFilters Tests', () {
    test('Initializes with default empty values', () {
      final TransactionFilters filters = TransactionFilters();
      expect(filters.hasFilters, isFalse);
      expect(filters.accounts, isEmpty);
      expect(filters.categories, isEmpty);
      expect(filters.text, isNull);
    });

    test('updateFilters detects accounts and categories list', () {
      final TransactionFilters filters = TransactionFilters();
      filters.accounts = <AccountRead>[
        const AccountRead(
          id: '123',
          type: 'accounts',
          attributes: AccountProperties(
            name: 'Cuenta BBVA',
            type: ShortAccountTypeProperty.asset,
          ),
        ),
      ];
      filters.updateFilters();
      expect(filters.hasFilters, isTrue);

      filters.reset();
      expect(filters.hasFilters, isFalse);
      expect(filters.accounts, isEmpty);
    });

    test(
      'reset clears all filters including dates, text, budget and amounts',
      () {
        final TransactionFilters filters = TransactionFilters();
        filters.text = 'Supermercado';
        filters.start = DateTime(2026, 1, 1);
        filters.end = DateTime(2026, 1, 31);
        filters.minAmount = 10.5;
        filters.maxAmount = 50.0;
        filters.budget = const BudgetRead(
          id: '1',
          type: 'budgets',
          attributes: BudgetProperties(name: 'Comida'),
        );
        filters.updateFilters();
        expect(filters.hasFilters, isTrue);

        final TransactionFilters copy = filters.copyWith();
        expect(copy.minAmount, 10.5);
        expect(copy.maxAmount, 50.0);

        filters.reset();
        expect(filters.hasFilters, isFalse);
        expect(filters.text, isNull);
        expect(filters.start, isNull);
        expect(filters.end, isNull);
        expect(filters.budget, isNull);
        expect(filters.minAmount, isNull);
        expect(filters.maxAmount, isNull);
      },
    );
  });

  group('AmountFilterSheet Widget Tests', () {
    testWidgets('Renders fields and buttons correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AmountFilterSheet(initialMin: 15.0, initialMax: 100.0),
          ),
        ),
      );

      expect(find.text("Importe"), findsOneWidget);
      expect(find.text("Desde"), findsOneWidget);
      expect(find.text("Hasta"), findsOneWidget);
      expect(find.text("15"), findsOneWidget);
      expect(find.text("100"), findsOneWidget);
      expect(find.text("Limpiar"), findsOneWidget);
      expect(find.text("Aplicar"), findsOneWidget);
    });
  });

  group('DateFilterSheet Widget Tests', () {
    testWidgets('Renders options correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DateFilterSheet(currentLabel: "Último mes")),
        ),
      );

      expect(find.text("Selecciona"), findsOneWidget);
      expect(find.text("Último mes"), findsOneWidget);
      expect(find.text("Últimos 3 meses"), findsOneWidget);
      expect(find.text("Último año"), findsOneWidget);
      expect(find.text("Personalizado"), findsOneWidget);
    });
  });

  group('BankLogoBadge Widget Tests', () {
    testWidgets('Renders BBVA and Santander brands correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                BankLogoBadge(accountName: "BBVA Online"),
                BankLogoBadge(accountName: "Cuenta Santander 123"),
              ],
            ),
          ),
        ),
      );

      expect(find.text("BBVA"), findsOneWidget);
      expect(find.text("SAN"), findsOneWidget);
    });
  });
}

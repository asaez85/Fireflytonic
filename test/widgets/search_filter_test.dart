import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/home/transactions/filter.dart';
import 'package:waterflyiii/pages/home/transactions/widgets/accounts_filter_sheet.dart';
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

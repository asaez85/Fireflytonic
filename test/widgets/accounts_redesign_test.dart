import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/widgets/bank_logo_badge.dart';

void main() {
  group('BankLogoBadge Widget Tests', () {
    testWidgets('Identifies multiple popular banks correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  BankLogoBadge(accountName: 'Nómina CaixaBank'),
                  BankLogoBadge(accountName: 'Cuenta Naranja ING'),
                  BankLogoBadge(accountName: 'Revolut Metal'),
                  BankLogoBadge(accountName: 'Openbank Corriente'),
                  BankLogoBadge(accountName: 'Wise Multi-divisa'),
                  BankLogoBadge(accountName: 'N26 Smart'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Caixa'), findsOneWidget);
      expect(find.text('ING'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Wise'), findsOneWidget);
      expect(find.text('N26'), findsOneWidget);
    });

    testWidgets('Shows appropriate icon for generic liability and asset', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                BankLogoBadge(
                  accountName: 'Préstamo Coche',
                  type: ShortAccountTypeProperty.liability,
                ),
                BankLogoBadge(
                  accountName: 'Billetera',
                  type: ShortAccountTypeProperty.cash,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.credit_card_outlined), findsOneWidget);
      expect(
        find.byIcon(Icons.account_balance_wallet_outlined),
        findsOneWidget,
      );
    });
  });
}

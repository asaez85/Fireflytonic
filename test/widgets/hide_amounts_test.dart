// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('Hide Amounts Feature Tests', () {
    test('CurrencyFormat.fmt respects obscure flag directly', () {
      final CurrencyRead currency = const CurrencyRead(
        id: '1',
        type: 'currencies',
        attributes: CurrencyProperties(
          code: 'EUR',
          name: 'Euro',
          symbol: '€',
          decimalPlaces: 2,
        ),
      );

      expect(
        currency.fmt(123.45, obscure: true),
        CurrencyFormat.hiddenAmountPlaceholder,
      );
      expect(currency.fmt(123.45, obscure: false), contains('123'));
    });

    testWidgets(
      'CurrencyFormat.fmt reacts to SettingsProvider.hideAmounts via context',
      (WidgetTester tester) async {
        final SettingsProvider settings = SettingsProvider();
        final CurrencyRead currency = const CurrencyRead(
          id: '1',
          type: 'currencies',
          attributes: CurrencyProperties(
            code: 'EUR',
            name: 'Euro',
            symbol: '€',
            decimalPlaces: 2,
          ),
        );

        Widget buildTestWidget() {
          return ChangeNotifierProvider<SettingsProvider>.value(
            value: settings,
            child: Builder(
              builder: (BuildContext context) {
                return MaterialApp(
                  home: Scaffold(
                    body: Text(currency.fmt(450.50, context: context)),
                  ),
                );
              },
            ),
          );
        }

        await tester.pumpWidget(buildTestWidget());
        expect(find.text(CurrencyFormat.hiddenAmountPlaceholder), findsNothing);
        expect(find.textContaining('450'), findsOneWidget);

        // Toggle hide amounts
        settings.hideAmounts = true;
        await tester.pumpAndSettle();

        expect(
          find.text(CurrencyFormat.hiddenAmountPlaceholder),
          findsOneWidget,
        );
        expect(find.textContaining('450'), findsNothing);

        // Show amounts again
        settings.hideAmounts = false;
        await tester.pumpAndSettle();

        expect(find.text(CurrencyFormat.hiddenAmountPlaceholder), findsNothing);
        expect(find.textContaining('450'), findsOneWidget);
      },
    );
  });
}

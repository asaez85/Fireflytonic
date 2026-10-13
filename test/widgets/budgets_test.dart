import 'dart:io';
import 'package:chopper/chopper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';
import 'package:waterflyiii/widgets/ft_progress_bar.dart';

void main() {
  group('Budgets UI & Components Tests', () {
    test(
      'APIRequestInterceptor injects Content-Type header on POST requests',
      () async {
        late http.BaseRequest capturedRequest;
        final MockClient mockClient = MockClient((http.Request request) async {
          capturedRequest = request;
          return http.Response(
            '{}',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        });

        final ChopperClient chopper = ChopperClient(
          client: mockClient,
          baseUrl: Uri.parse('http://example.com'),
          interceptors: <Interceptor>[
            APIRequestInterceptor(
              () => <String, String>{
                HttpHeaders.authorizationHeader: 'Bearer fake',
                HttpHeaders.acceptHeader: 'application/json',
              },
            ),
          ],
        );

        final Request request = Request(
          'POST',
          Uri.parse('http://example.com/v1/rules/1/trigger'),
          Uri.parse('http://example.com'),
        );
        await chopper.send(request);

        expect(
          capturedRequest.headers[HttpHeaders.contentTypeHeader],
          'application/json',
        );
        expect(
          capturedRequest.headers[HttpHeaders.acceptHeader],
          'application/json',
        );
      },
    );
    testWidgets('FtProgressBar renders safe clamped progress', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: FtProgressBar(
                  progress: 0.65,
                  color: Colors.green,
                  height: 6.0,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FtProgressBar), findsOneWidget);
    });

    testWidgets('FtCategoryIcon resolves appropriate icons and colors', (
      WidgetTester tester,
    ) async {
      final IconData foodIcon = FtCategoryIcon.forName('Supermercado');
      expect(foodIcon, Icons.shopping_cart);

      final IconData carIcon = FtCategoryIcon.forName('Gasolina');
      expect(carIcon, Icons.local_gas_station);

      final IconData restaurantIcon = FtCategoryIcon.forName('Restaurante');
      expect(restaurantIcon, Icons.restaurant);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                final Color color = FtColors.categoryColor(
                  'Supermercado',
                  context: context,
                );
                return FtCategoryIconWidget(
                  icon: foodIcon,
                  color: color,
                  size: 24,
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(FtCategoryIconWidget), findsOneWidget);
    });
  });
}

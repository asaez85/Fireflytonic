import 'package:flutter_test/flutter_test.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';

void main() {
  group('Budget deserialization', () {
    test('parses BudgetProperties with int object_group_id', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
        'name': 'Restaurantes',
        'order': 0,
        'object_group_id': 1,
        'object_group_title': 'Presupuesto',
        'object_group_order': 0,
        'currency_id': 1,
        'spent': <dynamic>[
          <String, dynamic>{
            'currency_id': 1,
            'currency_code': 'EUR',
            'currency_symbol': '€',
            'currency_decimal_places': 2,
            'sum': '50.00',
          },
        ],
      };

      final BudgetProperties props = BudgetProperties.fromJson(json);
      expect(props.name, 'Restaurantes');
      expect(props.objectGroupId, '1');
      expect(props.currencyId, '1');
      expect(props.spent?.first.currencyId, '1');
    });

    test('parses BudgetLimitProperties with int budget_id and currency_id', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
        'start': '2026-03-01T00:00:00Z',
        'end': '2026-03-31T23:59:59Z',
        'budget_id': 1,
        'currency_id': 1,
        'amount': 200,
      };

      final BudgetLimitProperties props = BudgetLimitProperties.fromJson(json);
      expect(props.budgetId, '1');
      expect(props.currencyId, '1');
      expect(props.amount, '200');
    });

    test('parses BudgetRead and BudgetLimitRead with integer id', () {
      final BudgetRead bRead = BudgetRead.fromJson(<String, dynamic>{
        'type': 'budgets',
        'id': 42,
        'attributes': <String, dynamic>{'name': 'Ocio', 'currency_id': 1},
      });
      expect(bRead.id, '42');

      final BudgetLimitRead lRead = BudgetLimitRead.fromJson(<String, dynamic>{
        'type': 'budget_limits',
        'id': 105,
        'attributes': <String, dynamic>{
          'budget_id': 42,
          'currency_id': 1,
          'amount': '150.00',
        },
      });
      expect(lRead.id, '105');
      expect(lRead.attributes.budgetId, '42');
    });

    test(
      'parses BudgetArray and BudgetLimitArray with int IDs and numeric values',
      () {
        final Map<String, dynamic> budgetArrayJson = <String, dynamic>{
          'data': <dynamic>[
            <String, dynamic>{
              'type': 'budgets',
              'id': 123,
              'attributes': <String, dynamic>{
                'name': 'Supermercado',
                'currency_id': 1,
                'primary_currency_id': 1,
                'object_group_id': 10,
                'auto_budget_amount': 350,
                'spent': <dynamic>[
                  <String, dynamic>{'currency_id': 1, 'sum': 45},
                ],
              },
            },
          ],
          'meta': <String, dynamic>{
            'pagination': <String, dynamic>{
              'total': 1,
              'count': 1,
              'per_page': 50,
              'current_page': 1,
              'total_pages': 1,
            },
          },
        };

        final BudgetArray budgets = BudgetArray.fromJson(budgetArrayJson);
        expect(budgets.data.first.id, '123');
        expect(budgets.data.first.attributes.currencyId, '1');
        expect(budgets.data.first.attributes.primaryCurrencyId, '1');
        expect(budgets.data.first.attributes.objectGroupId, '10');
        expect(budgets.data.first.attributes.autoBudgetAmount, '350');
        expect(budgets.data.first.attributes.spent?.first.sum, '45');

        final Map<String, dynamic> limitArrayJson = <String, dynamic>{
          'data': <dynamic>[
            <String, dynamic>{
              'type': 'budget_limits',
              'id': 456,
              'attributes': <String, dynamic>{
                'budget_id': 123,
                'currency_id': 1,
                'amount': 300,
              },
            },
          ],
          'meta': <String, dynamic>{
            'pagination': <String, dynamic>{
              'total': 1,
              'count': 1,
              'per_page': 50,
              'current_page': 1,
              'total_pages': 1,
            },
          },
        };

        final BudgetLimitArray limits = BudgetLimitArray.fromJson(
          limitArrayJson,
        );
        expect(limits.data.first.id, '456');
        expect(limits.data.first.attributes.budgetId, '123');
        expect(limits.data.first.attributes.amount, '300');
      },
    );
  });
}

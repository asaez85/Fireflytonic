import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';

void main() {
  group('Split Transaction Category & Icon Tests', () {
    test(
      'Split transaction with all splits in same category resolves category icon',
      () {
        final List<TransactionSplit> splits = <TransactionSplit>[
          TransactionSplit(
            user: '1',
            transactionJournalId: '101',
            type: TransactionTypeProperty.withdrawal,
            date: DateTime(2026, 10, 17),
            amount: '25.00',
            description: 'Cena parte 1',
            categoryName: 'Restaurante',
          ),
          TransactionSplit(
            user: '1',
            transactionJournalId: '102',
            type: TransactionTypeProperty.withdrawal,
            date: DateTime(2026, 10, 17),
            amount: '15.00',
            description: 'Cena parte 2',
            categoryName: 'Restaurante',
          ),
        ];

        final Set<String> categories = <String>{};
        String category = '';
        for (final TransactionSplit trans in splits) {
          if (trans.categoryName?.isNotEmpty ?? false) {
            categories.add(trans.categoryName!);
            if (category.isEmpty) {
              category = trans.categoryName!;
            }
          }
        }

        expect(categories.length, 1);
        expect(category, 'Restaurante');
        expect(FtCategoryIcon.forName(category), Icons.restaurant);
        expect(
          FtCategoryIcon.forName(category),
          isNot(Icons.category_outlined),
        );
      },
    );

    test(
      'Split transaction with multiple categories resolves to generic category icon',
      () {
        final List<TransactionSplit> splits = <TransactionSplit>[
          TransactionSplit(
            user: '1',
            transactionJournalId: '101',
            type: TransactionTypeProperty.withdrawal,
            date: DateTime(2026, 10, 17),
            amount: '25.00',
            description: 'Compra supermercado',
            categoryName: 'Supermercado',
          ),
          TransactionSplit(
            user: '1',
            transactionJournalId: '102',
            type: TransactionTypeProperty.withdrawal,
            date: DateTime(2026, 10, 17),
            amount: '15.00',
            description: 'Farmacia',
            categoryName: 'Farmacia',
          ),
        ];

        final Set<String> categories = <String>{};
        String category = '';
        for (final TransactionSplit trans in splits) {
          if (trans.categoryName?.isNotEmpty ?? false) {
            categories.add(trans.categoryName!);
            if (category.isEmpty) {
              category = trans.categoryName!;
            }
          }
        }

        expect(categories.length, 2);
        if (categories.length > 1) {
          category = '${categories.length} categorías';
        }
        expect(category, '2 categorías');
        expect(FtCategoryIcon.forName(category), Icons.category_outlined);
      },
    );

    testWidgets(
      'Renders specific category icon widget when all splits share category',
      (WidgetTester tester) async {
        const String category = 'Restaurante';
        final IconData icon = FtCategoryIcon.forName(category);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) {
                  final Color tint = FtColors.categoryColor(
                    category,
                    context: context,
                  );
                  return FtCategoryIconWidget(
                    icon: icon,
                    color: tint,
                    size: 24,
                    padding: 10,
                  );
                },
              ),
            ),
          ),
        );

        expect(find.byType(FtCategoryIconWidget), findsOneWidget);
        final Icon iconWidget = tester.widget<Icon>(find.byType(Icon));
        expect(iconWidget.icon, Icons.restaurant);
      },
    );
  });
}

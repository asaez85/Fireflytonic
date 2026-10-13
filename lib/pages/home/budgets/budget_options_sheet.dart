import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/home/budgets/add_edit_budget_dialog.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';
import 'package:waterflyiii/widgets/ft_progress_bar.dart';

class BudgetOptionsSheet extends StatelessWidget {
  final BudgetRead budget;
  final BudgetLimitRead? limit;
  final DateTime selectedMonth;
  final void Function(BudgetRead budget) onOpenTransactions;

  const BudgetOptionsSheet({
    super.key,
    required this.budget,
    required this.limit,
    required this.selectedMonth,
    required this.onOpenTransactions,
  });

  static Future<bool?> show(
    BuildContext context, {
    required BudgetRead budget,
    required BudgetLimitRead? limit,
    required DateTime selectedMonth,
    required void Function(BudgetRead budget) onOpenTransactions,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => BudgetOptionsSheet(
        budget: budget,
        limit: limit,
        selectedMonth: selectedMonth,
        onOpenTransactions: onOpenTransactions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    final String name = budget.attributes.name;
    final IconData icon = FtCategoryIcon.forName(name);
    final Color catColor = FtColors.categoryColor(name, context: context);

    final double limitAmount = limit != null
        ? (double.tryParse(limit?.attributes.amount ?? '') ?? 0.0)
        : (double.tryParse(budget.attributes.autoBudgetAmount ?? '') ?? 0.0);

    double spentAmount = 0.0;
    if (limit?.attributes.spent?.isNotEmpty ?? false) {
      spentAmount =
          (double.tryParse(limit!.attributes.spent!.first.sum ?? '') ?? 0.0)
              .abs();
    } else if (budget.attributes.spent?.isNotEmpty ?? false) {
      spentAmount =
          (double.tryParse(budget.attributes.spent!.first.sum ?? '') ?? 0.0)
              .abs();
    }

    final double progress = limitAmount > 0 ? (spentAmount / limitAmount) : 0.0;
    final bool isOver = spentAmount > limitAmount;

    Color barColor;
    if (progress <= 0.75) {
      barColor = Colors.green;
    } else if (progress <= 1.0) {
      barColor = Colors.orange;
    } else {
      barColor = FtColors.coralOf(context);
    }

    final String monthName = DateFormat(
      'MMMM yyyy',
      'es_ES',
    ).format(selectedMonth);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header info
          Row(
            children: <Widget>[
              FtCategoryIconWidget(
                icon: icon,
                color: catColor,
                size: 28,
                padding: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      monthName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    isOver
                        ? '+${currency.fmt(spentAmount - limitAmount, context: context)}'
                        : currency.fmt(
                            limitAmount - spentAmount,
                            context: context,
                          ),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isOver ? FtColors.coralOf(context) : null,
                    ),
                  ),
                  Text(
                    isOver ? 'Excedido' : 'Restante',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          FtProgressBar(progress: progress, color: barColor, height: 6),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Gastado: ${currency.fmt(spentAmount, context: context)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                'Límite: ${currency.fmt(limitAmount, context: context)} (${(progress * 100).toStringAsFixed(0)}%)',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const Divider(height: 32),
          // Action list
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Ver movimientos'),
            subtitle: const Text(
              'Consultar gastos asignados a este presupuesto',
            ),
            onTap: () {
              Navigator.pop(context);
              onOpenTransactions(budget);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Editar presupuesto y límite'),
            subtitle: const Text('Cambiar el importe mensual o nombre'),
            onTap: () async {
              Navigator.pop(context);
              final bool? updated = await AddEditBudgetDialog.show(
                context,
                budget: budget,
                limit: limit,
                selectedMonth: selectedMonth,
              );
              if ((updated ?? false) && context.mounted) {
                // Return true so parent reloads
              }
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Eliminar presupuesto',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('Borra el presupuesto de Firefly III'),
            onTap: () async {
              final bool? confirmed = await showDialog<bool>(
                context: context,
                builder: (BuildContext ctx) => AlertDialog(
                  title: const Text('¿Eliminar presupuesto?'),
                  content: Text(
                    'Se eliminará el presupuesto "$name" y sus límites asociados.',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );

              if ((confirmed ?? false) && context.mounted) {
                try {
                  await context.read<FireflyService>().api.v1BudgetsIdDelete(
                    id: budget.id,
                  );
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al eliminar: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

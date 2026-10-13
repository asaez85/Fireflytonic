import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/home.dart';
import 'package:waterflyiii/pages/home/budgets/add_edit_budget_dialog.dart';
import 'package:waterflyiii/pages/home/budgets/auto_budget_sheet.dart';
import 'package:waterflyiii/pages/home/budgets/budget_options_sheet.dart';
import 'package:waterflyiii/settings.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';
import 'package:waterflyiii/widgets/ft_progress_bar.dart';

class HomeBudgets extends StatefulWidget {
  final void Function(BudgetRead budget) onOpenBudgetTransactions;

  const HomeBudgets({super.key, required this.onOpenBudgetTransactions});

  @override
  State<HomeBudgets> createState() => _HomeBudgetsState();
}

class _HomeBudgetsState extends State<HomeBudgets> {
  late DateTime _selectedMonth;
  bool _isLoading = true;
  bool _isApplyingRules = false;
  String? _error;

  List<BudgetRead> _budgets = <BudgetRead>[];
  final Map<String, BudgetLimitRead> _limitsByBudgetId =
      <String, BudgetLimitRead>{};

  @override
  void initState() {
    super.initState();
    final FireflyService ff = context.read<FireflyService>();
    final DateTime now = ff.tzHandler.sNow().clearTime();
    _selectedMonth = DateTime(now.year, now.month, 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerAppBarActions();
      _fetchBudgets();
    });
  }

  void _registerAppBarActions() {
    context.read<PageActions>().set(widget.key!, <Widget>[
      IconButton(
        icon: const Icon(Icons.auto_awesome_outlined),
        tooltip: 'Generar presupuestos con histórico',
        onPressed: _openAutoBudgetSheet,
      ),
      IconButton(
        icon: _isApplyingRules
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            : const Icon(Icons.rule_folder_outlined),
        tooltip: 'Asignar reglas a gastos del mes',
        onPressed: _isApplyingRules ? null : _applyRulesToCurrentMonth,
      ),
      IconButton(
        icon: const Icon(Icons.add),
        tooltip: 'Nuevo presupuesto',
        onPressed: _openAddBudgetDialog,
      ),
    ]);
  }

  Future<void> _fetchBudgets() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final FireflyService ff = context.read<FireflyService>();
    final FireflyIii api = ff.api;

    final DateTime startOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );
    final DateTime endOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    );

    final String startStr = DateFormat(
      'yyyy-MM-dd',
      'en_US',
    ).format(startOfMonth);
    final String endStr = DateFormat('yyyy-MM-dd', 'en_US').format(endOfMonth);

    try {
      final (
        Response<BudgetArray> respBudgets,
        Response<BudgetLimitArray> respLimits,
      ) = await (
        api.v1BudgetsGet(start: startStr, end: endStr, limit: 100),
        api.v1BudgetLimitsGet(start: startStr, end: endStr),
      ).wait;

      final Map<String, BudgetLimitRead> limitsMap =
          <String, BudgetLimitRead>{};
      for (final BudgetLimitRead limit
          in respLimits.body?.data ?? <BudgetLimitRead>[]) {
        final String? bId = limit.attributes.budgetId;
        if (bId != null) {
          limitsMap[bId] = limit;
        }
      }

      final List<BudgetRead> budgetsList = List<BudgetRead>.from(
        respBudgets.body?.data ?? <BudgetRead>[],
      );

      // Helper para obtener gasto y límite asignado
      double getBudgetSpent(BudgetRead b) {
        final BudgetLimitRead? limit = limitsMap[b.id];
        if (limit?.attributes.spent?.isNotEmpty ?? false) {
          return (double.tryParse(limit!.attributes.spent!.first.sum ?? '') ??
                  0.0)
              .abs();
        } else if (b.attributes.spent?.isNotEmpty ?? false) {
          return (double.tryParse(b.attributes.spent!.first.sum ?? '') ?? 0.0)
              .abs();
        }
        return 0.0;
      }

      double getBudgetLimit(BudgetRead b) {
        final BudgetLimitRead? limit = limitsMap[b.id];
        if (limit != null) {
          return double.tryParse(limit.attributes.amount ?? '') ?? 0.0;
        } else if (b.attributes.autoBudgetAmount != null) {
          return double.tryParse(b.attributes.autoBudgetAmount!) ?? 0.0;
        }
        return 0.0;
      }

      // Ordenar por presupuesto asignado (límite) descendente y luego por gasto consumido descendente
      budgetsList.sort((BudgetRead a, BudgetRead b) {
        final double limitA = getBudgetLimit(a);
        final double limitB = getBudgetLimit(b);
        if (limitA != limitB) {
          return limitB.compareTo(limitA);
        }
        final double spentA = getBudgetSpent(a);
        final double spentB = getBudgetSpent(b);
        if (spentA != spentB) {
          return spentB.compareTo(spentA);
        }
        return a.attributes.name.compareTo(b.attributes.name);
      });

      if (mounted) {
        setState(() {
          _budgets = budgetsList;
          _limitsByBudgetId
            ..clear()
            ..addAll(limitsMap);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
    });
    _fetchBudgets();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );
    });
    _fetchBudgets();
  }

  void _currentMonth() {
    final DateTime now = context
        .read<FireflyService>()
        .tzHandler
        .sNow()
        .clearTime();
    setState(() {
      _selectedMonth = DateTime(now.year, now.month, 1);
    });
    _fetchBudgets();
  }

  bool get _isCurrentMonth {
    final DateTime now = context
        .read<FireflyService>()
        .tzHandler
        .sNow()
        .clearTime();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  Future<void> _openAutoBudgetSheet() async {
    final bool? changed = await AutoBudgetSheet.show(
      context,
      selectedMonth: _selectedMonth,
    );
    if (changed ?? false) {
      await _fetchBudgets();
    }
  }

  Future<void> _openAddBudgetDialog() async {
    final bool? changed = await AddEditBudgetDialog.show(
      context,
      selectedMonth: _selectedMonth,
    );
    if (changed ?? false) {
      await _fetchBudgets();
    }
  }

  Future<void> _applyRulesToCurrentMonth() async {
    if (_isApplyingRules) return;

    final String monthName = DateFormat(
      'MMMM yyyy',
      'es_ES',
    ).format(_selectedMonth);
    final String formattedMonth =
        monthName.substring(0, 1).toUpperCase() + monthName.substring(1);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Asignar reglas retroactivamente'),
        content: Text(
          'Se ejecutarán las reglas de presupuestos de Firefly III sobre todos los movimientos de $formattedMonth para vincular automáticamente cada gasto a su presupuesto correspondiente.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: FtColors.coralOf(context),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Asignar reglas'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false) || !mounted) return;

    setState(() {
      _isApplyingRules = true;
    });
    _registerAppBarActions();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aplicando reglas de presupuestos a los movimientos...'),
        duration: Duration(seconds: 2),
      ),
    );

    final FireflyService ff = context.read<FireflyService>();
    final FireflyIii api = ff.api;

    final DateTime startOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );
    final DateTime endOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    );

    final String startStr = DateFormat(
      'yyyy-MM-dd',
      'en_US',
    ).format(startOfMonth);
    final String endStr = DateFormat('yyyy-MM-dd', 'en_US').format(endOfMonth);

    try {
      // 1. Obtener todas las reglas existentes en Firefly III
      final List<RuleRead> budgetRules = <RuleRead>[];
      int rPage = 1;
      while (true) {
        final Response<RuleArray> rulesResp = await api.v1RulesGet(page: rPage);
        for (final RuleRead r in rulesResp.body?.data ?? <RuleRead>[]) {
          final bool hasBudgetAction = r.attributes.actions.any(
            (RuleAction a) => a.type == RuleActionKeyword.setBudget,
          );
          if (hasBudgetAction && (r.attributes.active ?? true)) {
            budgetRules.add(r);
          }
        }
        final int totalPages = rulesResp.body?.meta.pagination?.totalPages ?? 1;
        if (rPage >= totalPages || (rulesResp.body?.data.isEmpty ?? true)) {
          break;
        }
        rPage++;
      }

      // 2. Disparar cada regla sobre el rango de fechas del mes seleccionado
      int executedCount = 0;
      for (final RuleRead rule in budgetRules) {
        try {
          await api.v1RulesIdTriggerPost(
            id: rule.id,
            start: startStr,
            end: endStr,
          );
          executedCount++;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isApplyingRules = false;
        });
        _registerAppBarActions();
        await _fetchBudgets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                executedCount > 0
                    ? 'Reglas aplicadas con éxito ($executedCount reglas procesadas).'
                    : 'No se encontraron reglas activas de presupuesto en Firefly III.',
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isApplyingRules = false;
        });
        _registerAppBarActions();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aplicar reglas: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsProvider>();
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;

    // Totales globales
    double totalLimit = 0.0;
    double totalSpent = 0.0;

    for (final BudgetRead b in _budgets) {
      final BudgetLimitRead? limit = _limitsByBudgetId[b.id];
      if (limit != null) {
        totalLimit += double.tryParse(limit.attributes.amount ?? '') ?? 0.0;
        if (limit.attributes.spent?.isNotEmpty ?? false) {
          totalSpent +=
              (double.tryParse(limit.attributes.spent!.first.sum ?? "") ?? 0.0)
                  .abs();
        } else if (b.attributes.spent?.isNotEmpty ?? false) {
          totalSpent +=
              (double.tryParse(b.attributes.spent!.first.sum ?? "") ?? 0.0)
                  .abs();
        }
      } else if (b.attributes.autoBudgetAmount != null) {
        totalLimit += double.tryParse(b.attributes.autoBudgetAmount!) ?? 0.0;
        if (b.attributes.spent?.isNotEmpty ?? false) {
          totalSpent +=
              (double.tryParse(b.attributes.spent!.first.sum ?? "") ?? 0.0)
                  .abs();
        }
      } else if (b.attributes.spent?.isNotEmpty ?? false) {
        totalSpent +=
            (double.tryParse(b.attributes.spent!.first.sum ?? "") ?? 0.0).abs();
      }
    }

    final double totalRemaining = totalLimit - totalSpent;
    final double globalProgress = totalLimit > 0
        ? (totalSpent / totalLimit)
        : 0.0;
    final bool isGlobalOver = totalSpent > totalLimit;

    Color globalBarColor;
    if (globalProgress <= 0.75) {
      globalBarColor = Colors.green;
    } else if (globalProgress <= 1.0) {
      globalBarColor = Colors.orange;
    } else {
      globalBarColor = FtColors.coralOf(context);
    }

    // Cálculo de días restantes si es mes actual
    final DateTime now = context
        .read<FireflyService>()
        .tzHandler
        .sNow()
        .clearTime();
    final int lastDayOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final int daysRemaining = _isCurrentMonth
        ? (lastDayOfMonth - now.day + 1).clamp(1, 31)
        : 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _fetchBudgets,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Selector de mes
              _buildMonthSelector(context),
              const SizedBox(height: 12),

              // Tarjeta Resumen Global
              if (!_isLoading && _budgets.isNotEmpty) ...<Widget>[
                _buildGlobalSummaryCard(
                  context,
                  currency: currency,
                  totalLimit: totalLimit,
                  totalSpent: totalSpent,
                  totalRemaining: totalRemaining,
                  globalProgress: globalProgress,
                  globalBarColor: globalBarColor,
                  isGlobalOver: isGlobalOver,
                  daysRemaining: daysRemaining,
                ),
                const SizedBox(height: 20),
              ],

              // Estado de carga o error
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: <Widget>[
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text('Error al cargar presupuestos: $_error'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _fetchBudgets,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_budgets.isEmpty)
                _buildEmptyState(context)
              else
                _buildBudgetsList(context, currency),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    final String monthName = DateFormat(
      'MMMM yyyy',
      'es_ES',
    ).format(_selectedMonth);
    final String capitalizedMonth =
        monthName.substring(0, 1).toUpperCase() + monthName.substring(1);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Mes anterior',
              onPressed: _previousMonth,
            ),
            InkWell(
              onTap: _currentMonth,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      capitalizedMonth,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!_isCurrentMonth) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Hoy',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Mes siguiente',
              onPressed: _nextMonth,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalSummaryCard(
    BuildContext context, {
    required CurrencyRead currency,
    required double totalLimit,
    required double totalSpent,
    required double totalRemaining,
    required double globalProgress,
    required Color globalBarColor,
    required bool isGlobalOver,
    required int daysRemaining,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'PRESUPUESTO GLOBAL',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currency.fmt(totalSpent, decimalDigits: 0, context: context)} / ${currency.fmt(totalLimit, decimalDigits: 0, context: context)}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: globalBarColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(globalProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: globalBarColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FtProgressBar(
              progress: globalProgress,
              color: globalBarColor,
              height: 8,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      isGlobalOver
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      size: 16,
                      color: isGlobalOver
                          ? FtColors.coralOf(context)
                          : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isGlobalOver
                          ? 'Superado en ${currency.fmt(totalRemaining.abs(), decimalDigits: 0, context: context)}'
                          : 'Disponible: ${currency.fmt(totalRemaining, decimalDigits: 0, context: context)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isGlobalOver ? FtColors.coralOf(context) : null,
                      ),
                    ),
                  ],
                ),
                if (_isCurrentMonth && !isGlobalOver && totalRemaining > 0)
                  Text(
                    '~${currency.fmt(totalRemaining / daysRemaining, decimalDigits: 0, context: context)}/día ($daysRemaining d)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FtColors.coralOf(context).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.donut_large_outlined,
                size: 56,
                color: FtColors.coralOf(context),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aún no tienes presupuestos',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Establece límites de gasto mensuales para tener un control total de tus finanzas. Puedes generarlos automáticamente analizando tus movimientos de los últimos meses o crearlos a mano.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generar con mi histórico'),
              style: FilledButton.styleFrom(
                backgroundColor: FtColors.coralOf(context),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _openAutoBudgetSheet,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Crear presupuesto manual'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _openAddBudgetDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetsList(BuildContext context, CurrencyRead currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'MIS PRESUPUESTOS (${_budgets.length})',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextButton.icon(
                    icon: _isApplyingRules
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.rule_folder_outlined, size: 16),
                    label: const Text(
                      'Aplicar reglas',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: _isApplyingRules
                        ? null
                        : _applyRulesToCurrentMonth,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text(
                      'Auto-ajustar',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: FtColors.coralOf(context),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: _openAutoBudgetSheet,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _budgets.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (BuildContext ctx, int index) {
            final BudgetRead budget = _budgets[index];
            final BudgetLimitRead? limit = _limitsByBudgetId[budget.id];

            final String name = budget.attributes.name;
            final IconData icon = FtCategoryIcon.forName(name);
            final Color catColor = FtColors.categoryColor(
              name,
              context: context,
            );

            final double limitAmount = limit != null
                ? (double.tryParse(limit.attributes.amount ?? '') ?? 0.0)
                : (double.tryParse(budget.attributes.autoBudgetAmount ?? '') ??
                      0.0);

            double spentAmount = 0.0;
            if (limit?.attributes.spent?.isNotEmpty ?? false) {
              spentAmount =
                  (double.tryParse(limit!.attributes.spent!.first.sum ?? "") ??
                          0.0)
                      .abs();
            } else if (budget.attributes.spent?.isNotEmpty ?? false) {
              spentAmount =
                  (double.tryParse(budget.attributes.spent!.first.sum ?? "") ??
                          0.0)
                      .abs();
            }

            final double progress = limitAmount > 0
                ? (spentAmount / limitAmount)
                : 0.0;
            final bool isOver = spentAmount > limitAmount;

            Color barColor;
            if (progress <= 0.75) {
              barColor = Colors.green;
            } else if (progress <= 1.0) {
              barColor = Colors.orange;
            } else {
              barColor = FtColors.coralOf(context);
            }

            return Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () async {
                  final bool? changed = await BudgetOptionsSheet.show(
                    context,
                    budget: budget,
                    limit: limit,
                    selectedMonth: _selectedMonth,
                    onOpenTransactions: widget.onOpenBudgetTransactions,
                  );
                  if (changed ?? false) {
                    await _fetchBudgets();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          FtCategoryIconWidget(
                            icon: icon,
                            color: catColor,
                            size: 22,
                            padding: 10,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${currency.fmt(spentAmount, decimalDigits: 0, context: context)} de ${currency.fmt(limitAmount, decimalDigits: 0, context: context)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
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
                                    ? '+${currency.fmt(spentAmount - limitAmount, decimalDigits: 0, context: context)}'
                                    : currency.fmt(
                                        limitAmount - spentAmount,
                                        decimalDigits: 0,
                                        context: context,
                                      ),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: isOver
                                      ? FtColors.coralOf(context)
                                      : null,
                                ),
                              ),
                              Text(
                                isOver ? 'Excedido' : 'Restante',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FtProgressBar(
                        progress: progress,
                        color: barColor,
                        height: 5,
                      ),
                      if (limit == null) ...<Widget>[
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Sin límite explícito este mes (usando base)',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

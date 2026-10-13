import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';

class _CategoryBudgetItem {
  final String name;
  final double totalSpent;
  final double monthlyAverage;
  double suggestedLimit;
  bool isSelected;
  final TextEditingController controller;

  _CategoryBudgetItem({
    required this.name,
    required this.totalSpent,
    required this.monthlyAverage,
    required this.suggestedLimit,
    this.isSelected = true,
  }) : controller = TextEditingController(
         text: suggestedLimit.toStringAsFixed(0),
       );
}

class AutoBudgetSheet extends StatefulWidget {
  final DateTime selectedMonth;

  const AutoBudgetSheet({super.key, required this.selectedMonth});

  static Future<bool?> show(
    BuildContext context, {
    required DateTime selectedMonth,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) =>
          AutoBudgetSheet(selectedMonth: selectedMonth),
    );
  }

  @override
  State<AutoBudgetSheet> createState() => _AutoBudgetSheetState();
}

class _AutoBudgetSheetState extends State<AutoBudgetSheet> {
  int _monthsHorizon = 3;
  bool _isLoading = true;
  bool _isApplying = false;
  String _applyingStatus = "";

  bool _createRules = true;
  bool _retroApplyThisMonth = true;

  List<_CategoryBudgetItem> _items = <_CategoryBudgetItem>[];

  @override
  void initState() {
    super.initState();
    _calculateHistoricalBudgets();
  }

  @override
  void dispose() {
    for (_CategoryBudgetItem item in _items) {
      item.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _calculateHistoricalBudgets() async {
    setState(() {
      _isLoading = true;
    });

    final FireflyService ff = context.read<FireflyService>();
    final FireflyIii api = ff.api;
    final CurrencyRead currency = ff.defaultCurrency;

    final DateTime now = ff.tzHandler.sNow().clearTime();
    final Map<String, double> categorySums = <String, double>{};

    try {
      // Analizar los N meses anteriores
      for (int i = 1; i <= _monthsHorizon; i++) {
        final DateTime monthDate = DateTime(now.year, now.month - i, 1);
        final DateTime monthEnd = DateTime(now.year, now.month - i + 1, 0);

        final String startStr = DateFormat(
          'yyyy-MM-dd',
          'en_US',
        ).format(monthDate);
        final String endStr = DateFormat(
          'yyyy-MM-dd',
          'en_US',
        ).format(monthEnd);

        final Response<InsightGroup> resp = await api
            .v1InsightExpenseCategoryGet(start: startStr, end: endStr);

        if (resp.body != null) {
          for (final InsightGroupEntry entry in resp.body!) {
            if (entry.currencyId != null && entry.currencyId != currency.id) {
              continue;
            }
            final String name = (entry.name ?? '').trim();
            if (name.isEmpty) continue;
            final double amount = (entry.differenceFloat ?? 0.0).abs();
            if (amount > 0) {
              categorySums[name] = (categorySums[name] ?? 0.0) + amount;
            }
          }
        }
      }

      // Desechar controladores anteriores
      for (_CategoryBudgetItem item in _items) {
        item.controller.dispose();
      }

      final List<_CategoryBudgetItem> newItems = <_CategoryBudgetItem>[];
      for (final MapEntry<String, double> entry in categorySums.entries) {
        final double avg = entry.value / _monthsHorizon;
        if (avg < 5.0) continue; // Ignorar categorías con menos de 5€/mes

        // Redondear hacia arriba al múltiplo de 5 o 10 más próximo
        double suggested;
        if (avg < 50) {
          suggested = ((avg / 5).ceil() * 5).toDouble();
        } else {
          suggested = ((avg / 10).ceil() * 10).toDouble();
        }
        if (suggested < 10) suggested = 10;

        newItems.add(
          _CategoryBudgetItem(
            name: entry.key,
            totalSpent: entry.value,
            monthlyAverage: avg,
            suggestedLimit: suggested,
            // Desmarcar por defecto gastos grandes recurrentes tipo hipoteca que no suelen variar
            isSelected: !entry.key.toLowerCase().contains('hipoteca'),
          ),
        );
      }

      // Ordenar por gasto medio descendente
      newItems.sort(
        (_CategoryBudgetItem a, _CategoryBudgetItem b) =>
            b.monthlyAverage.compareTo(a.monthlyAverage),
      );

      if (mounted) {
        setState(() {
          _items = newItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al calcular histórico: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _applyBudgets() async {
    final List<_CategoryBudgetItem> selected = _items
        .where((_CategoryBudgetItem i) => i.isSelected)
        .toList();
    if (selected.isEmpty) {
      return;
    }

    setState(() {
      _isApplying = true;
      _applyingStatus = "Preparando presupuestos...";
    });

    final FireflyService ff = context.read<FireflyService>();
    final FireflyIii api = ff.api;
    final CurrencyRead currency = ff.defaultCurrency;

    final DateTime startOfMonth = DateTime(
      widget.selectedMonth.year,
      widget.selectedMonth.month,
      1,
    );
    final DateTime endOfMonth = DateTime(
      widget.selectedMonth.year,
      widget.selectedMonth.month + 1,
      0,
    );
    final String startStr = DateFormat(
      'yyyy-MM-dd',
      'en_US',
    ).format(startOfMonth);
    final String endStr = DateFormat('yyyy-MM-dd', 'en_US').format(endOfMonth);

    try {
      // 1. Obtener presupuestos existentes (con paginacion)
      setState(
        () => _applyingStatus = "Consultando presupuestos existentes...",
      );
      final Map<String, BudgetRead> existingBudgets = <String, BudgetRead>{};
      int bPage = 1;
      while (true) {
        final Response<BudgetArray> budgetsResp = await api.v1BudgetsGet(
          page: bPage,
        );
        for (BudgetRead b in budgetsResp.body?.data ?? <BudgetRead>[]) {
          existingBudgets[b.attributes.name.trim().toLowerCase()] = b;
        }
        final int totalPages =
            budgetsResp.body?.meta.pagination?.totalPages ?? 1;
        if (bPage >= totalPages || (budgetsResp.body?.data.isEmpty ?? true)) {
          break;
        }
        bPage++;
      }

      // 2. Obtener grupo de reglas si se activaron reglas o asignacion retroactiva
      String ruleGroupId = "1";
      final Map<String, RuleRead> existingCategoryRules = <String, RuleRead>{};
      if (_createRules || _retroApplyThisMonth) {
        setState(() => _applyingStatus = "Consultando reglas en Firefly...");
        try {
          final Response<RuleGroupArray> groupsResp = await api
              .v1RuleGroupsGet();
          if (groupsResp.body != null && groupsResp.body!.data.isNotEmpty) {
            ruleGroupId = groupsResp.body!.data.first.id;
          }
          int rPage = 1;
          while (true) {
            final Response<RuleArray> rulesResp = await api.v1RulesGet(
              page: rPage,
            );
            for (RuleRead r in rulesResp.body?.data ?? <RuleRead>[]) {
              for (RuleTrigger t in r.attributes.triggers) {
                if (t.type == RuleTriggerKeyword.categoryIs &&
                    t.value.isNotEmpty) {
                  existingCategoryRules[t.value.trim().toLowerCase()] = r;
                }
              }
            }
            final int totalPages =
                rulesResp.body?.meta.pagination?.totalPages ?? 1;
            if (rPage >= totalPages || (rulesResp.body?.data.isEmpty ?? true)) {
              break;
            }
            rPage++;
          }
        } catch (_) {}
      }

      // 3. Crear o actualizar presupuestos y límites
      int appliedCount = 0;
      for (final _CategoryBudgetItem item in selected) {
        setState(
          () => _applyingStatus =
              "Configurando presupuesto (${appliedCount + 1}/${selected.length}): ${item.name}",
        );

        final double amount =
            double.tryParse(item.controller.text.replaceAll(',', '.')) ??
            item.suggestedLimit;
        final String normName = item.name.trim().toLowerCase();

        String budgetId;
        if (existingBudgets.containsKey(normName)) {
          final BudgetRead existing = existingBudgets[normName]!;
          budgetId = existing.id;
          await api.v1BudgetsIdPut(
            id: budgetId,
            body: BudgetUpdate(
              name: item.name,
              autoBudgetType: AutoBudgetType.reset,
              autoBudgetPeriod: AutoBudgetPeriod.monthly,
              autoBudgetAmount: amount.toStringAsFixed(2),
              autoBudgetCurrencyId: currency.id,
            ),
          );
        } else {
          final Response<BudgetSingle> createResp = await api.v1BudgetsPost(
            body: BudgetStore(
              name: item.name,
              autoBudgetType: AutoBudgetType.reset,
              autoBudgetPeriod: AutoBudgetPeriod.monthly,
              autoBudgetAmount: amount.toStringAsFixed(2),
              autoBudgetCurrencyId: currency.id,
            ),
          );
          budgetId = createResp.body!.data.id;
        }

        // Crear o actualizar límite del mes seleccionado
        final Response<BudgetLimitArray> limitsResp = await api
            .v1BudgetsIdLimitsGet(id: budgetId, start: startStr, end: endStr);

        if (limitsResp.body?.data.isNotEmpty ?? false) {
          final BudgetLimitRead currentLimit = limitsResp.body!.data.first;
          await api.v1BudgetsIdLimitsLimitIdPut(
            id: budgetId,
            limitId: currentLimit.id,
            body: BudgetLimitUpdate(
              start: startOfMonth,
              end: endOfMonth,
              amount: amount.toStringAsFixed(2),
              currencyId: currency.id,
            ),
          );
        } else {
          await api.v1BudgetsIdLimitsPost(
            id: budgetId,
            body: BudgetLimitStore(
              start: startOfMonth,
              end: endOfMonth,
              amount: amount.toStringAsFixed(2),
              currencyId: currency.id,
            ),
          );
        }

        // Crear regla en Firefly III si no existe y esta habilitado
        String? ruleId;
        if (existingCategoryRules.containsKey(normName)) {
          ruleId = existingCategoryRules[normName]!.id;
        } else if (_createRules || _retroApplyThisMonth) {
          try {
            final Response<RuleSingle> newRuleResp = await api.v1RulesPost(
              body: RuleStore(
                title: "Presupuesto: ${item.name}",
                ruleGroupId: ruleGroupId,
                trigger: RuleTriggerType.storeJournal,
                strict: false,
                active: true,
                triggers: <RuleTriggerStore>[
                  RuleTriggerStore(
                    type: RuleTriggerKeyword.categoryIs,
                    value: item.name,
                  ),
                ],
                actions: <RuleActionStore>[
                  RuleActionStore(
                    type: RuleActionKeyword.setBudget,
                    value: item.name,
                  ),
                ],
              ),
            );
            ruleId = newRuleResp.body?.data.id;
            if (ruleId != null && newRuleResp.body?.data != null) {
              existingCategoryRules[normName] = newRuleResp.body!.data;
            }
          } catch (e) {
            log.warning("Error creando regla para ${item.name}: $e");
          }
        }

        // Disparar regla sobre los movimientos del mes actual si está marcado
        if (_retroApplyThisMonth && ruleId != null) {
          try {
            final Response<dynamic> triggerResp = await api
                .v1RulesIdTriggerPost(id: ruleId, start: startStr, end: endStr);
            if (!triggerResp.isSuccessful) {
              log.warning(
                "Trigger regla $ruleId fallo: ${triggerResp.statusCode} ${triggerResp.error}",
              );
            }
          } catch (e) {
            log.warning("Error disparando regla $ruleId: $e");
          }
        }

        appliedCount++;
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$appliedCount presupuestos generados y actualizados con éxito.',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aplicar presupuestos: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    final int selectedCount = _items
        .where((_CategoryBudgetItem i) => i.isSelected)
        .length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: <Widget>[
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome,
                  color: FtColors.coralOf(context),
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Generar presupuestos',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Calculado según tus gastos de los últimos meses',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _isApplying ? null : () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Period toggle chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: <Widget>[
                const Text(
                  'Analizar:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Últimos 3 meses'),
                  selected: _monthsHorizon == 3,
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  onSelected: _isApplying
                      ? null
                      : (bool sel) {
                          if (sel && _monthsHorizon != 3) {
                            setState(() {
                              _monthsHorizon = 3;
                            });
                            _calculateHistoricalBudgets();
                          }
                        },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Últimos 6 meses'),
                  selected: _monthsHorizon == 6,
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  onSelected: _isApplying
                      ? null
                      : (bool sel) {
                          if (sel && _monthsHorizon != 6) {
                            setState(() {
                              _monthsHorizon = 6;
                            });
                            _calculateHistoricalBudgets();
                          }
                        },
                ),
              ],
            ),
          ),

          // Option switches
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: <Widget>[
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: FtColors.coralOf(context),
                  title: const Text('Crear regla automática en Firefly'),
                  subtitle: const Text(
                    'Asignará futuros gastos con esta categoría a su presupuesto',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _createRules,
                  onChanged: _isApplying
                      ? null
                      : (bool val) {
                          setState(() {
                            _createRules = val;
                          });
                        },
                ),
                if (_createRules)
                  SwitchListTile.adaptive(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: FtColors.coralOf(context),
                    title: const Text('Asignar gastos del mes actual'),
                    subtitle: const Text(
                      'Aplica la regla retroactivamente sobre los movimientos de este mes',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _retroApplyThisMonth,
                    onChanged: _isApplying
                        ? null
                        : (bool val) {
                            setState(() {
                              _retroApplyThisMonth = val;
                            });
                          },
                  ),
              ],
            ),
          ),

          const Divider(height: 12),

          // Content body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        CircularProgressIndicator.adaptive(),
                        SizedBox(height: 16),
                        Text('Analizando tus movimientos anteriores...'),
                      ],
                    ),
                  )
                : _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No se encontraron gastos en los últimos $_monthsHorizon meses para generar presupuestos.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const Divider(height: 8),
                    itemBuilder: (BuildContext ctx, int index) {
                      final _CategoryBudgetItem item = _items[index];
                      final IconData icon = FtCategoryIcon.forName(item.name);
                      final Color catColor = FtColors.categoryColor(
                        item.name,
                        context: context,
                      );

                      return Row(
                        children: <Widget>[
                          Checkbox.adaptive(
                            value: item.isSelected,
                            activeColor: FtColors.coralOf(context),
                            onChanged: _isApplying
                                ? null
                                : (bool? val) {
                                    setState(() {
                                      item.isSelected = val ?? false;
                                    });
                                  },
                          ),
                          FtCategoryIconWidget(
                            icon: icon,
                            color: catColor,
                            size: 20,
                            padding: 8,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Media: ${currency.fmt(item.monthlyAverage, decimalDigits: 0, context: context)} / mes',
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
                          SizedBox(
                            width: 90,
                            child: TextFormField(
                              controller: item.controller,
                              enabled: item.isSelected && !_isApplying,
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(
                                isDense: true,
                                suffixText: ' €',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Bottom action footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                if (_isApplying)
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _applyingStatus,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...<Widget>[
                  Text(
                    '$selectedCount seleccionados',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: FtColors.coralOf(context),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: selectedCount > 0 ? _applyBudgets : null,
                    child: const Text(
                      'Aplicar presupuestos',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

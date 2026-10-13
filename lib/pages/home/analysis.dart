import 'dart:async';

import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/offline_cache.dart';
import 'package:waterflyiii/settings.dart';
import 'package:waterflyiii/pages/home/analysis_period.dart';
import 'package:waterflyiii/pages/home/category_detail.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';
import 'package:waterflyiii/widgets/ft_progress_bar.dart';
import 'package:waterflyiii/widgets/monthly_bars.dart';

/// Categoría agregada (gasto o ingreso).
class _CategorySpend {
  const _CategorySpend(this.name, this.amount);
  final String name;
  final double amount; // positivo
}

enum AnalysisCategoryType { expense, income }

class _AnalysisData {
  const _AnalysisData({
    required this.bars,
    required this.expenseCategoriesByBucket,
    required this.incomeCategoriesByBucket,
    this.budgetByBucket = const <double?>[],
  });
  final List<MonthBarData> bars;
  final List<List<_CategorySpend>> expenseCategoriesByBucket;
  final List<List<_CategorySpend>> incomeCategoriesByBucket;
  final List<double?> budgetByBucket;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'bars': bars
        .map(
          (MonthBarData b) => <String, dynamic>{
            'label': b.label,
            'income': b.income,
            'expense': b.expense,
          },
        )
        .toList(),
    'categoriesByBucket': expenseCategoriesByBucket
        .map(
          (List<_CategorySpend> list) => list
              .map(
                (_CategorySpend c) => <String, dynamic>{
                  'name': c.name,
                  'amount': c.amount,
                },
              )
              .toList(),
        )
        .toList(),
    'expenseCategoriesByBucket': expenseCategoriesByBucket
        .map(
          (List<_CategorySpend> list) => list
              .map(
                (_CategorySpend c) => <String, dynamic>{
                  'name': c.name,
                  'amount': c.amount,
                },
              )
              .toList(),
        )
        .toList(),
    'incomeCategoriesByBucket': incomeCategoriesByBucket
        .map(
          (List<_CategorySpend> list) => list
              .map(
                (_CategorySpend c) => <String, dynamic>{
                  'name': c.name,
                  'amount': c.amount,
                },
              )
              .toList(),
        )
        .toList(),
    'budgetByBucket': budgetByBucket,
  };

  factory _AnalysisData.fromJson(Map<String, dynamic> json) => _AnalysisData(
    bars:
        (json['bars'] as List<dynamic>?)
            ?.map(
              (dynamic b) => MonthBarData(
                label: (b as Map<String, dynamic>)['label'] as String? ?? '',
                income: (b['income'] as num?)?.toDouble() ?? 0.0,
                expense: (b['expense'] as num?)?.toDouble() ?? 0.0,
              ),
            )
            .toList() ??
        <MonthBarData>[],
    expenseCategoriesByBucket:
        (json['expenseCategoriesByBucket'] as List<dynamic>? ??
                json['categoriesByBucket'] as List<dynamic>?)
            ?.map(
              (dynamic list) => (list as List<dynamic>)
                  .map(
                    (dynamic c) => _CategorySpend(
                      (c as Map<String, dynamic>)['name'] as String? ?? '',
                      (c['amount'] as num?)?.toDouble() ?? 0.0,
                    ),
                  )
                  .toList(),
            )
            .toList() ??
        <List<_CategorySpend>>[],
    incomeCategoriesByBucket:
        (json['incomeCategoriesByBucket'] as List<dynamic>?)
            ?.map(
              (dynamic list) => (list as List<dynamic>)
                  .map(
                    (dynamic c) => _CategorySpend(
                      (c as Map<String, dynamic>)['name'] as String? ?? '',
                      (c['amount'] as num?)?.toDouble() ?? 0.0,
                    ),
                  )
                  .toList(),
            )
            .toList() ??
        <List<_CategorySpend>>[],
    budgetByBucket:
        (json['budgetByBucket'] as List<dynamic>?)
            ?.map((dynamic b) => (b as num?)?.toDouble())
            .toList() ??
        const <double?>[],
  );
}

class HomeAnalysis extends StatefulWidget {
  const HomeAnalysis({super.key});

  @override
  State<HomeAnalysis> createState() => _HomeAnalysisState();
}

class _HomeAnalysisState extends State<HomeAnalysis>
    with AutomaticKeepAliveClientMixin {
  AnalysisPeriod _period = AnalysisPeriod.month;
  AnalysisCategoryType _categoryType = AnalysisCategoryType.expense;
  DateTimeRange? _custom;
  int _offset = 0;
  late List<PeriodBucket> _buckets;
  late int _selected;
  late Future<_AnalysisData> _future;
  List<MonthBarData>? _cachedBars;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _buckets = generateBuckets(_period, custom: _custom, offset: _offset);
    _selected = _buckets.length - 1;
    _future = _fetch();
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd', 'en_US').format(d);

  Future<_AnalysisData> _fetch() async {
    final FireflyIii api = context.read<FireflyService>().api;
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;

    double sumTotal(Response<InsightTotal> resp) {
      double s = 0;
      for (final InsightTotalEntry e in resp.body ?? <InsightTotalEntry>[]) {
        if (e.currencyId != null && e.currencyId != currency.id) {
          continue;
        }
        s += (e.differenceFloat ?? 0).abs();
      }
      return s;
    }

    List<_CategorySpend> parseGroup(Response<InsightGroup> catResp) {
      final List<_CategorySpend> cats = <_CategorySpend>[];
      for (final InsightGroupEntry e in catResp.body ?? <InsightGroupEntry>[]) {
        if (e.currencyId != null && e.currencyId != currency.id) {
          continue;
        }
        final double amount = (e.differenceFloat ?? 0).abs();
        if (amount <= 0) {
          continue;
        }
        cats.add(_CategorySpend(e.name ?? '—', amount));
      }
      cats.sort(
        (_CategorySpend a, _CategorySpend b) => b.amount.compareTo(a.amount),
      );
      return cats;
    }

    try {
      // Totales por periodo para las barras (solo si no están en caché).
      List<MonthBarData> bars;
      if (_cachedBars != null) {
        bars = _cachedBars!;
      } else {
        bars = await Future.wait(
          _buckets.map((PeriodBucket b) async {
            final (
              Response<InsightTotal> inc,
              Response<InsightTotal> exp,
            ) = await (
              api.v1InsightIncomeTotalGet(
                start: _fmt(b.start),
                end: _fmt(b.end),
              ),
              api.v1InsightExpenseTotalGet(
                start: _fmt(b.start),
                end: _fmt(b.end),
              ),
            ).wait;
            return MonthBarData(
              label: b.shortLabel,
              income: sumTotal(inc),
              expense: sumTotal(exp),
            );
          }),
        );
        _cachedBars = bars;
      }

      // Categorías de gastos e ingresos concurrentemente.
      final List<(List<_CategorySpend>, List<_CategorySpend>)> allCats =
          await Future.wait(
            _buckets.map((PeriodBucket b) async {
              final (
                Response<InsightGroup> expCatResp,
                Response<InsightGroup> incCatResp,
              ) = await (
                api.v1InsightExpenseCategoryGet(
                  start: _fmt(b.start),
                  end: _fmt(b.end),
                ),
                api.v1InsightIncomeCategoryGet(
                  start: _fmt(b.start),
                  end: _fmt(b.end),
                ),
              ).wait;
              return (parseGroup(expCatResp), parseGroup(incCatResp));
            }),
          );

      final List<List<_CategorySpend>> allExpenseCats = allCats
          .map(((List<_CategorySpend>, List<_CategorySpend>) p) => p.$1)
          .toList();
      final List<List<_CategorySpend>> allIncomeCats = allCats
          .map(((List<_CategorySpend>, List<_CategorySpend>) p) => p.$2)
          .toList();

      final List<double?> budgetByBucket = List<double?>.filled(
        _buckets.length,
        null,
      );
      if (_period == AnalysisPeriod.month) {
        try {
          final List<Response<BudgetLimitArray>> limitsResp = await Future.wait(
            _buckets.map(
              (PeriodBucket b) =>
                  api.v1BudgetLimitsGet(start: _fmt(b.start), end: _fmt(b.end)),
            ),
          );
          for (int i = 0; i < _buckets.length; i++) {
            final List<BudgetLimitRead> limits =
                limitsResp[i].body?.data ?? <BudgetLimitRead>[];
            if (limits.isNotEmpty) {
              double sum = 0.0;
              for (final BudgetLimitRead l in limits) {
                sum += double.tryParse(l.attributes.amount ?? '') ?? 0.0;
              }
              if (sum > 0) {
                budgetByBucket[i] = sum;
              }
            }
          }
        } catch (_) {}
      }

      final _AnalysisData res = _AnalysisData(
        bars: bars,
        expenseCategoriesByBucket: allExpenseCats,
        incomeCategoriesByBucket: allIncomeCats,
        budgetByBucket: budgetByBucket,
      );
      final String cacheKey =
          'analysis_${_period.name}${_offset > 0 ? '_$_offset' : ''}';
      unawaited(OfflineCache.instance.saveJson(cacheKey, res.toJson()));
      return res;
    } catch (e) {
      final String cacheKey =
          'analysis_${_period.name}${_offset > 0 ? '_$_offset' : ''}';
      final dynamic cached = await OfflineCache.instance.getJson(cacheKey);
      if (cached is Map<String, dynamic>) {
        final _AnalysisData cachedData = _AnalysisData.fromJson(cached);
        if (cachedData.bars.isNotEmpty) {
          return cachedData;
        }
      }
      rethrow;
    }
  }

  void _reload() {
    _cachedBars = null;
    setState(() => _future = _fetch());
  }

  Future<void> _refresh() async {
    _reload();
    await _future;
  }

  void _onSelectBucket(int i) {
    if (i == _selected) {
      return;
    }
    setState(() {
      _selected = i;
    });
  }

  bool get _canGoPrevious => _period != AnalysisPeriod.custom;
  bool get _canGoNext => _period != AnalysisPeriod.custom && _offset > 0;

  void _onPrevious() {
    if (_period == AnalysisPeriod.custom) {
      return;
    }
    setState(() {
      _offset += _buckets.length;
      _buckets = generateBuckets(_period, custom: _custom, offset: _offset);
      _selected = (_selected).clamp(0, _buckets.length - 1);
      _reload();
    });
  }

  void _onNext() {
    if (_period == AnalysisPeriod.custom || _offset <= 0) {
      return;
    }
    setState(() {
      _offset = (_offset - _buckets.length).clamp(0, double.infinity).toInt();
      _buckets = generateBuckets(_period, custom: _custom, offset: _offset);
      _selected = (_selected).clamp(0, _buckets.length - 1);
      _reload();
    });
  }

  Future<void> _pickPeriod() async {
    final AnalysisPeriod? p = await showModalBottomSheet<AnalysisPeriod>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AnalysisPeriod.values
              .map(
                (AnalysisPeriod p) => ListTile(
                  leading: Icon(
                    p == _period
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: p == _period
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(p.label),
                  onTap: () => Navigator.pop(context, p),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (p == null || !mounted) {
      return;
    }
    if (p == AnalysisPeriod.custom) {
      final DateTimeRange? r = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        initialDateRange: _custom,
      );
      if (r == null) {
        return;
      }
      _custom = r;
    }
    setState(() {
      _period = p;
      _offset = 0;
      _buckets = generateBuckets(_period, custom: _custom, offset: _offset);
      _selected = _buckets.length - 1;
      _cachedBars = null;
      _future = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    context.watch<SettingsProvider>();
    return FutureBuilder<_AnalysisData>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<_AnalysisData> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudo cargar el análisis.\n${snapshot.error ?? ''}',
              ),
            ),
          );
        }
        final _AnalysisData data = snapshot.data!;
        return RefreshIndicator.adaptive(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: <Widget>[
              _PeriodHeader(
                rangeLabel: _buckets[_selected].rangeLabel,
                periodLabel: _period.label,
                onTapPeriod: _pickPeriod,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 12, 12),
                  child: MonthlyBars(
                    data: data.bars,
                    selectedIndex: _selected,
                    onSelect: _onSelectBucket,
                    onPrevious: _canGoPrevious ? _onPrevious : null,
                    onNext: _canGoNext ? _onNext : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  key: ValueKey<String>('${data.hashCode}_$_selected'),
                  children: <Widget>[
                    _SummaryCard(
                      income: data.bars[_selected].income,
                      expense: data.bars[_selected].expense,
                      budget:
                          _period == AnalysisPeriod.month &&
                              _selected < data.budgetByBucket.length
                          ? data.budgetByBucket[_selected]
                          : null,
                    ),
                    const SizedBox(height: 12),
                    AnalysisQuickFilters(
                      selected: _categoryType,
                      onSelected: (AnalysisCategoryType type) {
                        if (type != _categoryType) {
                          setState(() => _categoryType = type);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _DonutCard(
                      categories: _categoryType == AnalysisCategoryType.expense
                          ? data.expenseCategoriesByBucket[_selected]
                          : data.incomeCategoriesByBucket[_selected],
                      isIncome: _categoryType == AnalysisCategoryType.income,
                    ),
                    const SizedBox(height: 12),
                    _CategoryList(
                      categories: _categoryType == AnalysisCategoryType.expense
                          ? data.expenseCategoriesByBucket[_selected]
                          : data.incomeCategoriesByBucket[_selected],
                      bucket: _buckets[_selected],
                      period: _period,
                      custom: _custom,
                      selectedIndex: _selected,
                      offset: _offset,
                      isIncome: _categoryType == AnalysisCategoryType.income,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Cabecera con el rango de fechas y el selector de periodo.
class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({
    required this.rangeLabel,
    required this.periodLabel,
    required this.onTapPeriod,
  });
  final String rangeLabel;
  final String periodLabel;
  final VoidCallback onTapPeriod;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Text(
              rangeLabel,
              style: Theme.of(
                context,
              ).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            onPressed: onTapPeriod,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(periodLabel),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.income,
    required this.expense,
    this.budget,
  });
  final double income;
  final double expense;
  final double? budget;

  @override
  Widget build(BuildContext context) {
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    final bool hasBudget = budget != null && budget! > 0;
    final double net = income - expense;
    final double incomeRatio = income > 0
        ? (expense / income).clamp(0.0, 1.0)
        : 0.0;
    final double rawIncomeRatio = income > 0 ? (expense / income) : 0.0;

    if (hasBudget) {
      final double budgetVal = budget!;
      final double remaining = budgetVal - expense;
      final double budgetRatio = (expense / budgetVal).clamp(0.0, 1.0);
      final double rawBudgetRatio = expense / budgetVal;

      Color budgetBarColor;
      if (rawBudgetRatio <= 0.75) {
        budgetBarColor = Colors.green;
      } else if (rawBudgetRatio <= 1.0) {
        budgetBarColor = Colors.orange;
      } else {
        budgetBarColor = FtColors.coralOf(context);
      }

      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            children: <Widget>[
              _summaryRow(
                context,
                'Presupuesto',
                budgetVal,
                Theme.of(context).colorScheme.primary,
              ),
              const Divider(height: 20),
              _summaryRow(
                context,
                'Gastos',
                -expense,
                Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(height: 10),
              FtProgressBar(
                progress: budgetRatio,
                color: budgetBarColor,
                height: 8,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        rawBudgetRatio > 1.0
                            ? '${(rawBudgetRatio * 100).round()}% de tu presupuesto gastado (excedido)'
                            : '${(rawBudgetRatio * 100).round()}% de tu presupuesto gastado',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: rawBudgetRatio > 1.0
                              ? FtColors.coralOf(context)
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        income > 0
                            ? '${(rawIncomeRatio * 100).round()}% de tus ingresos gastado'
                            : 'Sin ingresos en este periodo',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              _summaryRow(
                context,
                remaining >= 0 ? 'Restante' : 'Excedido',
                remaining,
                remaining >= 0
                    ? FtColors.incomeOf(context)
                    : FtColors.coralOf(context),
                bold: true,
              ),
              if (income > 0) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Ingresos: ${currency.fmt(income, decimalDigits: 0, context: context)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Ahorro neto: ${currency.fmt(net, decimalDigits: 0, context: context)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: net >= 0
                            ? FtColors.incomeOf(context)
                            : FtColors.coralOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          children: <Widget>[
            _summaryRow(
              context,
              'Ingresos',
              income,
              FtColors.incomeOf(context),
            ),
            const Divider(height: 20),
            _summaryRow(
              context,
              'Gastos',
              -expense,
              Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 10),
            FtProgressBar(
              progress: incomeRatio,
              color: incomeRatio < 0.9
                  ? FtColors.incomeOf(context)
                  : FtColors.coralOf(context),
              height: 8,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  income > 0
                      ? '${(rawIncomeRatio * 100).round()}% de tus ingresos gastado'
                      : 'Sin ingresos en este periodo',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const Divider(height: 20),
            _summaryRow(
              context,
              'Neto',
              net,
              net >= 0 ? FtColors.incomeOf(context) : FtColors.coralOf(context),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    double amount,
    Color color, {
    bool bold = false,
  }) {
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    final TextStyle base = bold
        ? Theme.of(context).textTheme.titleMedium!
        : Theme.of(context).textTheme.bodyLarge!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: base.copyWith(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          currency.fmt(amount, context: context),
          style: base.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Filtros rápidos horizontales para alternar entre categorías de Gastos e Ingresos.
class AnalysisQuickFilters extends StatelessWidget {
  const AnalysisQuickFilters({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final AnalysisCategoryType selected;
  final ValueChanged<AnalysisCategoryType> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    Widget buildChip({
      required String label,
      required AnalysisCategoryType type,
      required IconData icon,
      required Color activeColor,
    }) {
      final bool isSelected = selected == type;
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selected: isSelected,
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        onSelected: (bool sel) {
          if (sel) {
            onSelected(type);
          }
        },
        selectedColor: activeColor,
        backgroundColor: isDark
            ? FtColors.sectionHeaderDark
            : FtColors.sectionHeader,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          buildChip(
            label: 'Gastos',
            type: AnalysisCategoryType.expense,
            icon: Icons.arrow_downward_rounded,
            activeColor: FtColors.coralOf(context),
          ),
          const SizedBox(width: 16),
          buildChip(
            label: 'Ingresos',
            type: AnalysisCategoryType.income,
            icon: Icons.arrow_upward_rounded,
            activeColor: FtColors.incomeOf(context),
          ),
        ],
      ),
    );
  }
}

class _DonutCard extends StatelessWidget {
  const _DonutCard({required this.categories, this.isIncome = false});
  final List<_CategorySpend> categories;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }
    final List<_CategorySpend> top = categories.take(6).toList();
    final double othersAmount = categories
        .skip(6)
        .fold(0.0, (double a, _CategorySpend c) => a + c.amount);
    final List<_CategorySpend> chartData = <_CategorySpend>[
      ...top,
      if (othersAmount > 0) _CategorySpend('Otros', othersAmount),
    ];
    final double total = categories.fold(
      0.0,
      (double a, _CategorySpend c) => a + c.amount,
    );
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              isIncome ? 'Categorías de ingreso' : 'Categorías de gasto',
              style: Theme.of(
                context,
              ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(
              height: 220,
              child: SfCircularChart(
                margin: EdgeInsets.zero,
                annotations: <CircularChartAnnotation>[
                  CircularChartAnnotation(
                    widget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Total',
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        Text(
                          currency.fmt(
                            total,
                            decimalDigits: 0,
                            context: context,
                          ),
                          style: Theme.of(context).textTheme.titleMedium!
                              .copyWith(
                                fontWeight: FontWeight.w700,
                                color: isIncome
                                    ? FtColors.incomeOf(context)
                                    : null,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
                series: <DoughnutSeries<_CategorySpend, String>>[
                  DoughnutSeries<_CategorySpend, String>(
                    dataSource: chartData,
                    xValueMapper: (_CategorySpend c, _) => c.name,
                    yValueMapper: (_CategorySpend c, _) => c.amount,
                    pointColorMapper: (_CategorySpend c, _) => c.name == 'Otros'
                        ? Theme.of(context).colorScheme.surfaceContainerHigh
                        : FtColors.categoryColor(c.name, context: context),
                    innerRadius: '68%',
                    radius: '90%',
                    strokeWidth: 2,
                    strokeColor: Theme.of(context).colorScheme.surface,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.bucket,
    required this.period,
    this.custom,
    required this.selectedIndex,
    this.offset = 0,
    this.isIncome = false,
  });
  final List<_CategorySpend> categories;
  final PeriodBucket bucket;
  final AnalysisPeriod period;
  final DateTimeRange? custom;
  final int selectedIndex;
  final int offset;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Center(
            child: Text(
              isIncome
                  ? 'No hay ingresos categorizados en este periodo'
                  : 'No hay gastos categorizados en este periodo',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    final double maxAmount = categories.first.amount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: <Widget>[
            for (int i = 0; i < categories.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
              _CategoryRow(
                category: categories[i],
                currency: currency,
                fraction: maxAmount > 0 ? categories[i].amount / maxAmount : 0,
                isIncome: isIncome,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => CategoryDetailPage(
                      categoryName: categories[i].name,
                      period: period,
                      custom: custom,
                      initialSelected: selectedIndex,
                      initialOffset: offset,
                      isIncome: isIncome,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.currency,
    required this.fraction,
    required this.onTap,
    this.isIncome = false,
  });
  final _CategorySpend category;
  final CurrencyRead currency;
  final double fraction;
  final VoidCallback onTap;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final Color tint = FtColors.categoryColor(category.name, context: context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            FtCategoryIconWidget(
              icon: FtCategoryIcon.forName(category.name),
              color: tint,
              size: 20,
              padding: 10,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FtProgressBar(
                    progress: fraction,
                    color: isIncome ? FtColors.incomeOf(context) : tint,
                    height: 5,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              currency.fmt(
                isIncome ? category.amount : -category.amount,
                context: context,
              ),
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                fontWeight: FontWeight.w700,
                color: isIncome ? FtColors.incomeOf(context) : null,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.secondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

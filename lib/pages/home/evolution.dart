import 'dart:async';
import 'dart:collection';

import 'package:chopper/chopper.dart' show Response;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/home/analysis_period.dart';
import 'package:waterflyiii/settings.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';
import 'package:waterflyiii/widgets/ft_progress_bar.dart';

final Logger log = Logger('Pages.Home.Evolution');

enum EvolutionViewMode { netWorth, balance, cashFlow, categories }

extension EvolutionViewModeExt on EvolutionViewMode {
  String get label => switch (this) {
    EvolutionViewMode.netWorth => 'Patrimonio',
    EvolutionViewMode.balance => 'Saldo',
    EvolutionViewMode.cashFlow => 'Flujo',
    EvolutionViewMode.categories => 'Categorías',
  };

  IconData get icon => switch (this) {
    EvolutionViewMode.netWorth => Icons.account_balance_outlined,
    EvolutionViewMode.balance => Icons.wallet_outlined,
    EvolutionViewMode.cashFlow => Icons.swap_vert_rounded,
    EvolutionViewMode.categories => Icons.pie_chart_outline_rounded,
  };
}

enum EvolutionPeriodPreset {
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  all,
  custom,
}

extension EvolutionPeriodPresetExt on EvolutionPeriodPreset {
  String get label => switch (this) {
    EvolutionPeriodPreset.oneMonth => '1M',
    EvolutionPeriodPreset.threeMonths => '3M',
    EvolutionPeriodPreset.sixMonths => '6M',
    EvolutionPeriodPreset.oneYear => '1A',
    EvolutionPeriodPreset.all => 'Todo',
    EvolutionPeriodPreset.custom => '📅',
  };

  static EvolutionPeriodPreset fromHomePeriod(HomePatrimonyPeriod period) =>
      switch (period) {
        HomePatrimonyPeriod.oneMonth => EvolutionPeriodPreset.oneMonth,
        HomePatrimonyPeriod.threeMonths => EvolutionPeriodPreset.threeMonths,
        HomePatrimonyPeriod.sixMonths => EvolutionPeriodPreset.sixMonths,
        HomePatrimonyPeriod.oneYear => EvolutionPeriodPreset.oneYear,
        HomePatrimonyPeriod.allTime => EvolutionPeriodPreset.all,
      };

  HomePatrimonyPeriod? toHomePeriod() => switch (this) {
    EvolutionPeriodPreset.oneMonth => HomePatrimonyPeriod.oneMonth,
    EvolutionPeriodPreset.threeMonths => HomePatrimonyPeriod.threeMonths,
    EvolutionPeriodPreset.sixMonths => HomePatrimonyPeriod.sixMonths,
    EvolutionPeriodPreset.oneYear => HomePatrimonyPeriod.oneYear,
    EvolutionPeriodPreset.all => HomePatrimonyPeriod.allTime,
    EvolutionPeriodPreset.custom => null,
  };
}

class ChartDataPoint {
  const ChartDataPoint({
    required this.date,
    required this.value,
    this.secondaryValue,
    this.label,
  });

  final DateTime date;
  final double value;
  final double? secondaryValue;
  final String? label;
}

class _CategoryEvolutionItem {
  const _CategoryEvolutionItem({
    required this.name,
    required this.amount,
    required this.percentage,
  });

  final String name;
  final double amount;
  final double percentage;
}

/// Calcula un rango del eje Y centrado en la media de los datos.
///
/// Expande el rango un 30% por encima de la máxima desviación respecto a la
/// media, de modo que la línea del gráfico quede aproximadamente a mitad de
/// la pantalla incluso cuando los valores fluctúen muy por encima de cero.
({double min, double max})? computeAdaptiveYAxisRange(
  List<ChartDataPoint> points,
) {
  if (points.isEmpty) return null;
  final List<double> values = points
      .map((ChartDataPoint p) => p.value)
      .toList();
  final double mean =
      values.reduce((double a, double b) => a + b) / values.length;
  double maxDiff = 0.0;
  for (final double v in values) {
    final double diff = (v - mean).abs();
    if (diff > maxDiff) {
      maxDiff = diff;
    }
  }
  final double span = maxDiff > 0
      ? maxDiff * 1.3
      : (mean.abs() * 0.1 > 0 ? mean.abs() * 0.1 : 100.0);
  return (min: mean - span, max: mean + span);
}

class _EvolutionData {
  const _EvolutionData({
    required this.points,
    required this.currentTotal,
    required this.startTotal,
    required this.difference,
    required this.percentChange,
    this.minVal = 0,
    this.maxVal = 0,
    this.categories = const <_CategoryEvolutionItem>[],
    this.accountBreakdown = const <String, double>{},
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.savingsRate = 0,
    this.liabilitiesTotal = 0,
    this.assetsTotal = 0,
  });

  final List<ChartDataPoint> points;
  final double currentTotal;
  final double startTotal;
  final double difference;
  final double percentChange;
  final double minVal;
  final double maxVal;
  final List<_CategoryEvolutionItem> categories;
  final Map<String, double> accountBreakdown;
  final double totalIncome;
  final double totalExpense;
  final double savingsRate;
  final double liabilitiesTotal;
  final double assetsTotal;
}

/// Pantalla completa de Evolución y Análisis gráfico
class HomeEvolution extends StatefulWidget {
  const HomeEvolution({super.key});

  @override
  State<HomeEvolution> createState() => _HomeEvolutionState();
}

class _HomeEvolutionState extends State<HomeEvolution>
    with AutomaticKeepAliveClientMixin {
  EvolutionViewMode _mode = EvolutionViewMode.netWorth;
  late EvolutionPeriodPreset _preset;
  DateTimeRange? _customRange;
  HomePatrimonyPeriod? _currentHomePeriod;
  bool _initialized = false;

  // Filtro opcional de cuentas o categorías
  final Set<String> _selectedAccountIds = <String>{};
  final Set<String> _selectedCategoryNames = <String>{};
  List<AccountRead> _availableAccounts = <AccountRead>[];
  List<CategoryRead> _availableCategories = <CategoryRead>[];
  Map<String, AccountRead>? _accountsCache;

  // Interacción en gráfico de categorías
  int? _selectedCategoryIndex;

  late Future<_EvolutionData> _future;
  _EvolutionData? _cachedData;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final HomePatrimonyPeriod defaultPeriod = context
        .watch<SettingsProvider>()
        .homePatrimonyPeriod;
    if (!_initialized) {
      _initialized = true;
      _currentHomePeriod = defaultPeriod;
      _preset = EvolutionPeriodPresetExt.fromHomePeriod(defaultPeriod);
      _future = _fetchEvolution();
    } else if (_currentHomePeriod != defaultPeriod) {
      _currentHomePeriod = defaultPeriod;
      _preset = EvolutionPeriodPresetExt.fromHomePeriod(defaultPeriod);
      _cachedData = null;
      _selectedCategoryIndex = null;
      _future = _fetchEvolution();
    }
  }

  Future<void> _ensureFilterOptions() async {
    final FireflyIii api = context.read<FireflyService>().api;
    if (_availableAccounts.isEmpty) {
      await _fetchAccountsMap(api);
    }
    if (_availableCategories.isEmpty) {
      try {
        final Response<CategoryArray> respCat = await api.v1CategoriesGet(
          limit: 100,
        );
        if (respCat.isSuccessful && respCat.body != null) {
          _availableCategories = respCat.body!.data;
        }
      } catch (e) {
        log.warning('Error loading category filter options: $e');
      }
    }
  }

  ({DateTime start, DateTime end}) _computeDateRange() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    switch (_preset) {
      case EvolutionPeriodPreset.oneMonth:
        return (
          start: DateTime(today.year, today.month - 1, today.day),
          end: today,
        );
      case EvolutionPeriodPreset.threeMonths:
        return (
          start: DateTime(today.year, today.month - 3, today.day),
          end: today,
        );
      case EvolutionPeriodPreset.sixMonths:
        return (
          start: DateTime(today.year, today.month - 6, today.day),
          end: today,
        );
      case EvolutionPeriodPreset.oneYear:
        return (
          start: DateTime(today.year - 1, today.month, today.day),
          end: today,
        );
      case EvolutionPeriodPreset.all:
        return (
          start: DateTime(today.year - 3, today.month, today.day),
          end: today,
        );
      case EvolutionPeriodPreset.custom:
        if (_customRange != null) {
          return (start: _customRange!.start, end: _customRange!.end);
        }
        return (
          start: DateTime(today.year, today.month - 6, today.day),
          end: today,
        );
    }
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _refresh({bool forceReloadAccounts = false}) async {
    setState(() {
      if (forceReloadAccounts) {
        _accountsCache = null;
        _availableAccounts.clear();
        _availableCategories.clear();
      }
      _selectedCategoryIndex = null;
      _cachedData = null;
      _future = _fetchEvolution();
    });
  }

  Future<_EvolutionData> _fetchEvolution() {
    final FireflyIii api = context.read<FireflyService>().api;
    final ({DateTime start, DateTime end}) range = _computeDateRange();
    final String startStr = _fmt(range.start);
    final String endStr = _fmt(range.end);

    switch (_mode) {
      case EvolutionViewMode.netWorth:
        return _fetchNetWorth(api, startStr, endStr);
      case EvolutionViewMode.balance:
        return _fetchBalance(api, startStr, endStr);
      case EvolutionViewMode.cashFlow:
        return _fetchCashFlow(api, range.start, range.end);
      case EvolutionViewMode.categories:
        return _fetchCategoriesEvolution(api, startStr, endStr);
    }
  }

  bool _datasetHasVariation(Map<String, dynamic> entries) {
    if (entries.length < 2) return false;
    double? first;
    for (final dynamic val in entries.values) {
      final double v = double.tryParse(val.toString()) ?? 0;
      first ??= v;
      if ((v - first).abs() > 0.0001) {
        return true;
      }
    }
    return false;
  }

  bool _shouldIncludeInBreakdown(
    String accountName,
    Map<String, AccountRead> accountsMap,
    Map<String, dynamic> entries,
  ) {
    if (accountsMap.isEmpty) {
      return true;
    }
    final AccountRead? acc = accountsMap[accountName];
    if (acc == null) {
      return _datasetHasVariation(entries);
    }
    final bool isActive = acc.attributes.active ?? true;
    if (isActive) {
      return true;
    }
    return _datasetHasVariation(entries);
  }

  Future<Map<String, AccountRead>> _fetchAccountsMap(FireflyIii api) async {
    if (_accountsCache != null) {
      return _accountsCache!;
    }
    final Map<String, AccountRead> map = <String, AccountRead>{};
    try {
      final (
        Response<AccountArray> respAsset,
        Response<AccountArray> respLiab,
      ) = await (
        api.v1AccountsGet(type: AccountTypeFilter.assetAccount, limit: 100),
        api.v1AccountsGet(type: AccountTypeFilter.liabilities, limit: 100),
      ).wait;

      for (final Response<AccountArray> resp in <Response<AccountArray>>[
        respAsset,
        respLiab,
      ]) {
        if (resp.isSuccessful && resp.body != null) {
          for (final AccountRead acc in resp.body!.data) {
            map[acc.attributes.name] = acc;
          }
        }
      }
      _accountsCache = map;
      _availableAccounts = map.values
          .where(
            (AccountRead a) =>
                (a.attributes.active ?? true) &&
                (a.attributes.type == ShortAccountTypeProperty.asset ||
                    a.attributes.type == ShortAccountTypeProperty.liability ||
                    a.attributes.type == ShortAccountTypeProperty.liabilities),
          )
          .toList();
    } catch (e) {
      log.warning('Error fetching accounts map for evolution breakdown: $e');
    }
    return map;
  }

  Future<_EvolutionData> _fetchNetWorth(
    FireflyIii api,
    String startStr,
    String endStr,
  ) async {
    final (
      Response<ChartLine> resp,
      Map<String, AccountRead> accountsMap,
    ) = await (
      api.v1ChartAccountOverviewGet(
        start: startStr,
        end: endStr,
        period: _preset == EvolutionPeriodPreset.oneMonth
            ? .value_1d
            : .value_1w,
        preselected: .all,
      ),
      _fetchAccountsMap(api),
    ).wait;
    apiThrowErrorIfEmpty(resp, mounted ? context : null);

    final Set<String> liabilityNames = <String>{};
    for (final AccountRead acc in accountsMap.values) {
      final String t = acc.attributes.type.value?.toLowerCase() ?? '';
      if (t.contains('liab') || t == 'loan' || t == 'debt' || t == 'mortgage') {
        liabilityNames.add(acc.attributes.name);
      }
    }
    if (liabilityNames.isEmpty) {
      try {
        final Response<AccountArray> respLiab = await api.v1AccountsGet(
          type: .liabilities,
        );
        if (respLiab.isSuccessful && respLiab.body != null) {
          for (final AccountRead acc in respLiab.body!.data) {
            liabilityNames.add(acc.attributes.name);
          }
        }
      } catch (_) {}
    }

    final List<ChartDataSet> datasets = resp.body ?? <ChartDataSet>[];
    final Map<DateTime, double> assetsByDate = <DateTime, double>{};
    final Map<DateTime, double> liabilitiesByDate = <DateTime, double>{};
    final Map<String, double> latestBreakdown = <String, double>{};

    double latestAssets = 0;
    double latestLiabilities = 0;

    for (final ChartDataSet ds in datasets) {
      final String label = ds.label ?? '';

      final bool isLiability =
          ds.type == 'liability' || liabilityNames.contains(label);
      final Map<String, dynamic> entries = (ds.entries is Map<String, dynamic>)
          ? (ds.entries as Map<String, dynamic>)
          : <String, dynamic>{};

      double lastVal = 0;
      entries.forEach((String dStr, dynamic val) {
        final DateTime? date = DateTime.tryParse(dStr);
        if (date == null) return;
        final double rawV = double.tryParse(val.toString()) ?? 0;
        final double v = isLiability ? rawV.abs() : rawV;
        lastVal = v;

        if (isLiability) {
          liabilitiesByDate[date] = (liabilitiesByDate[date] ?? 0) + v;
        } else {
          assetsByDate[date] = (assetsByDate[date] ?? 0) + v;
        }
      });
      if (_shouldIncludeInBreakdown(label, accountsMap, entries)) {
        latestBreakdown[label] = isLiability ? -lastVal : lastVal;
      }
      if (isLiability) {
        latestLiabilities += lastVal;
      } else {
        latestAssets += lastVal;
      }
    }

    final SplayTreeSet<DateTime> allDates = SplayTreeSet<DateTime>()
      ..addAll(assetsByDate.keys)
      ..addAll(liabilitiesByDate.keys);

    final List<ChartDataPoint> points = <ChartDataPoint>[];
    double minV = double.infinity;
    double maxV = -double.infinity;

    for (final DateTime d in allDates) {
      final double a = assetsByDate[d] ?? 0;
      final double l = liabilitiesByDate[d] ?? 0;
      final double net = a - l;
      if (net < minV) minV = net;
      if (net > maxV) maxV = net;
      points.add(ChartDataPoint(date: d, value: net, secondaryValue: a));
    }

    if (points.isEmpty) {
      return const _EvolutionData(
        points: <ChartDataPoint>[],
        currentTotal: 0,
        startTotal: 0,
        difference: 0,
        percentChange: 0,
      );
    }

    final double startVal = points.first.value;
    final double currentVal = points.last.value;
    final double diff = currentVal - startVal;
    final double pct = startVal.abs() > 0 ? (diff / startVal.abs()) * 100 : 0.0;

    return _EvolutionData(
      points: points,
      currentTotal: currentVal,
      startTotal: startVal,
      difference: diff,
      percentChange: pct,
      minVal: minV == double.infinity ? 0 : minV,
      maxVal: maxV == -double.infinity ? 0 : maxV,
      accountBreakdown: latestBreakdown,
      assetsTotal: latestAssets,
      liabilitiesTotal: latestLiabilities,
    );
  }

  Future<_EvolutionData> _fetchBalance(
    FireflyIii api,
    String startStr,
    String endStr,
  ) async {
    final Set<String> selectedNames = _selectedAccountIds.isNotEmpty
        ? _availableAccounts
              .where((AccountRead a) => _selectedAccountIds.contains(a.id))
              .map((AccountRead a) => a.attributes.name)
              .toSet()
        : const <String>{};

    final (
      Response<ChartLine> resp,
      Map<String, AccountRead> accountsMap,
    ) = await (
      api.v1ChartAccountOverviewGet(
        start: startStr,
        end: endStr,
        period: _preset == EvolutionPeriodPreset.oneMonth
            ? .value_1d
            : .value_1w,
        preselected: .assets,
      ),
      _fetchAccountsMap(api),
    ).wait;
    apiThrowErrorIfEmpty(resp, mounted ? context : null);

    final List<ChartDataSet> datasets = resp.body ?? <ChartDataSet>[];
    final Map<DateTime, double> totalByDate = <DateTime, double>{};
    final Map<String, double> breakdown = <String, double>{};

    for (final ChartDataSet ds in datasets) {
      // Firefly III API devuelve type: "line" para todas las series en este endpoint,
      // o type: null / "asset". No filtrar por ds.type == 'asset'.
      final String label = ds.label ?? '';
      final AccountRead? acc = accountsMap[label];

      if (selectedNames.isNotEmpty && !selectedNames.contains(label)) {
        continue;
      }
      // Cuando no se seleccionan cuentas individualmente, el Saldo Agregado
      // solo incluye cuentas activas marcadas con includeNetWorth == true.
      if (selectedNames.isEmpty && !(acc?.attributes.includeNetWorth ?? true)) {
        continue;
      }
      final Map<String, dynamic> entries = (ds.entries is Map<String, dynamic>)
          ? (ds.entries as Map<String, dynamic>)
          : <String, dynamic>{};
      double lastVal = 0;
      entries.forEach((String dStr, dynamic val) {
        final DateTime? date = DateTime.tryParse(dStr);
        if (date == null) return;
        final double v = double.tryParse(val.toString()) ?? 0;
        totalByDate[date] = (totalByDate[date] ?? 0) + v;
        lastVal = v;
      });
      if (_shouldIncludeInBreakdown(label, accountsMap, entries)) {
        breakdown[label] = lastVal;
      }
    }

    final List<DateTime> sortedDates = totalByDate.keys.toList()..sort();
    final List<ChartDataPoint> points = <ChartDataPoint>[];
    double minV = double.infinity;
    double maxV = -double.infinity;

    for (final DateTime d in sortedDates) {
      final double v = totalByDate[d] ?? 0;
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
      points.add(ChartDataPoint(date: d, value: v));
    }

    if (points.isEmpty) {
      return const _EvolutionData(
        points: <ChartDataPoint>[],
        currentTotal: 0,
        startTotal: 0,
        difference: 0,
        percentChange: 0,
      );
    }

    final double startVal = points.first.value;
    final double currentVal = points.last.value;
    final double diff = currentVal - startVal;
    final double pct = startVal.abs() > 0 ? (diff / startVal.abs()) * 100 : 0.0;

    return _EvolutionData(
      points: points,
      currentTotal: currentVal,
      startTotal: startVal,
      difference: diff,
      percentChange: pct,
      minVal: minV == double.infinity ? 0 : minV,
      maxVal: maxV == -double.infinity ? 0 : maxV,
      accountBreakdown: breakdown,
    );
  }

  Future<_EvolutionData> _fetchCashFlow(
    FireflyIii api,
    DateTime start,
    DateTime end,
  ) async {
    // Para flujo mensual o por buckets
    final int monthsCount =
        ((end.year - start.year) * 12 + end.month - start.month).clamp(1, 24);
    final List<PeriodBucket> buckets = generateBuckets(
      AnalysisPeriod.month,
      count: monthsCount + 1,
    );

    final List<({PeriodBucket bucket, double income, double expense})>
    results = await Future.wait(
      buckets.map((PeriodBucket b) async {
        final (
          Response<InsightTotal> respInc,
          Response<InsightTotal> respExp,
        ) = await (
          api.v1InsightIncomeTotalGet(start: _fmt(b.start), end: _fmt(b.end)),
          api.v1InsightExpenseTotalGet(start: _fmt(b.start), end: _fmt(b.end)),
        ).wait;

        double inc = 0;
        for (final InsightTotalEntry e
            in respInc.body ?? <InsightTotalEntry>[]) {
          inc += (e.differenceFloat ?? 0).abs();
        }
        double exp = 0;
        for (final InsightTotalEntry e
            in respExp.body ?? <InsightTotalEntry>[]) {
          exp += (e.differenceFloat ?? 0).abs();
        }
        return (bucket: b, income: inc, expense: exp);
      }),
    );

    double totalIncome = 0;
    double totalExpense = 0;
    final List<ChartDataPoint> points = <ChartDataPoint>[];

    for (final ({PeriodBucket bucket, double income, double expense}) item
        in results) {
      totalIncome += item.income;
      totalExpense += item.expense;

      points.add(
        ChartDataPoint(
          date: item.bucket.start,
          value: item.income,
          secondaryValue: item.expense,
          label: item.bucket.shortLabel,
        ),
      );
    }

    final double netTotal = totalIncome - totalExpense;
    final double savingsRate = totalIncome > 0
        ? (netTotal / totalIncome) * 100
        : 0;

    return _EvolutionData(
      points: points,
      currentTotal: netTotal,
      startTotal: 0,
      difference: netTotal,
      percentChange: savingsRate,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      savingsRate: savingsRate,
    );
  }

  Future<_EvolutionData> _fetchCategoriesEvolution(
    FireflyIii api,
    String startStr,
    String endStr,
  ) async {
    final Response<InsightGroup> resp = await api.v1InsightExpenseCategoryGet(
      start: startStr,
      end: endStr,
    );
    apiThrowErrorIfEmpty(resp, mounted ? context : null);

    final List<InsightGroupEntry> rawCats = resp.body ?? <InsightGroupEntry>[];
    double totalSpend = 0;
    final Map<String, double> catMap = <String, double>{};

    for (final InsightGroupEntry e in rawCats) {
      final String name = e.name?.isNotEmpty ?? false
          ? e.name!
          : 'Sin categoría';
      if (_selectedCategoryNames.isNotEmpty &&
          !_selectedCategoryNames.contains(name)) {
        continue;
      }
      final double amt = (e.differenceFloat ?? 0).abs();
      catMap[name] = (catMap[name] ?? 0) + amt;
      totalSpend += amt;
    }

    final List<_CategoryEvolutionItem> sortedCats = catMap.entries
        .map(
          (MapEntry<String, double> e) => _CategoryEvolutionItem(
            name: e.key,
            amount: e.value,
            percentage: totalSpend > 0 ? (e.value / totalSpend) * 100 : 0,
          ),
        )
        .sortedBy<num>((_CategoryEvolutionItem c) => -c.amount);

    return _EvolutionData(
      points: <ChartDataPoint>[],
      currentTotal: totalSpend,
      startTotal: 0,
      difference: 0,
      percentChange: 0,
      categories: sortedCats,
    );
  }

  Future<void> _openFiltersSheet() async {
    await _ensureFilterOptions();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Filtros de visualización',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedAccountIds.clear();
                              _selectedCategoryNames.clear();
                            });
                          },
                          child: const Text('Limpiar'),
                        ),
                      ],
                    ),
                    const Divider(),
                    Text(
                      'Cuentas para Saldo / Patrimonio:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _availableAccounts.map((AccountRead a) {
                        final bool isSel = _selectedAccountIds.contains(a.id);
                        return FilterChip(
                          label: Text(a.attributes.name),
                          selected: isSel,
                          onSelected: (bool sel) {
                            setModalState(() {
                              if (sel) {
                                _selectedAccountIds.add(a.id);
                              } else {
                                _selectedAccountIds.remove(a.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Categorías para desglose:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _availableCategories.map((CategoryRead c) {
                            final String name = c.attributes.name;
                            final bool isSel = _selectedCategoryNames.contains(
                              name,
                            );
                            return FilterChip(
                              label: Text(name),
                              selected: isSel,
                              onSelected: (bool sel) {
                                setModalState(() {
                                  if (sel) {
                                    _selectedCategoryNames.add(name);
                                  } else {
                                    _selectedCategoryNames.remove(name);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _refresh();
                        },
                        child: const Text('Aplicar filtros'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickCustomRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      initialDateRange:
          _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 90)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _preset = EvolutionPeriodPreset.custom;
        _refresh();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    final SettingsProvider settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator.adaptive(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: <Widget>[
            // Fila de Filtro de Periodos (Estilo Fintonic)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: EvolutionPeriodPreset.values.map((
                        EvolutionPeriodPreset p,
                      ) {
                        final bool isSel = _preset == p;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(p.label),
                            selected: isSel,
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            onSelected: (bool sel) {
                              if (!sel) return;
                              if (p == EvolutionPeriodPreset.custom) {
                                _pickCustomRange();
                              } else {
                                setState(() {
                                  _preset = p;
                                  _refresh();
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Badge(
                    isLabelVisible:
                        _selectedAccountIds.isNotEmpty ||
                        _selectedCategoryNames.isNotEmpty,
                    child: const Icon(Icons.filter_list_rounded),
                  ),
                  tooltip: 'Filtros avanzados',
                  onPressed: _openFiltersSheet,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Selector de Modo (Patrimonio, Saldo, Flujo, Categorías)
            SegmentedButton<EvolutionViewMode>(
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
                  EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
              segments: EvolutionViewMode.values
                  .map(
                    (EvolutionViewMode m) => ButtonSegment<EvolutionViewMode>(
                      value: m,
                      label: Text(
                        m.label,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                        style: const TextStyle(fontSize: 11),
                      ),
                      tooltip: m.label,
                    ),
                  )
                  .toList(),
              selected: <EvolutionViewMode>{_mode},
              showSelectedIcon: false,
              onSelectionChanged: (Set<EvolutionViewMode> newSelection) {
                setState(() {
                  _mode = newSelection.first;
                  _refresh();
                });
              },
            ),
            const SizedBox(height: 16),

            // Bloque de datos y gráfico
            FutureBuilder<_EvolutionData>(
              future: _future,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<_EvolutionData> snapshot,
                  ) {
                    if (snapshot.connectionState != ConnectionState.done &&
                        _cachedData == null) {
                      return const SizedBox(
                        height: 350,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Error al cargar métricas de evolución:\n${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasData) {
                      _cachedData = snapshot.data;
                    }

                    final _EvolutionData data = _cachedData!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Tarjeta KPI principal
                        _buildKpiCard(context, data, currency, settings),
                        const SizedBox(height: 16),

                        // Gráfico Principal SfCartesianChart
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 16, 12, 12),
                            child: _buildChart(
                              context,
                              data,
                              currency,
                              settings,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Desglose contextual inferior
                        _buildBottomBreakdown(
                          context,
                          data,
                          currency,
                          settings,
                        ),
                      ],
                    );
                  },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context,
    _EvolutionData data,
    CurrencyRead currency,
    SettingsProvider settings,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String mainTitle = switch (_mode) {
      EvolutionViewMode.netWorth => 'Patrimonio Neto',
      EvolutionViewMode.balance => 'Saldo Agregado',
      EvolutionViewMode.cashFlow => 'Ahorro Neto Acumulado',
      EvolutionViewMode.categories => 'Gasto Total en Periodo',
    };

    final double diff = data.difference;
    final bool isPositive = diff >= 0;
    final Color diffColor = isPositive
        ? FtColors.incomeFor(isDark: isDark)
        : FtColors.coralFor(isDark: isDark);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              mainTitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  settings.hideAmounts
                      ? '••••'
                      : currency.fmt(data.currentTotal, context: context),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                const Spacer(),
                if (_mode != EvolutionViewMode.categories) ...<Widget>[
                  Icon(
                    isPositive
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: diffColor,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${isPositive ? '+' : ''}${currency.fmt(diff, decimalDigits: 0, context: context)} (${data.percentChange.toStringAsFixed(1)}%)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: diffColor,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (_mode == EvolutionViewMode.netWorth) ...<Widget>[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Activos totales',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        settings.hideAmounts
                            ? '••••'
                            : currency.fmt(data.assetsTotal, context: context),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: FtColors.incomeFor(isDark: isDark),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        'Deuda / Pasivos',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        settings.hideAmounts
                            ? '••••'
                            : currency.fmt(
                                data.liabilitiesTotal.abs(),
                                context: context,
                              ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: FtColors.coralFor(isDark: isDark),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            if (_mode == EvolutionViewMode.cashFlow) ...<Widget>[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Tasa de ahorro: ${data.savingsRate.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Ingresos: ${currency.fmt(data.totalIncome, decimalDigits: 0, context: context)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_CategoryEvolutionItem> _computeChartCategories(
    List<_CategoryEvolutionItem> categories,
    double totalSpend,
  ) {
    if (categories.length <= 6) {
      return categories;
    }
    final List<_CategoryEvolutionItem> top5 = categories.take(5).toList();
    final double otherAmount = categories
        .skip(5)
        .fold(0.0, (double sum, _CategoryEvolutionItem c) => sum + c.amount);
    final double otherPct = totalSpend > 0
        ? (otherAmount / totalSpend) * 100
        : 0.0;
    return <_CategoryEvolutionItem>[
      ...top5,
      _CategoryEvolutionItem(
        name: 'Otros',
        amount: otherAmount,
        percentage: otherPct,
      ),
    ];
  }

  Widget _buildChart(
    BuildContext context,
    _EvolutionData data,
    CurrencyRead currency,
    SettingsProvider settings,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryLineColor = switch (_mode) {
      EvolutionViewMode.netWorth => FtColors.blueFor(isDark: isDark),
      EvolutionViewMode.balance => FtColors.incomeFor(isDark: isDark),
      EvolutionViewMode.cashFlow => FtColors.blueFor(isDark: isDark),
      EvolutionViewMode.categories => FtColors.coralFor(isDark: isDark),
    };

    if (_mode == EvolutionViewMode.categories) {
      if (data.categories.isEmpty) {
        return const SizedBox(
          height: 240,
          child: Center(child: Text('Sin datos en este periodo')),
        );
      }
      final List<_CategoryEvolutionItem> chartCategories =
          _computeChartCategories(data.categories, data.currentTotal);

      final _CategoryEvolutionItem? selItem =
          (_selectedCategoryIndex != null &&
              _selectedCategoryIndex! < chartCategories.length)
          ? chartCategories[_selectedCategoryIndex!]
          : null;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 250,
            child: SfCircularChart(
              margin: EdgeInsets.zero,
              legend: const Legend(isVisible: false),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                builder:
                    (
                      dynamic data,
                      dynamic point,
                      dynamic series,
                      int pointIndex,
                      int seriesIndex,
                    ) {
                      if (pointIndex >= chartCategories.length) {
                        return const SizedBox.shrink();
                      }
                      final _CategoryEvolutionItem item =
                          chartCategories[pointIndex];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              settings.hideAmounts
                                  ? '••••'
                                  : '${currency.fmt(item.amount, context: context)} (${item.percentage.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontSize: 11,
                                color: FtColors.coralFor(isDark: isDark),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
              ),
              annotations: <CircularChartAnnotation>[
                CircularChartAnnotation(
                  widget: selItem != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                selItem.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                settings.hideAmounts
                                    ? '••••'
                                    : currency.fmt(
                                        selItem.amount,
                                        context: context,
                                      ),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: FtColors.coralFor(isDark: isDark),
                                    ),
                              ),
                              Text(
                                '${selItem.percentage.toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: isDark
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant
                                          : Theme.of(
                                              context,
                                            ).colorScheme.outline,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Gasto total',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              settings.hideAmounts
                                  ? '••••'
                                  : currency.fmt(
                                      data.currentTotal,
                                      decimalDigits: 0,
                                      context: context,
                                    ),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${chartCategories.length} categorías',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: isDark
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant
                                        : Theme.of(context).colorScheme.outline,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                ),
              ],
              series: <CircularSeries<_CategoryEvolutionItem, String>>[
                DoughnutSeries<_CategoryEvolutionItem, String>(
                  dataSource: chartCategories,
                  xValueMapper: (_CategoryEvolutionItem item, _) => item.name,
                  yValueMapper: (_CategoryEvolutionItem item, _) => item.amount,
                  pointColorMapper: (_CategoryEvolutionItem item, _) =>
                      item.name == 'Otros'
                      ? Theme.of(context).colorScheme.outlineVariant
                      : FtColors.categoryColor(item.name, context: context),
                  innerRadius: '68%',
                  radius: '82%',
                  animationDuration: 0,
                  explode: true,
                  explodeIndex: _selectedCategoryIndex,
                  explodeOffset: '6%',
                  onPointTap: (ChartPointDetails details) {
                    if (details.pointIndex != null) {
                      setState(() {
                        if (_selectedCategoryIndex == details.pointIndex) {
                          _selectedCategoryIndex = null;
                        } else {
                          _selectedCategoryIndex = details.pointIndex;
                        }
                      });
                    }
                  },
                  dataLabelMapper: (_CategoryEvolutionItem item, _) {
                    if (settings.hideAmounts) return '••••';
                    if (item.percentage < 5) return '';
                    return currency.fmt(
                      item.amount,
                      decimalDigits: 0,
                      context: context,
                    );
                  },
                  dataLabelSettings: DataLabelSettings(
                    isVisible: true,
                    labelPosition: ChartDataLabelPosition.outside,
                    connectorLineSettings: ConnectorLineSettings(
                      type: ConnectorType.curve,
                      length: '10%',
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    labelIntersectAction: LabelIntersectAction.shift,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: chartCategories.mapIndexed((
                int idx,
                _CategoryEvolutionItem item,
              ) {
                final bool isSelected = _selectedCategoryIndex == idx;
                final Color catColor = item.name == 'Otros'
                    ? Theme.of(context).colorScheme.outlineVariant
                    : FtColors.categoryColor(item.name, context: context);

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() {
                      if (_selectedCategoryIndex == idx) {
                        _selectedCategoryIndex = null;
                      } else {
                        _selectedCategoryIndex = idx;
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? catColor.withValues(alpha: 0.18)
                          : Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? catColor : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: catColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? catColor
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.outline,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      );
    }

    if (_mode == EvolutionViewMode.cashFlow) {
      return SizedBox(
        height: 280,
        child: SfCartesianChart(
          primaryXAxis: CategoryAxis(
            labelStyle: Theme.of(context).textTheme.labelSmall,
          ),
          primaryYAxis: NumericAxis(
            numberFormat: NumberFormat.compact(),
            labelStyle: Theme.of(context).textTheme.labelSmall,
          ),
          legend: const Legend(isVisible: true, position: LegendPosition.top),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <CartesianSeries<ChartDataPoint, String>>[
            ColumnSeries<ChartDataPoint, String>(
              name: 'Ingresos',
              dataSource: data.points,
              xValueMapper: (ChartDataPoint p, _) => p.label ?? '',
              yValueMapper: (ChartDataPoint p, _) => p.value,
              animationDuration: 0,
              color: FtColors.incomeFor(isDark: isDark),
            ),
            ColumnSeries<ChartDataPoint, String>(
              name: 'Gastos',
              dataSource: data.points,
              xValueMapper: (ChartDataPoint p, _) => p.label ?? '',
              yValueMapper: (ChartDataPoint p, _) => p.secondaryValue ?? 0,
              animationDuration: 0,
              color: FtColors.coralFor(isDark: isDark),
            ),
          ],
        ),
      );
    }

    if (data.points.isEmpty) {
      return const SizedBox(
        height: 240,
        child: Center(child: Text('No hay datos suficientes para el gráfico')),
      );
    }

    final DateFormat dateFmt = _preset == EvolutionPeriodPreset.oneMonth
        ? DateFormat('d MMM')
        : DateFormat('MMM yy');
    final DateFormat tooltipDateFmt = _preset == EvolutionPeriodPreset.oneMonth
        ? DateFormat('d MMM')
        : DateFormat('d MMM yyyy');

    final bool useAdaptiveYAxis =
        _mode == EvolutionViewMode.netWorth ||
        _mode == EvolutionViewMode.balance;
    final ({double min, double max})? yRange = useAdaptiveYAxis
        ? computeAdaptiveYAxisRange(data.points)
        : null;

    return SizedBox(
      height: 280,
      child: SfCartesianChart(
        primaryXAxis: DateTimeAxis(
          dateFormat: dateFmt,
          labelStyle: Theme.of(context).textTheme.labelSmall,
          majorGridLines: const MajorGridLines(width: 0.5),
        ),
        primaryYAxis: NumericAxis(
          minimum: yRange?.min,
          maximum: yRange?.max,
          numberFormat: NumberFormat.compact(),
          labelStyle: Theme.of(context).textTheme.labelSmall,
        ),
        trackballBehavior: TrackballBehavior(
          enable: true,
          activationMode: ActivationMode.singleTap,
          tooltipDisplayMode: TrackballDisplayMode.floatAllPoints,
          lineType: TrackballLineType.vertical,
          builder: (BuildContext context, TrackballDetails trackballDetails) {
            final int? pointIndex = trackballDetails.pointIndex;
            if (pointIndex == null ||
                pointIndex < 0 ||
                pointIndex >= data.points.length) {
              return const SizedBox.shrink();
            }
            final ChartDataPoint point = data.points[pointIndex];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tooltipDateFmt.format(point.date),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    settings.hideAmounts
                        ? '••••'
                        : currency.fmt(point.value, context: context),
                    style: TextStyle(fontSize: 11, color: primaryLineColor),
                  ),
                ],
              ),
            );
          },
        ),
        series: <CartesianSeries<ChartDataPoint, DateTime>>[
          SplineAreaSeries<ChartDataPoint, DateTime>(
            dataSource: data.points,
            xValueMapper: (ChartDataPoint p, _) => p.date,
            yValueMapper: (ChartDataPoint p, _) => p.value,
            splineType: SplineType.monotonic,
            color: primaryLineColor.withValues(alpha: 0.18),
            borderColor: primaryLineColor,
            borderWidth: 2.5,
            animationDuration: 0,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBreakdown(
    BuildContext context,
    _EvolutionData data,
    CurrencyRead currency,
    SettingsProvider settings,
  ) {
    if (_mode == EvolutionViewMode.categories) {
      final List<_CategoryEvolutionItem> chartCategories =
          _computeChartCategories(data.categories, data.currentTotal);
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Ranking de gastos por categoría',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              ...data.categories.map((_CategoryEvolutionItem cat) {
                final int chartIdx = chartCategories.indexWhere(
                  (_CategoryEvolutionItem c) => c.name == cat.name,
                );
                final bool isSelected =
                    _selectedCategoryIndex != null &&
                    _selectedCategoryIndex! < chartCategories.length &&
                    (chartCategories[_selectedCategoryIndex!].name ==
                            cat.name ||
                        (chartCategories[_selectedCategoryIndex!].name ==
                                'Otros' &&
                            chartIdx == -1));
                final Color catColor = FtColors.categoryColor(
                  cat.name,
                  context: context,
                );

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: catColor.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    setState(() {
                      final int targetIdx = chartIdx != -1
                          ? chartIdx
                          : chartCategories.indexWhere(
                              (_CategoryEvolutionItem c) => c.name == 'Otros',
                            );
                      if (targetIdx != -1) {
                        if (_selectedCategoryIndex == targetIdx) {
                          _selectedCategoryIndex = null;
                        } else {
                          _selectedCategoryIndex = targetIdx;
                        }
                      }
                    });
                  },
                  leading: FtCategoryIconWidget(
                    icon: FtCategoryIcon.forName(cat.name),
                    color: catColor,
                  ),
                  title: Text(
                    cat.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                  ),
                  subtitle: FtProgressBar(
                    progress: (cat.percentage / 100).clamp(0.0, 1.0),
                    color: catColor,
                    height: 5,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        settings.hideAmounts
                            ? '••••'
                            : currency.fmt(cat.amount, context: context),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${cat.percentage.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : null,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }

    if (data.accountBreakdown.isNotEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Desglose por cuentas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              ...data.accountBreakdown.entries.map((
                MapEntry<String, double> entry,
              ) {
                final double val = entry.value;
                final bool isNeg = val < 0;
                return ListTile(
                  title: Text(entry.key),
                  trailing: Text(
                    settings.hideAmounts
                        ? '••••'
                        : currency.fmt(val, context: context),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isNeg ? FtColors.coralOf(context) : null,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

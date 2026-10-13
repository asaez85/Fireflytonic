import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/home/analysis_period.dart';
import 'package:waterflyiii/pages/home/transactions.dart';
import 'package:waterflyiii/pages/home/transactions/filter.dart';
import 'package:waterflyiii/settings.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';
import 'package:waterflyiii/widgets/monthly_bars.dart';

class _DetailData {
  const _DetailData({required this.bars});
  final List<MonthBarData> bars;
}

/// Vista detallada de una categoría: gasto o ingreso por periodo + sus movimientos.
class CategoryDetailPage extends StatefulWidget {
  const CategoryDetailPage({
    super.key,
    required this.categoryName,
    required this.period,
    this.custom,
    this.initialSelected,
    this.initialOffset = 0,
    this.isIncome = false,
  });
  final String categoryName;
  final AnalysisPeriod period;
  final DateTimeRange? custom;
  final int? initialSelected;
  final int initialOffset;
  final bool isIncome;

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  late int _offset;
  late List<PeriodBucket> _buckets;
  late int _selected;
  late Future<_DetailData> _future;
  List<MonthBarData>? _cachedBars;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset;
    _buckets = generateBuckets(
      widget.period,
      custom: widget.custom,
      offset: _offset,
    );
    _selected = widget.initialSelected ?? _buckets.length - 1;
    if (_selected >= _buckets.length) {
      _selected = _buckets.length - 1;
    }
    _future = _fetch();
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd', 'en_US').format(d);

  Future<_DetailData> _fetch() async {
    final FireflyIii api = context.read<FireflyService>().api;
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;

    List<MonthBarData> bars;
    if (_cachedBars != null) {
      bars = _cachedBars!;
    } else {
      bars = await Future.wait(
        _buckets.map((PeriodBucket b) async {
          final Response<InsightGroup> resp = widget.isIncome
              ? await api.v1InsightIncomeCategoryGet(
                  start: _fmt(b.start),
                  end: _fmt(b.end),
                )
              : await api.v1InsightExpenseCategoryGet(
                  start: _fmt(b.start),
                  end: _fmt(b.end),
                );
          double amount = 0;
          for (final InsightGroupEntry e
              in resp.body ?? <InsightGroupEntry>[]) {
            if (e.currencyId != null && e.currencyId != currency.id) {
              continue;
            }
            if (e.name == widget.categoryName) {
              amount = (e.differenceFloat ?? 0).abs();
            }
          }
          return MonthBarData(
            label: b.shortLabel,
            income: widget.isIncome ? amount : 0,
            expense: widget.isIncome ? 0 : amount,
          );
        }),
      );
      _cachedBars = bars;
    }

    return _DetailData(bars: bars);
  }

  void _onSelectBucket(int i) {
    if (i == _selected) {
      return;
    }
    setState(() {
      _selected = i;
    });
  }

  bool get _canGoPrevious => widget.period != AnalysisPeriod.custom;
  bool get _canGoNext => widget.period != AnalysisPeriod.custom && _offset > 0;

  void _onPrevious() {
    if (widget.period == AnalysisPeriod.custom) {
      return;
    }
    setState(() {
      _offset += _buckets.length;
      _buckets = generateBuckets(
        widget.period,
        custom: widget.custom,
        offset: _offset,
      );
      _selected = (_selected).clamp(0, _buckets.length - 1);
      _cachedBars = null;
      _future = _fetch();
    });
  }

  void _onNext() {
    if (widget.period == AnalysisPeriod.custom || _offset <= 0) {
      return;
    }
    setState(() {
      _offset = (_offset - _buckets.length).clamp(0, double.infinity).toInt();
      _buckets = generateBuckets(
        widget.period,
        custom: widget.custom,
        offset: _offset,
      );
      _selected = (_selected).clamp(0, _buckets.length - 1);
      _cachedBars = null;
      _future = _fetch();
    });
  }

  TransactionFilters _filter() {
    final PeriodBucket b = _buckets[_selected];
    return TransactionFilters(
      category: CategoryRead.fromJson(<String, dynamic>{
        'type': 'categories',
        'id': '0',
        'attributes': <String, dynamic>{'name': widget.categoryName},
      }),
      start: b.start,
      end: b.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color tint = FtColors.categoryColor(
      widget.categoryName,
      context: context,
    );
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    final SettingsProvider settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        actions: <Widget>[
          IconButton(
            icon: Icon(
              settings.hideAmounts
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            tooltip: settings.hideAmounts
                ? 'Mostrar importes'
                : 'Ocultar importes',
            onPressed: () => settings.hideAmounts = !settings.hideAmounts,
          ),
        ],
        title: Row(
          children: <Widget>[
            FtCategoryIconWidget(
              icon: FtCategoryIcon.forName(widget.categoryName),
              color: tint,
              size: 18,
              padding: 9,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _buckets[_selected].rangeLabel,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          FutureBuilder<_DetailData>(
            future: _future,
            builder: (BuildContext context, AsyncSnapshot<_DetailData> snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final _DetailData data = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 12, 12),
                    child: Column(
                      children: <Widget>[
                        MonthlyBars(
                          data: data.bars,
                          selectedIndex: _selected,
                          onSelect: _onSelectBucket,
                          onPrevious: _canGoPrevious ? _onPrevious : null,
                          onNext: _canGoNext ? _onNext : null,
                          expenseOnly: !widget.isIncome,
                          incomeOnly: widget.isIncome,
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
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
                            key: ValueKey<int>(_selected),
                            children: <Widget>[
                              const Divider(height: 24),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Text(
                                      widget.isIncome ? 'Ingresado' : 'Gastado',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      currency.fmt(
                                        widget.isIncome
                                            ? data.bars[_selected].income
                                            : -data.bars[_selected].expense,
                                        context: context,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                            color: widget.isIncome
                                                ? FtColors.incomeOf(context)
                                                : null,
                                            fontWeight: FontWeight.w700,
                                            fontFeatures: const <FontFeature>[
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: HomeTransactions(
              key: ValueKey<int>(_selected),
              filters: _filter(),
            ),
          ),
        ],
      ),
    );
  }
}

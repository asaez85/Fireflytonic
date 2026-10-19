import 'dart:async';

import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/offline_cache.dart';
import 'package:waterflyiii/pages/home.dart';
import 'package:waterflyiii/pages/home/transactions.dart';
import 'package:waterflyiii/pages/home/transactions/filter.dart';
import 'package:waterflyiii/settings.dart';
import 'package:waterflyiii/theme.dart';

/// Cuenta simplificada para la pantalla de inicio.
class _Account {
  const _Account({
    required this.id,
    required this.name,
    required this.balance,
    required this.role,
    this.includeNetWorth = true,
    this.account,
  });
  final String id;
  final String name;
  final double balance;
  final String role;
  final bool includeNetWorth;
  final AccountRead? account;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'balance': balance,
    'role': role,
    'includeNetWorth': includeNetWorth,
  };

  factory _Account.fromJson(Map<String, dynamic> json) => _Account(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
    role: json['role'] as String? ?? '',
    includeNetWorth: json['includeNetWorth'] as bool? ?? true,
  );

  AccountRead toAccountRead() {
    if (account != null) {
      return account!;
    }
    return AccountRead(
      id: id,
      type: 'accounts',
      attributes: AccountProperties(
        name: name,
        currentBalance: balance.toString(),
        type: ShortAccountTypeProperty.asset,
        includeNetWorth: includeNetWorth,
      ),
    );
  }
}

class _SummaryData {
  const _SummaryData({
    required this.accounts,
    required this.income,
    required this.expense,
    this.history = const <double>[],
  });
  final List<_Account> accounts;
  final double income;
  final double expense;
  final List<double> history;

  double get total => accounts
      .where((_Account c) => c.includeNetWorth)
      .fold(0.0, (double a, _Account c) => a + c.balance);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'accounts': accounts.map((_Account a) => a.toJson()).toList(),
    'income': income,
    'expense': expense,
    'history': history,
  };

  factory _SummaryData.fromJson(Map<String, dynamic> json) => _SummaryData(
    accounts:
        (json['accounts'] as List<dynamic>?)
            ?.map((dynamic a) => _Account.fromJson(a as Map<String, dynamic>))
            .toList() ??
        <_Account>[],
    income: (json['income'] as num?)?.toDouble() ?? 0.0,
    expense: (json['expense'] as num?)?.toDouble() ?? 0.0,
    history:
        (json['history'] as List<dynamic>?)
            ?.map((dynamic e) => (e as num).toDouble())
            .toList() ??
        const <double>[],
  );
}

/// Pantalla de Inicio estilo Fintonic: patrimonio, resumen del mes y cuentas.
class HomeSummary extends StatefulWidget {
  const HomeSummary({super.key});

  @override
  State<HomeSummary> createState() => _HomeSummaryState();
}

class _HomeSummaryState extends State<HomeSummary>
    with AutomaticKeepAliveClientMixin {
  late Future<_SummaryData> _future;
  _SummaryData? _initialData;

  HomePatrimonyPeriod? _currentPeriod;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final dynamic cached = OfflineCache.instance.getJsonSync('summary_data');
    if (cached is Map<String, dynamic>) {
      try {
        _initialData = _SummaryData.fromJson(cached);
      } catch (_) {}
    }
    _future = _fetch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final HomePatrimonyPeriod period = context
        .watch<SettingsProvider>()
        .homePatrimonyPeriod;
    if (_currentPeriod != null && _currentPeriod != period) {
      _currentPeriod = period;
      _refresh();
    } else {
      _currentPeriod = period;
    }
  }

  Future<_SummaryData> _fetch() async {
    final FireflyIii api = context.read<FireflyService>().api;
    final SettingsProvider settings = context.read<SettingsProvider>();
    final HomePatrimonyPeriod period = settings.homePatrimonyPeriod;
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    final DateTime now = DateTime.now();
    final String start = DateFormat(
      'yyyy-MM-dd',
      'en_US',
    ).format(DateTime(now.year, now.month, 1));
    final String end = DateFormat('yyyy-MM-dd', 'en_US').format(now);
    final String chartStart = DateFormat(
      'yyyy-MM-dd',
      'en_US',
    ).format(period.getStartDate(now));

    final V1ChartAccountOverviewGetPeriod apiPeriod = switch (period) {
      HomePatrimonyPeriod.oneMonth => V1ChartAccountOverviewGetPeriod.value_1d,
      HomePatrimonyPeriod.threeMonths =>
        V1ChartAccountOverviewGetPeriod.value_1d,
      HomePatrimonyPeriod.sixMonths => V1ChartAccountOverviewGetPeriod.value_1w,
      HomePatrimonyPeriod.oneYear => V1ChartAccountOverviewGetPeriod.value_1w,
      HomePatrimonyPeriod.allTime => V1ChartAccountOverviewGetPeriod.value_1m,
    };

    try {
      final (
        Response<AccountArray> respAssets,
        Response<AccountArray> respLiab,
        Response<InsightTotal> incomeR,
        Response<InsightTotal> expenseR,
        Response<List<ChartDataSet>> chartR,
      ) = await (
        api.v1AccountsGet(type: AccountTypeFilter.assetAccount, limit: 100),
        api.v1AccountsGet(type: AccountTypeFilter.liabilities, limit: 100),
        api.v1InsightIncomeTotalGet(start: start, end: end),
        api.v1InsightExpenseTotalGet(start: start, end: end),
        api.v1ChartAccountOverviewGet(
          start: chartStart,
          end: end,
          period: apiPeriod,
          preselected: V1ChartAccountOverviewGetPreselected.all,
        ),
      ).wait;

      final List<AccountRead> allFetchedAccounts = <AccountRead>[
        ...?respAssets.body?.data,
        ...?respLiab.body?.data,
      ];
      final List<_Account> accounts = <_Account>[];
      final Map<String, bool> includeInNetWorth = <String, bool>{};
      final Set<String> liabilityNames = <String>{};
      for (final AccountRead a in allFetchedAccounts) {
        final String name = a.attributes.name.trim();
        final bool incNetWorth = a.attributes.includeNetWorth ?? true;
        includeInNetWorth[name] = incNetWorth;
        final bool isLiab =
            a.attributes.type == ShortAccountTypeProperty.liability ||
            a.attributes.type == ShortAccountTypeProperty.liabilities ||
            (a.attributes.type.value?.toLowerCase().contains('liab') ?? false);
        if (isLiab) {
          liabilityNames.add(name);
        }
        final double bal =
            double.tryParse(a.attributes.currentBalance ?? '0') ?? 0.0;
        final double effectiveBal = isLiab ? -bal.abs() : bal;
        if (incNetWorth && effectiveBal.abs() > 0.0001) {
          accounts.add(
            _Account(
              id: a.id,
              name: name,
              balance: effectiveBal,
              role: a.attributes.accountRole?.value ?? '',
              includeNetWorth: incNetWorth,
              account: a,
            ),
          );
        }
      }

      final Map<String, double> dailyTotals = <String, double>{};
      final List<ChartDataSet>? chartItems = chartR.body;
      if (chartItems != null) {
        for (final ChartDataSet item in chartItems) {
          final String label = item.label ?? '';
          if (includeInNetWorth[label] != true) {
            continue;
          }
          final bool isLiability =
              item.type == 'liability' || liabilityNames.contains(label);
          if (item.entries is Map<String, dynamic>) {
            final Map<String, dynamic> entries =
                item.entries as Map<String, dynamic>;
            for (final MapEntry<String, dynamic> e in entries.entries) {
              final double rawVal = double.tryParse(e.value.toString()) ?? 0.0;
              final double val = isLiability ? -rawVal.abs() : rawVal;
              dailyTotals[e.key] = (dailyTotals[e.key] ?? 0.0) + val;
            }
          }
        }
      }
      final List<String> sortedDates = dailyTotals.keys.toList()..sort();
      final List<double> history = sortedDates
          .map((String k) => dailyTotals[k]!)
          .toList();

      double sum(Iterable<InsightTotalEntry>? e) {
        double s = 0;
        for (final InsightTotalEntry x in e ?? <InsightTotalEntry>[]) {
          if (x.currencyId != null && x.currencyId != currency.id) {
            continue;
          }
          s += (x.differenceFloat ?? 0).abs();
        }
        return s;
      }

      final _SummaryData result = _SummaryData(
        accounts: accounts,
        income: sum(incomeR.body),
        expense: sum(expenseR.body),
        history: history,
      );

      unawaited(
        OfflineCache.instance.saveJson('summary_data', result.toJson()),
      );
      return result;
    } catch (e) {
      final dynamic cached = await OfflineCache.instance.getJson(
        'summary_data',
      );
      if (cached is Map<String, dynamic>) {
        return _SummaryData.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetch());
    await _future;
  }

  IconData _roleIcon(String role) => switch (role) {
    'savingAsset' => Icons.savings,
    'cashWalletAsset' => Icons.account_balance_wallet,
    'ccAsset' => Icons.credit_card,
    _ => Icons.account_balance,
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    context.watch<SettingsProvider>();
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    return FutureBuilder<_SummaryData>(
      future: _future,
      initialData: _initialData,
      builder: (BuildContext context, AsyncSnapshot<_SummaryData> snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final _SummaryData? data = snapshot.data ?? _initialData;
        if (data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "No se pudo cargar el inicio.\n${snapshot.error ?? ''}",
              ),
            ),
          );
        }

        return RefreshIndicator.adaptive(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: <Widget>[
              _PatrimonyCard(
                total: data.total,
                income: data.income,
                expense: data.expense,
                history: data.history,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  "Tus cuentas",
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Card(
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < data.accounts.length; i++) ...<Widget>[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 60,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.14),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          child: Icon(_roleIcon(data.accounts[i].role)),
                        ),
                        title: Text(
                          data.accounts[i].name,
                          style: Theme.of(context).textTheme.bodyLarge!
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        trailing: Text(
                          currency.fmt(
                            data.accounts[i].balance,
                            context: context,
                          ),
                          style: Theme.of(context).textTheme.titleSmall!
                              .copyWith(
                                fontWeight: FontWeight.w700,
                                color: data.accounts[i].balance >= 0
                                    ? Theme.of(context).colorScheme.onSurface
                                    : FtColors.coralOf(context),
                                fontFeatures: const <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                        onTap: () {
                          final AccountRead acc = data.accounts[i]
                              .toAccountRead();
                          final HomePageState? homeState = context
                              .findAncestorStateOfType<HomePageState>();
                          if (homeState != null) {
                            homeState.openTransactionsForAccount(acc);
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) => Scaffold(
                                  appBar: AppBar(
                                    title: Text(acc.attributes.name),
                                  ),
                                  body: HomeTransactions(
                                    filters: TransactionFilters(account: acc),
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
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

/// Tarjeta principal con el patrimonio total y el resumen del mes.
class _PatrimonyCard extends StatelessWidget {
  const _PatrimonyCard({
    required this.total,
    required this.income,
    required this.expense,
    this.history = const <double>[],
  });
  final double total;
  final double income;
  final double expense;
  final List<double> history;

  @override
  Widget build(BuildContext context) {
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FtTheme.radius),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FtTheme.radius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[FtColors.navy, FtColors.navySoft],
          ),
        ),
        child: Stack(
          children: <Widget>[
            if (history.length >= 2)
              Positioned.fill(
                child: CustomPaint(
                  painter: _SparklineBackgroundPainter(values: history),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        "Saldo neto",
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium!.copyWith(color: Colors.white70),
                      ),
                      Consumer<SettingsProvider>(
                        builder:
                            (
                              BuildContext context,
                              SettingsProvider settings,
                              _,
                            ) {
                              return PopupMenuButton<HomePatrimonyPeriod>(
                                initialValue: settings.homePatrimonyPeriod,
                                tooltip: 'Cambiar periodo del gráfico',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onSelected: (HomePatrimonyPeriod period) {
                                  settings.setHomePatrimonyPeriod(period);
                                },
                                itemBuilder: (BuildContext context) =>
                                    HomePatrimonyPeriod.values
                                        .map(
                                          (HomePatrimonyPeriod p) =>
                                              PopupMenuItem<
                                                HomePatrimonyPeriod
                                              >(
                                                value: p,
                                                child: Row(
                                                  children: <Widget>[
                                                    if (p ==
                                                        settings
                                                            .homePatrimonyPeriod)
                                                      const Icon(
                                                        Icons.check,
                                                        size: 18,
                                                      )
                                                    else
                                                      const SizedBox(width: 18),
                                                    const SizedBox(width: 8),
                                                    Text(p.label),
                                                  ],
                                                ),
                                              ),
                                        )
                                        .toList(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        settings.homePatrimonyPeriod.shortLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currency.fmt(total, context: context),
                    style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      _stat(
                        context,
                        Icons.south_west,
                        "Ingresos",
                        income,
                        FtColors.incomeLight,
                        onTap: () {
                          final DateTime now = DateTime.now();
                          final DateTime start = DateTime(
                            now.year,
                            now.month,
                            1,
                          );
                          final DateTime end = DateTime(
                            now.year,
                            now.month + 1,
                            0,
                            23,
                            59,
                            59,
                          );
                          final HomePageState? home = context
                              .findAncestorStateOfType<HomePageState>();
                          home?.openTransactionsForMonthType(
                            segment: 2, // Depósitos (Ingresos)
                            start: start,
                            end: end,
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      _stat(
                        context,
                        Icons.north_east,
                        "Gastos",
                        expense,
                        FtColors.coralLight,
                        onTap: () {
                          final DateTime now = DateTime.now();
                          final DateTime start = DateTime(
                            now.year,
                            now.month,
                            1,
                          );
                          final DateTime end = DateTime(
                            now.year,
                            now.month + 1,
                            0,
                            23,
                            59,
                            59,
                          );
                          final HomePageState? home = context
                              .findAncestorStateOfType<HomePageState>();
                          home?.openTransactionsForMonthType(
                            segment: 1, // Retiradas (Gastos)
                            start: start,
                            end: end,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    IconData icon,
    String label,
    double amount,
    Color color, {
    VoidCallback? onTap,
  }) {
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FtTheme.radiusSmall),
          splashColor: Colors.white.withValues(alpha: 0.15),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(FtTheme.radiusSmall),
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.22),
                  foregroundColor: color,
                  child: Icon(icon, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall!.copyWith(color: Colors.white70),
                    ),
                    Text(
                      currency.fmt(amount, context: context),
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter que dibuja una línea suave y un área sombreada de evolución
/// de fondo en la tarjeta de patrimonio.
class _SparklineBackgroundPainter extends CustomPainter {
  const _SparklineBackgroundPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) {
      return;
    }

    double minY = values.reduce((double a, double b) => a < b ? a : b);
    double maxY = values.reduce((double a, double b) => a > b ? a : b);
    final double diff = maxY - minY;
    final double padding = diff == 0
        ? (minY == 0 ? 10.0 : minY.abs() * 0.1)
        : diff * 0.15;
    minY -= padding;
    maxY += padding;
    final double rangeY = maxY - minY;

    // Queremos que la gráfica ocupe la parte inferior y media de la tarjeta
    // Dejando espacio superior para que no interfiera visualmente con los textos.
    final double topMargin = size.height * 0.22;
    final double bottomMargin = size.height * 0.04;
    final double availableHeight = size.height - topMargin - bottomMargin;

    final List<Offset> points = <Offset>[];
    final double stepX = size.width / (values.length - 1);
    for (int i = 0; i < values.length; i++) {
      final double x = i * stepX;
      final double normalizedY = (values[i] - minY) / rangeY;
      final double y = topMargin + (1.0 - normalizedY) * availableHeight;
      points.add(Offset(x, y));
    }

    final Path linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final Offset p0 = points[i];
      final Offset p1 = points[i + 1];
      final double midX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    // Relleno de área debajo de la curva con degradado sutil
    final Path fillPath = Path.from(linePath);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final Paint fillPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              FtColors.incomeLight.withValues(alpha: 0.18),
              FtColors.incomeLight.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromLTWH(0, topMargin, size.width, size.height - topMargin),
          )
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Trazo de la línea de evolución
    final Paint strokePaint = Paint()
      ..color = FtColors.incomeLight.withValues(alpha: 0.45)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklineBackgroundPainter oldDelegate) {
    if (identical(values, oldDelegate.values)) {
      return false;
    }
    if (values.length != oldDelegate.values.length) {
      return true;
    }
    for (int i = 0; i < values.length; i++) {
      if (values[i] != oldDelegate.values[i]) {
        return true;
      }
    }
    return false;
  }
}

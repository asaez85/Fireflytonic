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
    this.account,
  });
  final String id;
  final String name;
  final double balance;
  final String role;
  final AccountRead? account;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'balance': balance,
    'role': role,
  };

  factory _Account.fromJson(Map<String, dynamic> json) => _Account(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
    role: json['role'] as String? ?? '',
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
      ),
    );
  }
}

class _SummaryData {
  const _SummaryData({
    required this.accounts,
    required this.income,
    required this.expense,
  });
  final List<_Account> accounts;
  final double income;
  final double expense;

  double get total =>
      accounts.fold(0.0, (double a, _Account c) => a + c.balance);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'accounts': accounts.map((_Account a) => a.toJson()).toList(),
    'income': income,
    'expense': expense,
  };

  factory _SummaryData.fromJson(Map<String, dynamic> json) => _SummaryData(
    accounts:
        (json['accounts'] as List<dynamic>?)
            ?.map((dynamic a) => _Account.fromJson(a as Map<String, dynamic>))
            .toList() ??
        <_Account>[],
    income: (json['income'] as num?)?.toDouble() ?? 0.0,
    expense: (json['expense'] as num?)?.toDouble() ?? 0.0,
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

  Future<_SummaryData> _fetch() async {
    final FireflyIii api = context.read<FireflyService>().api;
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    final DateTime now = DateTime.now();
    final String start = DateFormat(
      'yyyy-MM-dd',
      'en_US',
    ).format(DateTime(now.year, now.month, 1));
    final String end = DateFormat('yyyy-MM-dd', 'en_US').format(now);

    try {
      final (
        Response<AccountArray> accountsR,
        Response<InsightTotal> incomeR,
        Response<InsightTotal> expenseR,
      ) = await (
        api.v1AccountsGet(type: AccountTypeFilter.asset),
        api.v1InsightIncomeTotalGet(start: start, end: end),
        api.v1InsightExpenseTotalGet(start: start, end: end),
      ).wait;

      final List<_Account> accounts = <_Account>[];
      for (final AccountRead a in accountsR.body?.data ?? <AccountRead>[]) {
        if (!(a.attributes.active ?? true)) {
          continue;
        }
        accounts.add(
          _Account(
            id: a.id,
            name: a.attributes.name,
            balance: double.tryParse(a.attributes.currentBalance ?? '0') ?? 0,
            role: a.attributes.accountRole?.value ?? '',
            account: a,
          ),
        );
      }

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
  });
  final double total;
  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    return Card(
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
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              "Patrimonio total",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              currency.fmt(total, context: context),
              style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
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
                ),
                const SizedBox(width: 12),
                _stat(
                  context,
                  Icons.north_east,
                  "Gastos",
                  expense,
                  FtColors.coralLight,
                ),
              ],
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
    Color color,
  ) {
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    return Expanded(
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
    );
  }
}

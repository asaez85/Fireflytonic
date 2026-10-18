import 'dart:async';

import 'package:animations/animations.dart';
import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.enums.swagger.dart'
    as enums;
import 'package:waterflyiii/offline_cache.dart';
import 'package:waterflyiii/pages/home.dart';
import 'package:waterflyiii/pages/home/transactions/export_page.dart';
import 'package:waterflyiii/pages/home/transactions/filter.dart';
import 'package:waterflyiii/pages/home/transactions/search_page.dart';
import 'package:waterflyiii/pages/transaction.dart';
import 'package:waterflyiii/pages/transaction/delete.dart';
import 'package:waterflyiii/settings.dart';
import 'package:waterflyiii/stock.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/timezonehandler.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';
import 'package:waterflyiii/pages/transaction_consult.dart';
import 'package:waterflyiii/widgets/listview_pagedchildbuilder.dart';

class TransactionSum {
  double withdrawals = 0;
  double deposits = 0;
  double transfers = 0;

  double get total => deposits - withdrawals;
}

class HomeTransactions extends StatefulWidget {
  const HomeTransactions({super.key, this.filters, this.initialSegment});

  final TransactionFilters? filters;
  final int? initialSegment;

  @override
  State<HomeTransactions> createState() => HomeTransactionsState();
}

class HomeTransactionsState extends State<HomeTransactions>
    with AutomaticKeepAliveClientMixin {
  final Logger log = Logger("Pages.Home.Transaction");

  final int _numberOfPostsPerRequest = 50;
  late PagingState<int, TransactionRead> _pagingState;

  DateTime? _lastDate;
  final List<int> _rowsWithDate = <int>[];
  late TransStock _stock;
  late TimeZoneHandler _tzHandler;

  TransactionSum _txSum = TransactionSum();
  final List<String> _txSumUsed = <String>[];

  final TransactionFilters _filters = TransactionFilters();
  final ValueNotifier<bool> _tagsHidden = ValueNotifier<bool>(false);
  final Map<String, double> _runningBalancesByTransactionId =
      <String, double>{};
  double? _lastCalculatedBalance;
  final Map<String, double> _accountBalances = <String, double>{};
  final Map<String, double> _accountBalancesByName = <String, double>{};
  final Map<String, double> _lastCalculatedBalanceByAccount =
      <String, double>{};

  // Pestañas estilo Fintonic: 0=Todos, 1=Gastos, 2=Ingresos, 3=Traspasos.
  int _segment = 0;
  bool _isRefreshing = false;
  // Resumen del mes en curso y saldo de cuentas para la tarjeta de cabecera.
  Future<({double income, double expense, double accountsBalance})>?
  _summaryFuture;
  ({double income, double expense, double accountsBalance})? _cachedSummary;

  bool _isRevenueOrExpense(ShortAccountTypeProperty? type) {
    return type == ShortAccountTypeProperty.revenue ||
        type == ShortAccountTypeProperty.expense;
  }

  void setAccountFilter(AccountRead account) {
    _filters.reset();
    _filters.account = account;
    _filters.updateFilters();
    _rowsWithDate.clear();
    _lastDate = null;
    _txSum = TransactionSum();
    _txSumUsed.clear();
    _runningBalancesByTransactionId.clear();
    _lastCalculatedBalance = null;
    _lastCalculatedBalanceByAccount.clear();
    _summaryFuture = _fetchSummary();
    if (mounted) {
      setState(() {
        _pagingState = _resetPaging();
      });
    }
  }

  void setBudgetFilter(BudgetRead budget) {
    _filters.reset();
    _filters.budget = budget;
    _filters.updateFilters();
    _rowsWithDate.clear();
    _lastDate = null;
    _txSum = TransactionSum();
    _txSumUsed.clear();
    _runningBalancesByTransactionId.clear();
    _lastCalculatedBalance = null;
    _lastCalculatedBalanceByAccount.clear();
    _summaryFuture = _fetchSummary();
    if (mounted) {
      setState(() {
        _pagingState = _resetPaging();
      });
    }
  }

  void clearAccountFilter() {
    _filters.account = null;
    _filters.updateFilters();
    _rowsWithDate.clear();
    _lastDate = null;
    _txSum = TransactionSum();
    _txSumUsed.clear();
    _runningBalancesByTransactionId.clear();
    _lastCalculatedBalance = null;
    _lastCalculatedBalanceByAccount.clear();
    _summaryFuture = _fetchSummary();
    if (mounted) {
      setState(() {
        _pagingState = _resetPaging();
      });
    }
  }

  void setTypeFilter({required int segment, DateTime? start, DateTime? end}) {
    _filters.reset();
    _filters.start = start;
    _filters.end = end;
    _filters.updateFilters();
    _rowsWithDate.clear();
    _lastDate = null;
    _txSum = TransactionSum();
    _txSumUsed.clear();
    _runningBalancesByTransactionId.clear();
    _segment = segment;
    _lastCalculatedBalance = null;
    _lastCalculatedBalanceByAccount.clear();
    _summaryFuture = _fetchSummary();
    if (mounted) {
      setState(() {
        _pagingState = _resetPaging();
      });
    }
  }

  void clearBudgetFilter() {
    _filters.budget = null;
    _filters.updateFilters();
    _rowsWithDate.clear();
    _lastDate = null;
    _txSum = TransactionSum();
    _txSumUsed.clear();
    _runningBalancesByTransactionId.clear();
    _lastCalculatedBalance = null;
    _lastCalculatedBalanceByAccount.clear();
    _summaryFuture = _fetchSummary();
    if (mounted) {
      setState(() {
        _pagingState = _resetPaging();
      });
    }
  }

  void clearAllFilters() {
    _filters.reset();
    _filters.updateFilters();
    _rowsWithDate.clear();
    _lastDate = null;
    _txSum = TransactionSum();
    _txSumUsed.clear();
    _runningBalancesByTransactionId.clear();
    _lastCalculatedBalance = null;
    _lastCalculatedBalanceByAccount.clear();
    _summaryFuture = _fetchSummary();
    if (mounted) {
      setState(() {
        _pagingState = _resetPaging();
      });
    }
  }

  Future<({double income, double expense, double accountsBalance})>
  _fetchSummary() async {
    try {
      final FireflyIii api = context.read<FireflyService>().api;
      final CurrencyRead currency = context
          .read<FireflyService>()
          .defaultCurrency;
      final DateTime now = _tzHandler.sNow().clearTime();
      final String start = DateFormat(
        'yyyy-MM-dd',
        'en_US',
      ).format(now.copyWith(day: 1));
      final String end = DateFormat('yyyy-MM-dd', 'en_US').format(now);

      final int? filterAccountId = _filters.account != null
          ? int.tryParse(_filters.account!.id)
          : null;
      final List<int>? insightAccounts = filterAccountId != null
          ? <int>[filterAccountId]
          : null;

      final (
        Response<AccountArray> accountsR,
        Response<InsightTotal> incomeR,
        Response<InsightTotal> expenseR,
      ) = await (
        api.v1AccountsGet(type: .assetAccount),
        api.v1InsightIncomeTotalGet(
          start: start,
          end: end,
          accounts: insightAccounts,
        ),
        api.v1InsightExpenseTotalGet(
          start: start,
          end: end,
          accounts: insightAccounts,
        ),
      ).wait;

      double totalAssetsBalance = 0;
      _accountBalances.clear();
      _accountBalancesByName.clear();
      for (final AccountRead a in accountsR.body?.data ?? <AccountRead>[]) {
        if (!(a.attributes.active ?? true)) {
          continue;
        }
        // El saldo neto de la cabecera solo computa cuentas activas marcadas
        // para incluir en el valor neto.
        if (!(a.attributes.includeNetWorth ?? true)) {
          continue;
        }
        final double bal =
            double.tryParse(a.attributes.currentBalance ?? '0') ?? 0.0;
        _accountBalances[a.id] = bal;
        _accountBalancesByName[a.attributes.name] = bal;
        totalAssetsBalance += bal;
      }

      final double accountsBalance = _filters.account != null
          ? (_accountBalances[_filters.account!.id] ??
                double.tryParse(
                  _filters.account!.attributes.currentBalance ?? '0',
                ) ??
                0.0)
          : totalAssetsBalance;

      double sum(Iterable<InsightTotalEntry>? entries) {
        double s = 0;
        for (final InsightTotalEntry e in entries ?? <InsightTotalEntry>[]) {
          if (e.currencyId != null && e.currencyId != currency.id) {
            continue;
          }
          s += (e.differenceFloat ?? 0).abs();
        }
        return s;
      }

      final ({double expense, double income, double accountsBalance}) res = (
        income: sum(incomeR.body),
        expense: sum(expenseR.body),
        accountsBalance: accountsBalance,
      );
      if (_filters.account == null) {
        unawaited(
          OfflineCache.instance.saveJson('tx_month_summary', <String, dynamic>{
            'income': res.income,
            'expense': res.expense,
            'accountsBalance': res.accountsBalance,
            'accountBalances': _accountBalances,
            'accountBalancesByName': _accountBalancesByName,
          }),
        );
      }
      return res;
    } catch (e) {
      log.warning("Offline fallback for _fetchSummary: $e");
      final dynamic cached = await OfflineCache.instance.getJson(
        'tx_month_summary',
      );
      if (cached is Map<String, dynamic>) {
        if (cached['accountBalances'] is Map<String, dynamic>) {
          (cached['accountBalances'] as Map<String, dynamic>).forEach((
            String k,
            dynamic v,
          ) {
            if (v is num) _accountBalances[k] = v.toDouble();
          });
        }
        if (cached['accountBalancesByName'] is Map<String, dynamic>) {
          (cached['accountBalancesByName'] as Map<String, dynamic>).forEach((
            String k,
            dynamic v,
          ) {
            if (v is num) _accountBalancesByName[k] = v.toDouble();
          });
        }
        final double cachedAccountsBal = _filters.account != null
            ? (_accountBalances[_filters.account!.id] ??
                  double.tryParse(
                    _filters.account!.attributes.currentBalance ?? '0',
                  ) ??
                  0.0)
            : ((cached['accountsBalance'] as num?)?.toDouble() ?? 0.0);
        return (
          income: (cached['income'] as num?)?.toDouble() ?? 0.0,
          expense: (cached['expense'] as num?)?.toDouble() ?? 0.0,
          accountsBalance: cachedAccountsBal,
        );
      }
      final dynamic summaryCache = await OfflineCache.instance.getJson(
        'summary_data',
      );
      if (summaryCache is Map<String, dynamic>) {
        double accBal = 0;
        final dynamic accounts = summaryCache['accounts'];
        if (accounts is List<dynamic>) {
          for (final dynamic a in accounts) {
            if (a is Map<String, dynamic>) {
              final String name = a['name'] as String? ?? '';
              final String id = a['id'] as String? ?? '';
              final double bal = (a['balance'] as num?)?.toDouble() ?? 0.0;
              final bool includeNetWorth = a['includeNetWorth'] != false;
              if (_filters.account != null) {
                if ((id.isNotEmpty && id == _filters.account!.id) ||
                    (name.isNotEmpty &&
                        name == _filters.account!.attributes.name)) {
                  accBal = bal;
                  break;
                }
              } else if (includeNetWorth) {
                accBal += bal;
              }
            }
          }
        }
        return (
          income: (summaryCache['income'] as num?)?.toDouble() ?? 0.0,
          expense: (summaryCache['expense'] as num?)?.toDouble() ?? 0.0,
          accountsBalance: accBal,
        );
      }
      return (income: 0.0, expense: 0.0, accountsBalance: 0.0);
    }
  }

  /// Generación de la paginación. Se incrementa en cada reset para que las
  /// respuestas en vuelo de una consulta anterior (p. ej. otra pestaña
  /// Todos/Gastos/Ingresos/Traspasos) se descarten en lugar de mezclarse.
  int _pagingGeneration = 0;

  PagingState<int, TransactionRead> _resetPaging() {
    _pagingGeneration++;
    return _pagingState.reset();
  }

  void _onSegmentChanged(int index) {
    if (_segment == index) {
      return;
    }
    _rowsWithDate.clear();
    _lastDate = null;
    _txSum = TransactionSum();
    _txSumUsed.clear();
    _runningBalancesByTransactionId.clear();
    setState(() {
      _segment = index;
      _lastCalculatedBalance = null;
      _lastCalculatedBalanceByAccount.clear();
      _pagingState = _resetPaging();
    });
  }

  @override
  void initState() {
    super.initState();

    _tzHandler = context.read<FireflyService>().tzHandler;
    _pagingState = PagingState<int, TransactionRead>();
    _tagsHidden.value = context.read<SettingsProvider>().hideTags;

    if (widget.initialSegment != null) {
      _segment = widget.initialSegment!;
    }

    if (widget.filters != null) {
      _filters.account = widget.filters!.account;
      _filters.text = widget.filters!.text;
      _filters.currency = widget.filters!.currency;
      _filters.category = widget.filters!.category;
      _filters.budget = widget.filters!.budget;
      _filters.bill = widget.filters!.bill;
      _filters.tags = widget.filters!.tags;
      _filters.start = widget.filters!.start;
      _filters.end = widget.filters!.end;
      _filters.updateFilters();
    }

    // Tarjeta de saldo (resumen del mes) en la pestaña principal o con filtro de cuenta.
    if (widget.filters == null || widget.filters?.account != null) {
      final dynamic cached =
          OfflineCache.instance.getJsonSync('tx_month_summary') ??
          OfflineCache.instance.getJsonSync('summary_data');
      if (cached is Map<String, dynamic>) {
        double accBal = (cached['accountsBalance'] as num?)?.toDouble() ?? 0.0;
        if (cached['accountBalances'] is Map<String, dynamic>) {
          (cached['accountBalances'] as Map<String, dynamic>).forEach((
            String k,
            dynamic v,
          ) {
            if (v is num) _accountBalances[k] = v.toDouble();
          });
        }
        if (cached['accountBalancesByName'] is Map<String, dynamic>) {
          (cached['accountBalancesByName'] as Map<String, dynamic>).forEach((
            String k,
            dynamic v,
          ) {
            if (v is num) _accountBalancesByName[k] = v.toDouble();
          });
        }
        if (accBal == 0.0 && cached['accounts'] is List<dynamic>) {
          for (final dynamic a in cached['accounts'] as List<dynamic>) {
            if (a is Map<String, dynamic>) {
              accBal += (a['balance'] as num?)?.toDouble() ?? 0.0;
            }
          }
        }
        if (_filters.account != null) {
          accBal =
              _accountBalances[_filters.account!.id] ??
              double.tryParse(
                _filters.account!.attributes.currentBalance ?? '0',
              ) ??
              0.0;
        }
        _cachedSummary = (
          income: (cached['income'] as num?)?.toDouble() ?? 0.0,
          expense: (cached['expense'] as num?)?.toDouble() ?? 0.0,
          accountsBalance: accBal,
        );
      }
      _summaryFuture = _fetchSummary();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final HomePageState? homeState = context
          .findAncestorStateOfType<HomePageState>();
      if (homeState?.pendingAccountFilter != null) {
        final AccountRead pending = homeState!.pendingAccountFilter!;
        homeState.pendingAccountFilter = null;
        setAccountFilter(pending);
      } else if (homeState?.pendingBudgetFilter != null) {
        final BudgetRead pending = homeState!.pendingBudgetFilter!;
        homeState.pendingBudgetFilter = null;
        setBudgetFilter(pending);
      } else if (homeState?.pendingTypeFilter != null) {
        final ({int segment, DateTime start, DateTime end}) pending =
            homeState!.pendingTypeFilter!;
        homeState.pendingTypeFilter = null;
        setTypeFilter(
          segment: pending.segment,
          start: pending.start,
          end: pending.end,
        );
      }
    });

    // Only add filter button when in own tab
    if (widget.filters == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<PageActions>().set(widget.key!, <Widget>[
          ValueListenableBuilder<bool>(
            valueListenable: _tagsHidden,
            builder: (BuildContext context, bool value, _) => IconButton(
              icon: const Icon(Icons.bookmarks_outlined),
              selectedIcon: Icon(
                Icons.bookmarks,
                color: Theme.of(context).colorScheme.primary,
              ),
              isSelected: !value,
              tooltip: S.of(context).homeTransactionsSettingsShowTags,
              onPressed: () {
                final SettingsProvider settings = context
                    .read<SettingsProvider>();
                settings.hideTags = !settings.hideTags;
                _tagsHidden.value = settings.hideTags;
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: "Exportar movimientos",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    const ExportTransactionsPage(),
              ),
            ),
          ),
          ChangeNotifierProvider<TransactionFilters>.value(
            value: _filters,
            builder: (BuildContext context, _) => IconButton(
              icon: const Icon(Icons.filter_alt_outlined),
              selectedIcon: Icon(
                Icons.filter_alt,
                color: Theme.of(context).colorScheme.primary,
              ),
              isSelected: context.watch<TransactionFilters>().hasFilters,
              tooltip: S.of(context).homeTransactionsActionFilter,
              onPressed: () async {
                final TransactionFilters oldFilters = _filters.copyWith();
                final bool? ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (BuildContext context) =>
                        TransactionsSearchPage(initialFilters: _filters),
                  ),
                );
                if (ok == null || !ok) {
                  _filters.account = oldFilters.account;
                  _filters.accounts = oldFilters.accounts;
                  _filters.budget = oldFilters.budget;
                  _filters.category = oldFilters.category;
                  _filters.categories = oldFilters.categories;
                  _filters.currency = oldFilters.currency;
                  _filters.text = oldFilters.text;
                  _filters.bill = oldFilters.bill;
                  _filters.tags = oldFilters.tags;
                  _filters.start = oldFilters.start;
                  _filters.end = oldFilters.end;
                  _filters.updateFilters();
                  return;
                }
                _filters.updateFilters();
                _rowsWithDate.clear();
                _lastDate = null;
                _txSum = TransactionSum();
                _txSumUsed.clear();
                _runningBalancesByTransactionId.clear();
                _lastCalculatedBalance = null;
                _lastCalculatedBalanceByAccount.clear();
                _summaryFuture = _fetchSummary();
                setState(() {
                  _pagingState = _resetPaging();
                });
              },
            ),
          ),
        ]);
      });
    }

    _stock = context.read<FireflyService>().transStock!;
    _stock.addListener(notifRefresh);
  }

  @override
  void dispose() {
    _stock.removeListener(notifRefresh);

    super.dispose();
  }

  void notifRefresh() {
    if (_isRefreshing) return;
    if (_pagingState.pages != null && _pagingState.pages!.isNotEmpty) {
      _handleRefresh();
    } else {
      setState(() {
        _lastCalculatedBalance = null;
        _pagingState = _resetPaging();
      });
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });

    try {
      context.read<FireflyService>().transStock!.clear(notify: false);
      if (_summaryFuture != null) {
        _summaryFuture = _fetchSummary();
      }
      await _fetchPage(isRefresh: true);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _fetchPage({bool isRefresh = false}) async {
    if (!isRefresh && _pagingState.isLoading) return;
    if (isRefresh) {
      // Invalida cualquier carga normal en vuelo: el refresh reemplaza todo.
      _pagingGeneration++;
    }
    final int generation = _pagingGeneration;
    final int segment = _segment;
    bool isStale() =>
        !mounted || generation != _pagingGeneration || segment != _segment;
    final TransStock? stock = context.read<FireflyService>().transStock;
    if (stock == null) {
      throw Exception("Stock not available");
    }
    final SettingsProvider settings = context.read<SettingsProvider>();

    if (!isRefresh) {
      setState(() {
        _pagingState = _pagingState.copyWith(isLoading: true, error: null);
      });
    }

    final int pageKey = isRefresh ? 1 : ((_pagingState.keys?.last ?? 0) + 1);
    log.finest(
      "Getting page $pageKey (isRefresh: $isRefresh, ${_pagingState.pages?.length} pages loaded)",
    );

    int attempts = 0;
    const int maxAttempts = 2;

    while (attempts < maxAttempts) {
      attempts++;
      try {
        late TransStockRead stockResponse;

        if (widget.filters != null) {
          _filters.account = widget.filters!.account;
          _filters.accounts = widget.filters!.accounts;
          _filters.text = widget.filters!.text;
          _filters.currency = widget.filters!.currency;
          _filters.category = widget.filters!.category;
          _filters.categories = widget.filters!.categories;
          _filters.budget = widget.filters!.budget;
          _filters.bill = widget.filters!.bill;
          _filters.tags = widget.filters!.tags;
          _filters.start = widget.filters!.start;
          _filters.end = widget.filters!.end;
          _filters.updateFilters();
        }

        // Get start date
        late DateTime startDate;
        final DateTime now = _tzHandler.sNow().clearTime();
        switch (settings.transactionDateFilter) {
          case .currentMonth:
            startDate = now.copyWith(day: 1);
            break;
          case .currentYear:
            startDate = now.copyWith(month: 1, day: 1);
            break;
          case .last30Days:
            startDate = now.subtract(const Duration(days: 30));
            break;
          case .lastYear:
            startDate = now.copyWith(year: now.year - 1);
            break;
          default:
            // Don't use 0 seconds, as DST & stuff might throw an error:
            // "The start must be a date after 1970-01-02."
            startDate = DateTime.fromMillisecondsSinceEpoch(
              365 * 24 * 60 * 60 * 1000,
            );
            break;
        }

        // Pestañas estilo Fintonic (segmento rápido)
        final enums.TransactionTypeFilter segmentType = switch (_segment) {
          1 => .withdrawal,
          2 => .deposit,
          3 => .transfer,
          _ => .all,
        };

        // Faster than searching for an account, and also has cache (stock) behind
        // This search should never have additional filters!
        final bool hasOtherFilters =
            _filters.text != null ||
            _filters.currency != null ||
            _filters.category != null ||
            _filters.categories.isNotEmpty ||
            _filters.budget != null ||
            _filters.bill != null ||
            (_filters.tags?.tags.isNotEmpty ?? false) ||
            _filters.start != null ||
            _filters.end != null;

        if (_filters.account != null &&
            _filters.accounts.isEmpty &&
            !hasOtherFilters) {
          stockResponse = await stock.getAccount(
            id: _filters.account!.id,
            page: pageKey,
            limit: _numberOfPostsPerRequest,
            type: segmentType,
            start: settings.showFutureTXs
                ? null
                : DateFormat('yyyy-MM-dd', 'en_US').format(startDate),
            end: settings.showFutureTXs
                ? null
                : DateFormat('yyyy-MM-dd', 'en_US').format(now),
          );
        } else if (_filters.hasFilters || hasOtherFilters) {
          String query = _filters.text ?? "";
          if (_filters.accounts.isNotEmpty) {
            final String accountIds = _filters.accounts
                .map((AccountRead a) => a.id)
                .join(",");
            query = "account_id:$accountIds $query";
          } else if (_filters.account != null) {
            query = "account_id:${_filters.account!.id} $query";
          }
          if (_segment == 1) {
            query = "type:withdrawal $query";
          } else if (_segment == 2) {
            query = "type:deposit $query";
          } else if (_segment == 3) {
            query = "type:transfer $query";
          }
          if (_filters.currency != null) {
            query = "currency_is:${_filters.currency!.attributes.code} $query";
          }
          if (_filters.categories.isNotEmpty) {
            if (_filters.categories.length == 1) {
              query =
                  "category_is:\"${_filters.categories.first.attributes.name}\" $query";
            }
          } else if (_filters.category != null) {
            query = (_filters.category!.id == "-1")
                ? "has_no_category:true $query"
                : "category_is:\"${_filters.category!.attributes.name}\" $query";
          }
          if (_filters.budget != null) {
            query = (_filters.budget!.id == "-1")
                ? "has_no_budget:true $query"
                : "budget_is:\"${_filters.budget!.attributes.name}\" $query";
          }
          if (_filters.bill != null) {
            query = (_filters.bill!.id == "-1")
                ? "has_no_bill:true $query"
                : "bill_is:\"${_filters.bill!.attributes.name}\" $query";
          }
          if (_filters.tags != null) {
            for (String tag in _filters.tags!.tags) {
              query = "tag_is:\"$tag\" $query";
            }
          }
          final DateTime effectiveStart = _filters.start ?? startDate;
          query =
              "date_after:${DateFormat('yyyy-MM-dd', 'en_US').format(effectiveStart)} $query";
          if (_filters.end != null) {
            query =
                "date_before:${DateFormat('yyyy-MM-dd', 'en_US').format(_filters.end!)} $query";
          } else if (!settings.showFutureTXs) {
            query = "date_before:today $query";
          }
          log.fine(() => "Search query: $query");
          stockResponse = await stock.getSearch(
            query: query,
            page: pageKey,
            limit: _numberOfPostsPerRequest,
          );
          if (_filters.categories.length > 1) {
            final Set<String> catNames = _filters.categories
                .map((CategoryRead c) => c.attributes.name.toLowerCase())
                .toSet();
            stockResponse = TransStockRead(
              stockResponse.data.where((TransactionRead tx) {
                return tx.attributes.transactions.any(
                  (TransactionSplit s) =>
                      catNames.contains(s.categoryName?.toLowerCase()),
                );
              }).toList(),
              stockResponse.pagination,
            );
          }
        } else {
          stockResponse = await stock.get(
            page: pageKey,
            limit: _numberOfPostsPerRequest,
            type: segmentType,
            end: settings.showFutureTXs
                ? null
                : DateFormat('yyyy-MM-dd', 'en_US').format(now),
            start: DateFormat('yyyy-MM-dd', 'en_US').format(startDate),
          );
        }

        final List<TransactionRead> transactionList = stockResponse.data;

        // Respuesta de una consulta anterior (otra pestaña/filtro): descartar.
        if (isStale()) {
          log.finer("_fetchPage(): discarding stale response (page $pageKey)");
          return;
        }

        if (isRefresh) {
          _rowsWithDate.clear();
          _lastDate = null;
          _txSum = TransactionSum();
          _txSumUsed.clear();
          _runningBalancesByTransactionId.clear();
          _lastCalculatedBalance = null;
          _lastCalculatedBalanceByAccount.clear();
        }

        if (_filters.account != null) {
          final AccountRead account = _filters.account!;
          // Attempt to retrieve the opening balance
          double balance =
              _lastCalculatedBalance ??
              double.tryParse(account.attributes.currentBalance!) ??
              0.0;
          // If the account is a revenue/expense account, we need to invert the balance
          if (_lastCalculatedBalance == null &&
              _isRevenueOrExpense(account.attributes.type)) {
            balance *= -1;
          }
          for (TransactionRead item in transactionList) {
            _runningBalancesByTransactionId[item.id] = balance;
            // Attempt to retrieve the transaction total amount
            for (TransactionSplit tx in item.attributes.transactions) {
              final double amount = double.tryParse(tx.amount) ?? 0.0;
              // Should never be the case
              if (amount == 0.0) {
                continue;
              }

              if (tx.type == .withdrawal) {
                balance += amount;
              } else if (tx.type == .transfer) {
                if (tx.destinationId == account.id) {
                  balance -= amount;
                } else {
                  balance += amount;
                }
              } else {
                balance -= amount;
              }
            }
            _lastCalculatedBalance = balance;
          }
        } else {
          if (_accountBalances.isEmpty && _summaryFuture != null) {
            try {
              await _summaryFuture;
            } catch (_) {}
          }
          if (_accountBalances.isEmpty && mounted) {
            try {
              final FireflyIii api = context.read<FireflyService>().api;
              final Response<AccountArray> resp = await api.v1AccountsGet(
                type: .assetAccount,
              );
              if (resp.body?.data != null) {
                for (final AccountRead a in resp.body!.data) {
                  if (!(a.attributes.active ?? true)) continue;
                  final double bal =
                      double.tryParse(a.attributes.currentBalance ?? '0') ??
                      0.0;
                  _accountBalances[a.id] = bal;
                  _accountBalancesByName[a.attributes.name] = bal;
                }
              }
            } catch (_) {}
          }
          if (isStale()) {
            return;
          }

          for (TransactionRead item in transactionList) {
            final List<TransactionSplit> splits = item.attributes.transactions;
            if (splits.isEmpty) {
              continue;
            }
            final TransactionSplit firstTx = splits.first;
            final String? accountId = switch (firstTx.type) {
              TransactionTypeProperty.withdrawal => firstTx.sourceId,
              TransactionTypeProperty.deposit => firstTx.destinationId,
              TransactionTypeProperty.transfer => firstTx.sourceId,
              _ =>
                firstTx.sourceType == AccountTypeProperty.assetAccount
                    ? firstTx.sourceId
                    : firstTx.destinationId,
            };
            final String? accountName = switch (firstTx.type) {
              TransactionTypeProperty.withdrawal => firstTx.sourceName,
              TransactionTypeProperty.deposit => firstTx.destinationName,
              TransactionTypeProperty.transfer => firstTx.sourceName,
              _ => firstTx.sourceName ?? firstTx.destinationName,
            };

            final String? serverBalStr = switch (firstTx.type) {
              TransactionTypeProperty.deposit =>
                firstTx.destinationBalanceAfter ?? firstTx.sourceBalanceAfter,
              TransactionTypeProperty.withdrawal =>
                firstTx.sourceBalanceAfter ?? firstTx.destinationBalanceAfter,
              _ =>
                firstTx.sourceBalanceAfter ?? firstTx.destinationBalanceAfter,
            };
            final double? serverBal = serverBalStr != null
                ? double.tryParse(serverBalStr)
                : null;

            final String accKey = accountId ?? accountName ?? 'default';
            double currentAccBal =
                _lastCalculatedBalanceByAccount[accKey] ??
                (accountId != null ? _accountBalances[accountId] : null) ??
                (accountName != null
                    ? _accountBalancesByName[accountName]
                    : null) ??
                serverBal ??
                0.0;

            if (serverBal != null) {
              currentAccBal = serverBal;
            }

            _runningBalancesByTransactionId[item.id] = currentAccBal;

            for (TransactionSplit tx in splits) {
              final double amount = double.tryParse(tx.amount) ?? 0.0;
              if (amount == 0.0) {
                continue;
              }
              if (tx.type == TransactionTypeProperty.withdrawal) {
                currentAccBal += amount;
              } else if (tx.type == TransactionTypeProperty.deposit) {
                currentAccBal -= amount;
              } else if (tx.type == TransactionTypeProperty.transfer) {
                currentAccBal += amount;
              } else {
                currentAccBal -= amount;
              }
            }
            _lastCalculatedBalanceByAccount[accKey] = currentAccBal;
          }
        }
        for (TransactionRead item in transactionList) {
          if (_txSumUsed.contains(item.id)) {
            continue;
          }
          _txSumUsed.add(item.id);
          for (TransactionSplit tx in item.attributes.transactions) {
            switch (tx.type) {
              case .deposit:
                _txSum.deposits +=
                    double.tryParse(tx.pcAmount ?? tx.amount) ?? 0.0;
                break;
              case .withdrawal:
                _txSum.withdrawals +=
                    double.tryParse(tx.pcAmount ?? tx.amount) ?? 0.0;
                break;
              case .transfer:
                _txSum.transfers +=
                    double.tryParse(tx.pcAmount ?? tx.amount) ?? 0.0;
                break;
              case .openingBalance:
              case .reconciliation:
              case .swaggerGeneratedUnknown:
              // do nothing, ignore
            }
          }
        }

        final bool isLastPage;
        if (stockResponse.pagination != null) {
          isLastPage =
              stockResponse.pagination!.currentPage ==
              stockResponse.pagination!.totalPages;
        } else {
          isLastPage = transactionList.length < _numberOfPostsPerRequest;
        }

        if (!isStale()) {
          setState(() {
            if (isRefresh) {
              _pagingState = PagingState<int, TransactionRead>(
                pages: <List<TransactionRead>>[transactionList],
                keys: <int>[pageKey],
                hasNextPage: !isLastPage,
                isLoading: false,
                error: null,
              );
            } else {
              _pagingState = _pagingState.copyWith(
                pages: <List<TransactionRead>>[
                  ...?_pagingState.pages,
                  transactionList,
                ],
                keys: <int>[...?_pagingState.keys, pageKey],
                hasNextPage: !isLastPage,
                isLoading: false,
                error: null,
              );
            }
          });
        }
        return;
      } catch (e, stackTrace) {
        if (isStale()) {
          return;
        }
        if (attempts < maxAttempts) {
          log.warning(
            "_fetchPage() attempt $attempts failed, retrying in 500ms: $e",
          );
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue;
        }
        log.severe("_fetchPage()", e, stackTrace);
        if (mounted &&
            (!isRefresh ||
                _pagingState.pages == null ||
                _pagingState.pages!.isEmpty)) {
          setState(() {
            _pagingState = _pagingState.copyWith(error: e, isLoading: false);
          });
        }
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    log.finest(() => "build()");
    super.build(context);
    context.watch<SettingsProvider>();

    final Widget list = RefreshIndicator.adaptive(
      onRefresh: _handleRefresh,
      child: PagedListView<int, TransactionRead>(
        state: _pagingState,
        fetchNextPage: () => _fetchPage(),
        builderDelegate: customPagedChildBuilderDelegate<TransactionRead>(
          itemBuilder: transactionRowBuilder,
          noMoreItemsIndicatorBuilder: (BuildContext context) {
            final CurrencyRead defaultCurrency = context
                .read<FireflyService>()
                .defaultCurrency;
            return Padding(
              padding: const .symmetric(horizontal: 8),
              child: Column(
                children: <Widget>[
                  const Divider(),
                  Table(
                    //border: TableBorder.all(), // :DEBUG:
                    columnWidths: const <int, TableColumnWidth>{
                      0: FlexColumnWidth(),
                      1: FlexColumnWidth(),
                      2: FlexColumnWidth(),
                    },
                    children: <TableRow>[
                      TableRow(
                        children: <Widget>[
                          Text(
                            S.of(context).transactionTypeDeposit,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge!.copyWith(fontWeight: .bold),
                          ),
                          Text(
                            S.of(context).transactionTypeWithdrawal,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge!.copyWith(fontWeight: .bold),
                          ),
                          Text(
                            S.of(context).transactionTypeTransfer,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge!.copyWith(fontWeight: .bold),
                          ),
                        ],
                      ),

                      TableRow(
                        children: <Widget>[
                          Text(
                            defaultCurrency.fmt(_txSum.deposits),
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(
                                  color: FtColors.incomeOf(context),
                                  fontWeight: .bold,
                                  fontFeatures: const <FontFeature>[
                                    .tabularFigures(),
                                  ],
                                ),
                          ),
                          Text(
                            defaultCurrency.fmt(_txSum.withdrawals),
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(
                                  color: FtColors.coralOf(context),
                                  fontWeight: .bold,
                                  fontFeatures: const <FontFeature>[
                                    .tabularFigures(),
                                  ],
                                ),
                          ),
                          Text(
                            defaultCurrency.fmt(_txSum.transfers),
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(
                                  color: FtColors.blueOf(context),
                                  fontWeight: .bold,
                                  fontFeatures: const <FontFeature>[
                                    .tabularFigures(),
                                  ],
                                ),
                          ),
                        ],
                      ),
                      const TableRow(
                        children: <Widget>[
                          SizedBox(height: 8),
                          SizedBox.shrink(),
                          SizedBox.shrink(),
                        ],
                      ),
                      TableRow(
                        children: <Widget>[
                          const SizedBox.shrink(),
                          Align(
                            alignment: .centerRight,
                            child: Text(
                              "${S.of(context).generalSum}:  ",
                              style: Theme.of(context).textTheme.bodyLarge!
                                  .copyWith(fontWeight: .bold),
                            ),
                          ),
                          Text(
                            defaultCurrency.fmt(_txSum.total),
                            style: Theme.of(context).textTheme.bodyLarge!
                                .copyWith(
                                  color: _txSum.total < 0
                                      ? FtColors.coralOf(context)
                                      : FtColors.incomeOf(context),
                                  fontWeight: .bold,
                                  fontFeatures: const <FontFeature>[
                                    .tabularFigures(),
                                  ],
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Padding for FAB
                  const SizedBox(height: 76),
                ],
              ),
            );
          },
        ),
      ),
      //itemExtent: 80,
    );

    // En la pestaña principal o con filtro de cuenta o presupuesto mostramos la tarjeta de saldo
    // y las pestañas Todos/Gastos/Ingresos/Traspasos al estilo Fintonic sobre la lista.
    if (widget.filters == null ||
        _filters.account != null ||
        _filters.budget != null ||
        widget.filters?.account != null ||
        widget.filters?.budget != null) {
      final ({double accountsBalance, double expense, double income})?
      initialSummary;
      if (_filters.account != null) {
        final double? knownBal =
            _accountBalances[_filters.account!.id] ??
            double.tryParse(_filters.account!.attributes.currentBalance ?? '');
        initialSummary = knownBal != null
            ? (income: 0.0, expense: 0.0, accountsBalance: knownBal)
            : null;
      } else {
        initialSummary = _cachedSummary;
      }

      String filterTitle = "Saldo neto";
      final List<String> activeFilterNames = <String>[];
      if (_filters.account != null) {
        activeFilterNames.add(_filters.account!.attributes.name);
      }
      if (_filters.budget != null) {
        activeFilterNames.add(
          'Presupuesto: ${_filters.budget!.attributes.name}',
        );
      }
      if (_filters.category != null) {
        activeFilterNames.add(
          'Categoría: ${_filters.category!.attributes.name}',
        );
      }
      if (_filters.start != null || _filters.end != null) {
        final DateTime s = _filters.start ?? DateTime.now();
        activeFilterNames.add(DateFormat('MMMM yyyy', 'es_ES').format(s));
      }
      if (activeFilterNames.isNotEmpty) {
        filterTitle = activeFilterNames.join(' · ');
      }

      return Column(
        children: <Widget>[
          _BalanceHeader(
            summaryFuture: _summaryFuture,
            initialData: initialSummary,
            filterTitle: filterTitle,
            hasActiveFilter: activeFilterNames.isNotEmpty,
            onClearFilter:
                (widget.filters == null && activeFilterNames.isNotEmpty)
                ? clearAllFilters
                : null,
          ),
          SegmentedTabs(selected: _segment, onChanged: _onSegmentChanged),
          if (_isRefreshing)
            LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              color: Theme.of(context).colorScheme.primary,
            ),
          Expanded(child: list),
        ],
      );
    }
    if (_isRefreshing) {
      return Column(
        children: <Widget>[
          LinearProgressIndicator(
            minHeight: 2.5,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            color: Theme.of(context).colorScheme.primary,
          ),
          Expanded(child: list),
        ],
      );
    }
    return list;
  }

  Widget transactionRowBuilder(
    BuildContext context,
    TransactionRead item,
    int index,
  ) {
    final List<TransactionSplit> transactions = item.attributes.transactions;
    if (transactions.isEmpty) {
      return Text(S.of(context).homeTransactionsEmpty);
    }
    String category = "";
    final Set<String> categories = <String>{};
    String notes = "";
    bool hasAttachments = false;
    double amount = 0.0;
    final Map<String, double> foreignAmounts = <String, double>{};
    final Map<String, CurrencyRead> foreignCurrencies =
        <String, CurrencyRead>{};
    String foreignText = "";
    String sourceName = "";
    String destinationName = "";
    List<String> tags = <String>[];
    late bool reconciled;
    for (TransactionSplit trans in transactions) {
      if (trans.categoryName?.isNotEmpty ?? false) {
        categories.add(trans.categoryName!);
        if (category.isEmpty) {
          category = trans.categoryName!;
        }
      }
      if (trans.notes?.isNotEmpty ?? false) {
        if (notes.isNotEmpty) {
          notes += "\n";
        }
        notes += trans.notes!.trim();
      }
      if (trans.hasAttachments ?? false) {
        hasAttachments = true;
      }
      if (trans.tags?.isNotEmpty ?? false) {
        tags = trans.tags!;
      }
      amount += double.parse(trans.amount);
      if (trans.foreignAmount?.isNotEmpty ?? false) {
        final double foreignAmount = double.parse(trans.foreignAmount!);
        final String foreignSymbol =
            trans.foreignCurrencySymbol ?? trans.foreignCurrencyCode ?? "";
        if (foreignAmount != 0 && foreignSymbol.isNotEmpty) {
          foreignAmounts[foreignSymbol] =
              (foreignAmounts[foreignSymbol] ?? 0) + foreignAmount;
          foreignCurrencies[foreignSymbol] = CurrencyRead(
            id: trans.foreignCurrencyId ?? "0",
            type: "currencies",
            attributes: CurrencyProperties(
              code: trans.foreignCurrencyCode ?? "",
              name: "",
              symbol: trans.foreignCurrencySymbol ?? "",
              decimalPlaces: trans.foreignCurrencyDecimalPlaces,
            ),
          );
        }
      }
      if (sourceName == "") {
        sourceName = trans.sourceName!;
      } else if (sourceName != trans.sourceName!) {
        sourceName = S.of(context).generalMultiple;
      }
      if (destinationName == "") {
        destinationName = trans.destinationName!;
      } else if (destinationName != trans.destinationName!) {
        destinationName = S.of(context).generalMultiple;
      }
    }
    if (categories.length > 1) {
      category = S
          .of(context)
          .homeTransactionsMultipleCategories(categories.length);
    }

    // Title
    late String title;
    if (item.attributes.groupTitle?.isNotEmpty ?? false) {
      title = item.attributes.groupTitle!;
    } else {
      title = transactions.first.description;
    }
    // Subtitle
    final List<InlineSpan> subtitle = <InlineSpan>[];
    if (hasAttachments) {
      subtitle.add(
        const WidgetSpan(
          baseline: .ideographic,
          alignment: .middle,
          child: Padding(
            padding: .only(right: 2),
            child: Icon(Icons.attachment),
          ),
        ),
      );
    }
    if (transactions.first.type == .transfer) {
      subtitle.add(
        TextSpan(text: "(${S.of(context).transactionTypeTransfer})"),
      );
      subtitle.add(
        const WidgetSpan(
          baseline: .ideographic,
          alignment: .middle,
          child: Padding(
            padding: .only(right: 2),
            child: Icon(Icons.arrow_right_alt),
          ),
        ),
      );
    }
    subtitle.add(
      TextSpan(
        text:
            (transactions.first.type == .withdrawal ||
                transactions.first.type == .transfer)
            ? destinationName
            : sourceName,
      ),
    );
    subtitle.add(const TextSpan(text: "\n"));
    if (category.isNotEmpty) {
      subtitle.add(
        TextSpan(
          text: category,
          style: const TextStyle(fontStyle: .italic),
        ),
      );
    }
    if (notes.isNotEmpty) {
      subtitle.add(
        TextSpan(
          text: "\n$notes",
          style: const TextStyle(fontStyle: .italic),
        ),
      );
    }

    reconciled = transactions.first.reconciled ?? false;
    final CurrencyRead currency = CurrencyRead(
      id: transactions.first.currencyId ?? "0",
      type: "currencies",
      attributes: CurrencyProperties(
        code: transactions.first.currencyCode ?? "",
        name: transactions.first.currencyName ?? "",
        symbol: transactions.first.currencySymbol ?? "",
        decimalPlaces: transactions.first.currencyDecimalPlaces,
      ),
    );
    if (foreignAmounts.isNotEmpty) {
      foreignAmounts.forEach((String cur, double amount) {
        if (foreignCurrencies.containsKey(cur)) {
          foreignText += "${foreignCurrencies[cur]!.fmt(amount)} ";
        }
      });
      foreignText += " ";
    }

    // Account balance
    double? balance;
    final TransactionSplit firstTx = item.attributes.transactions.first;
    if (_filters.account != null) {
      if (firstTx.sourceBalanceAfter != null ||
          firstTx.destinationBalanceAfter != null) {
        final String? balStr = firstTx.destinationId == _filters.account?.id
            ? (firstTx.destinationBalanceAfter ?? firstTx.sourceBalanceAfter)
            : (firstTx.sourceBalanceAfter ?? firstTx.destinationBalanceAfter);
        balance = double.tryParse(balStr ?? '') ?? 0;
        if (_filters.account!.attributes.type !=
                ShortAccountTypeProperty.asset &&
            balance != 0) {
          balance *= -1;
        }
      } else {
        balance = _runningBalancesByTransactionId[item.id] ?? 0;
      }
    } else {
      final String? serverBal = switch (firstTx.type) {
        TransactionTypeProperty.deposit =>
          firstTx.destinationBalanceAfter ?? firstTx.sourceBalanceAfter,
        TransactionTypeProperty.withdrawal =>
          firstTx.sourceBalanceAfter ?? firstTx.destinationBalanceAfter,
        _ => firstTx.sourceBalanceAfter ?? firstTx.destinationBalanceAfter,
      };
      if (serverBal != null && serverBal.isNotEmpty) {
        balance = double.tryParse(serverBal);
      }
      balance ??= _runningBalancesByTransactionId[item.id];
    }

    Widget transactionWidget = OpenContainer(
      openBuilder: (BuildContext context, Function closedContainer) =>
          TransactionConsultPage(transaction: item),
      openColor: Theme.of(context).cardColor,
      closedColor: Theme.of(context).cardColor,
      closedShape: const RoundedRectangleBorder(
        borderRadius: .only(topLeft: .circular(16), bottomLeft: .circular(16)),
      ),
      closedElevation: 0,
      closedBuilder: (BuildContext context, Function openContainer) =>
          GestureDetector(
            onLongPressStart: (LongPressStartDetails details) async {
              final Size screenSize = MediaQuery.of(context).size;
              final Offset offset = details.globalPosition;
              unawaited(HapticFeedback.vibrate());
              final Function? func = await showMenu<Function>(
                context: context,
                position: .fromLTRB(
                  offset.dx,
                  offset.dy,
                  screenSize.width - offset.dx,
                  screenSize.height - offset.dy,
                ),
                items: <PopupMenuEntry<Function>>[
                  PopupMenuItem<Function>(
                    value: () async {
                      final bool? ok = await Navigator.push(
                        context,
                        MaterialPageRoute<bool>(
                          builder: (BuildContext context) =>
                              TransactionPage(transaction: item, clone: true),
                        ),
                      );
                      if (ok ?? false) {
                        _rowsWithDate.clear();
                        _lastDate = null;
                        _txSum = TransactionSum();
                        _txSumUsed.clear();
                        if (context.mounted) {
                          context.read<FireflyService>().transStock!.clear();
                        }
                      }
                      setState(() {
                        _lastCalculatedBalance = null;
                        _lastCalculatedBalanceByAccount.clear();
                        _pagingState = _resetPaging();
                      });
                    },
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.copy),
                        const SizedBox(width: 12),
                        Text(S.of(context).transactionDuplicate),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<Function>(
                    value: () async {
                      final FireflyIii api = context.read<FireflyService>().api;
                      final bool? ok = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) =>
                            const DeletionConfirmDialog(),
                      );
                      if (!(ok ?? false)) {
                        return;
                      }

                      await api.v1TransactionsIdDelete(id: item.id);
                      _rowsWithDate.clear();
                      _lastDate = null;
                      _txSum = TransactionSum();
                      _txSumUsed.clear();
                      if (context.mounted) {
                        context.read<FireflyService>().transStock!.clear();
                      }
                      setState(() {
                        _lastCalculatedBalance = null;
                        _lastCalculatedBalanceByAccount.clear();
                        _pagingState = _resetPaging();
                      });
                    },
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.delete),
                        const SizedBox(width: 12),
                        Text(
                          MaterialLocalizations.of(context).deleteButtonTooltip,
                        ),
                      ],
                    ),
                  ),
                ],
                clipBehavior: .hardEdge,
              );
              if (func == null) {
                return;
              }
              func();
            },
            child: ListTile(
              leading: Builder(
                builder: (BuildContext context) {
                  final bool isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  final bool hasCategory = category.isNotEmpty;
                  final Color tint = hasCategory
                      ? FtColors.categoryColor(category, isDark: isDark)
                      : transactions.first.type.color;
                  final IconData icon = hasCategory
                      ? FtCategoryIcon.forName(category)
                      : transactions.first.type.icon;
                  return FtCategoryIconWidget(
                    icon: icon,
                    color: tint,
                    size: 24,
                    padding: 10,
                  );
                },
              ),
              title: Row(
                crossAxisAlignment: .start,
                children: <Widget>[
                  // Front part
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        if (transactions.length > 1) ...<Widget>[
                          Icon(
                            Icons.call_split,
                            size: 14,
                            color: FtColors.blueOf(context),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(title, maxLines: 1, overflow: .ellipsis),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Trailing part
                  RichText(
                    textAlign: .end,
                    maxLines: 1,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: <InlineSpan>[
                        if (foreignText.isNotEmpty)
                          TextSpan(
                            text: foreignText,
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  fontFeatures: const <FontFeature>[
                                    .tabularFigures(),
                                  ],
                                ),
                          ),
                        TextSpan(
                          text: currency.fmt(amount, context: context),
                          style: Theme.of(context).textTheme.titleMedium!
                              .copyWith(
                                fontWeight: FontWeight.w700,
                                color: switch (transactions.first.type) {
                                  .deposit => FtColors.incomeOf(context),
                                  .withdrawal => Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  .reconciliation =>
                                    transactions.first.sourceType ==
                                            .reconciliationAccount
                                        ? FtColors.incomeOf(context)
                                        : FtColors.coralOf(context),
                                  _ => transactions.first.type.colorOf(context),
                                },
                                fontFeatures: const <FontFeature>[
                                  .tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              subtitle: Row(
                crossAxisAlignment: .start,
                children: <Widget>[
                  // Front part
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: <Widget>[
                        RichText(
                          overflow: .ellipsis,
                          maxLines: 2,
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodyMedium,
                            children: subtitle,
                          ),
                        ),
                        if (!context.watch<SettingsProvider>().hideTags &&
                            tags.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: tags
                                .map(
                                  (String tag) => Container(
                                    padding: const .symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHigh,
                                      borderRadius: .circular(6),
                                    ),
                                    child: Text(
                                      tag,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall!
                                          .copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Trailing part: nombre de la cuenta y saldo corriente debajo
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      RichText(
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: <InlineSpan>[
                            if (reconciled)
                              const WidgetSpan(
                                baseline: TextBaseline.ideographic,
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: EdgeInsets.only(right: 2),
                                  child: Icon(Icons.check, size: 14),
                                ),
                              ),
                            if (_filters.account != null)
                              TextSpan(
                                text: currency.fmt(
                                  balance ?? 0,
                                  context: context,
                                ),
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(
                                      fontFeatures: const <FontFeature>[
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            if (_filters.account == null)
                              TextSpan(
                                text: switch (transactions.first.type) {
                                  TransactionTypeProperty.deposit =>
                                    destinationName,
                                  TransactionTypeProperty.openingBalance => "",
                                  TransactionTypeProperty.reconciliation => "",
                                  _ => sourceName,
                                },
                              ),
                          ],
                        ),
                      ),
                      if (_filters.account == null &&
                          balance != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          currency.fmt(balance, context: context),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontFeatures: const <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: .only(
                  topLeft: .circular(16),
                  bottomLeft: .circular(16),
                ),
              ),
            ),
          ),
      onClosed: (bool? refresh) async {
        if (_filters.account != null) {
          // Reset last balance calculated
          final FireflyIii api = context.read<FireflyService>().api;
          // Retrieve the account to get the current balance
          final Response<AccountSingle> respAccount = await api.v1AccountsIdGet(
            id: _filters.account!.id,
          );
          apiThrowErrorIfEmpty(respAccount, mounted ? context : null);
          final AccountRead account = respAccount.body!.data;
          _lastCalculatedBalance =
              double.tryParse(account.attributes.currentBalance!) ?? 0.0;
          // If the account is a revenue/expense account, we need to invert the balance
          if (_isRevenueOrExpense(account.attributes.type)) {
            _lastCalculatedBalance = _lastCalculatedBalance != null
                ? _lastCalculatedBalance! * -1
                : 0;
          }
        }

        if (refresh ?? false == true) {
          _rowsWithDate.clear();
          _lastDate = null;
          _txSum = TransactionSum();
          _txSumUsed.clear();
          if (context.mounted) {
            context.read<FireflyService>().transStock!.clear();
          }
        }
        setState(() {
          _lastCalculatedBalance = null;
          _lastCalculatedBalanceByAccount.clear();
          _pagingState = _resetPaging();
        });
      },
    );

    // Date
    final DateTime date = _tzHandler.sTime(transactions.first.date).toLocal();
    // Show Date Banner when:
    // 1. _lastDate is not set (= first element)
    // 2. _lastDate has a different day than current date (= date changed) and
    //    is an earlier date (= scrolling down)
    // 3. index indicates we have to.
    if (_lastDate == null ||
        (_lastDate!.clearTime() != date.clearTime() &&
            date.clearTime().isBefore(_lastDate!.clearTime())) ||
        _rowsWithDate.contains(index)) {
      // Add date row
      _rowsWithDate.add(index);
      transactionWidget = Column(
        crossAxisAlignment: .start,
        children: <Widget>[
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            padding: const .fromLTRB(16, 8, 16, 8),
            child: Text(
              DateFormat.yMMMMEEEEd().format(date).toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          transactionWidget,
        ],
      );
      _lastDate = date;
    }

    return transactionWidget;
  }
}

/// Tarjeta superior con el saldo actual de las cuentas y resumen del mes (estilo Fintonic).
class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({
    required this.summaryFuture,
    this.initialData,
    this.filterTitle,
    this.hasActiveFilter = false,
    this.onClearFilter,
  });

  final Future<({double income, double expense, double accountsBalance})>?
  summaryFuture;
  final ({double income, double expense, double accountsBalance})? initialData;
  final String? filterTitle;
  final bool hasActiveFilter;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child:
              FutureBuilder<
                ({double income, double expense, double accountsBalance})
              >(
                future: summaryFuture,
                initialData: initialData,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<
                        ({
                          double income,
                          double expense,
                          double accountsBalance,
                        })
                      >
                      snapshot,
                    ) {
                      final ({
                        double income,
                        double expense,
                        double accountsBalance,
                      })?
                      data = snapshot.data ?? initialData;
                      final bool ready = data != null;
                      final double income = data?.income ?? 0;
                      final double expense = data?.expense ?? 0;
                      final double net = income - expense;
                      final double accountsBalance = data?.accountsBalance ?? 0;
                      return Column(
                        children: <Widget>[
                          Text(
                            ready
                                ? currency.fmt(
                                    accountsBalance,
                                    context: context,
                                  )
                                : "—",
                            style: Theme.of(context).textTheme.headlineMedium!
                                .copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  filterTitle ?? "Saldo neto",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall!
                                      .copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              if (hasActiveFilter &&
                                  onClearFilter != null) ...<Widget>[
                                const SizedBox(width: 4),
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: onClearFilter,
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              Expanded(
                                child: _miniStat(
                                  context,
                                  "Ingresos",
                                  income,
                                  FtColors.income,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 26,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              Expanded(
                                child: _miniStat(
                                  context,
                                  "Gastos",
                                  -expense,
                                  Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 26,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              Expanded(
                                child: _miniStat(
                                  context,
                                  "Saldo neto",
                                  net,
                                  net >= 0 ? FtColors.income : FtColors.coral,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
              ),
        ),
      ),
    );
  }

  Widget _miniStat(
    BuildContext context,
    String label,
    double amount,
    Color color,
  ) {
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    return Column(
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            currency.fmt(amount, context: context),
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// Pestañas Todos / Gastos / Ingresos / Traspasos al estilo Fintonic.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final int selected;
  final ValueChanged<int> onChanged;

  static const List<String> _labels = <String>[
    "Todos",
    "Gastos",
    "Ingresos",
    "Traspasos",
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < _labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: <Widget>[
                      Text(
                        _labels[i],
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          fontWeight: selected == i
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected == i
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 2.5,
                        width: 36,
                        decoration: BoxDecoration(
                          color: selected == i
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

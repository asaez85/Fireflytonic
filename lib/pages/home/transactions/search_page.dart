import 'dart:async';

import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/home/transactions/filter.dart';
import 'package:waterflyiii/pages/home/transactions/widgets/accounts_filter_sheet.dart';
import 'package:waterflyiii/pages/home/transactions/widgets/amount_filter_sheet.dart';
import 'package:waterflyiii/pages/home/transactions/widgets/budget_filter_sheet.dart';
import 'package:waterflyiii/pages/home/transactions/widgets/categories_filter_sheet.dart';
import 'package:waterflyiii/pages/home/transactions/widgets/date_filter_sheet.dart';
import 'package:waterflyiii/pages/transaction/category_select.dart';
import 'package:waterflyiii/pages/transaction_consult.dart';
import 'package:waterflyiii/stock.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';

class TransactionsSearchPage extends StatefulWidget {
  final TransactionFilters? initialFilters;

  const TransactionsSearchPage({super.key, this.initialFilters});

  @override
  State<TransactionsSearchPage> createState() => _TransactionsSearchPageState();
}

class _TransactionsSearchPageState extends State<TransactionsSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // Filter state
  DateTime? _startDate;
  DateTime? _endDate;
  String _dateLabel = "Fecha";
  List<CategoryRead> _selectedCategories = <CategoryRead>[];
  List<AccountRead> _selectedAccounts = <AccountRead>[];
  BudgetRead? _selectedBudget;
  double? _minAmount;
  double? _maxAmount;

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _startDate != null ||
      _endDate != null ||
      _selectedCategories.isNotEmpty ||
      _selectedAccounts.isNotEmpty ||
      _selectedBudget != null ||
      _minAmount != null ||
      _maxAmount != null;

  void _clearFilters() {
    _debounceTimer?.cancel();
    setState(() {
      _searchController.clear();
      _startDate = null;
      _endDate = null;
      _dateLabel = "Fecha";
      _selectedCategories = <CategoryRead>[];
      _selectedAccounts = <AccountRead>[];
      _selectedBudget = null;
      _minAmount = null;
      _maxAmount = null;
    });
    if (widget.initialFilters != null) {
      widget.initialFilters!.reset();
    }
    unawaited(_fetchResults());
  }

  // Results state
  bool _isLoading = false;
  String? _error;
  List<TransactionRead> _results = <TransactionRead>[];
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilters != null) {
      final TransactionFilters f = widget.initialFilters!;
      if (f.text?.isNotEmpty ?? false) {
        _searchController.text = f.text!;
      }
      _startDate = f.start;
      _endDate = f.end;
      if (f.start != null || f.end != null) {
        _dateLabel = "Personalizado";
      }
      if (f.categories.isNotEmpty) {
        _selectedCategories = List<CategoryRead>.from(f.categories);
      } else if (f.category != null) {
        _selectedCategories = <CategoryRead>[f.category!];
      }
      if (f.accounts.isNotEmpty) {
        _selectedAccounts = List<AccountRead>.from(f.accounts);
      } else if (f.account != null) {
        _selectedAccounts = <AccountRead>[f.account!];
      }
      _selectedBudget = f.budget;
      _minAmount = f.minAmount;
      _maxAmount = f.maxAmount;
    }

    _fetchResults();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _fetchResults();
    });
  }

  Future<void> _fetchResults() async {
    final int generation = ++_searchGeneration;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final TransStock? stock = context.read<FireflyService>().transStock;
      if (stock == null) {
        throw Exception("TransStock unavailable");
      }

      final String queryText = _searchController.text.trim();
      String query = queryText;

      if (_selectedAccounts.isNotEmpty) {
        final String accountIds = _selectedAccounts
            .map((AccountRead a) => a.id)
            .join(",");
        query = "account_id:$accountIds $query";
      }

      if (_selectedCategories.length == 1) {
        query =
            "category_is:\"${_selectedCategories.first.attributes.name}\" $query";
      }

      if (_startDate != null) {
        query =
            "date_after:${DateFormat('yyyy-MM-dd', 'en_US').format(_startDate!)} $query";
      }
      if (_endDate != null) {
        query =
            "date_before:${DateFormat('yyyy-MM-dd', 'en_US').format(_endDate!)} $query";
      }

      if (_selectedBudget != null) {
        query = (_selectedBudget!.id == "-1")
            ? "budget_is:\"\" $query"
            : "budget_is:\"${_selectedBudget!.attributes.name}\" $query";
      }

      if (_minAmount != null) {
        query = "more:${_formatAmount(_minAmount!)} $query";
      }
      if (_maxAmount != null) {
        query = "less:${_formatAmount(_maxAmount!)} $query";
      }

      query = query.trim();

      late List<TransactionRead> transactions;
      if (query.isNotEmpty) {
        final TransStockRead resp = await stock.getSearch(
          query: query,
          page: 1,
          limit: 100,
        );
        transactions = resp.data;
      } else {
        final TransStockRead resp = await stock.get(page: 1, limit: 100);
        transactions = resp.data;
      }

      // If multiple categories were selected, filter locally
      if (_selectedCategories.length > 1) {
        final Set<String> catNames = _selectedCategories
            .map((CategoryRead c) => c.attributes.name.toLowerCase())
            .toSet();
        transactions = transactions.where((TransactionRead tx) {
          return tx.attributes.transactions.any(
            (TransactionSplit s) =>
                catNames.contains(s.categoryName?.toLowerCase()),
          );
        }).toList();
      }

      if (!mounted || generation != _searchGeneration) return;

      setState(() {
        _results = transactions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _syncAndPop() {
    if (widget.initialFilters != null) {
      final TransactionFilters f = widget.initialFilters!;
      f.text = _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim();
      f.start = _startDate;
      f.end = _endDate;
      f.categories = List<CategoryRead>.from(_selectedCategories);
      f.category = _selectedCategories.length == 1
          ? _selectedCategories.first
          : null;
      f.accounts = List<AccountRead>.from(_selectedAccounts);
      f.account = _selectedAccounts.length == 1
          ? _selectedAccounts.first
          : null;
      f.budget = _selectedBudget;
      f.minAmount = _minAmount;
      f.maxAmount = _maxAmount;
      f.updateFilters();
    }
    Navigator.pop(context, true);
  }

  Map<DateTime, List<TransactionRead>> _groupTransactionsByDate(
    List<TransactionRead> txs,
  ) {
    final Map<DateTime, List<TransactionRead>> groups =
        <DateTime, List<TransactionRead>>{};
    for (TransactionRead item in txs) {
      if (item.attributes.transactions.isEmpty) continue;
      final DateTime date = item.attributes.transactions.first.date.toLocal();
      final DateTime dayKey = DateTime(date.year, date.month, date.day);
      groups.putIfAbsent(dayKey, () => <TransactionRead>[]).add(item);
    }
    return groups;
  }

  String _formatAmount(double value) {
    final String s = value.toStringAsFixed(2);
    if (s.endsWith('.00')) {
      return s.substring(0, s.length - 3);
    }
    if (s.contains('.') && s.endsWith('0')) {
      return s.substring(0, s.length - 1);
    }
    return s;
  }

  String _amountPillLabel() {
    if (_minAmount == null && _maxAmount == null) {
      return "Importe";
    }
    if (_minAmount != null && _maxAmount != null) {
      return "${_formatAmount(_minAmount!)} € - ${_formatAmount(_maxAmount!)} €";
    }
    if (_minAmount != null) {
      return "Desde ${_formatAmount(_minAmount!)} €";
    }
    return "Hasta ${_formatAmount(_maxAmount!)} €";
  }

  String _formatDateHeader(DateTime date) {
    try {
      final DateFormat fmt = DateFormat('EEEE d MMM yyyy', 'es_ES');
      return fmt.format(date).toUpperCase();
    } catch (_) {
      return DateFormat('yyyy-MM-dd').format(date);
    }
  }

  Future<void> _recategorize(TransactionRead item) async {
    final String currentCat =
        item.attributes.transactions.first.categoryName ?? "";
    final String? newCat = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (BuildContext context) =>
            CategorySelectPage(selectedCategoryName: currentCat),
      ),
    );

    if (newCat != null && newCat != currentCat && mounted) {
      try {
        final FireflyIii api = context.read<FireflyService>().api;
        final List<TransactionSplitUpdate> splits = <TransactionSplitUpdate>[];
        for (int i = 0; i < item.attributes.transactions.length; i++) {
          final TransactionSplit s = item.attributes.transactions[i];
          splits.add(
            TransactionSplitUpdate(
              amount: s.amount,
              description: s.description,
              categoryName: newCat,
              date: s.date,
              type: s.type,
              sourceId: s.sourceId,
              destinationId: s.destinationId,
              notes: s.notes,
              order: i,
              transactionJournalId: s.transactionJournalId,
            ),
          );
        }

        final Response<TransactionSingle> resp = await api.v1TransactionsIdPut(
          id: item.id,
          body: TransactionUpdate(
            groupTitle: item.attributes.groupTitle,
            transactions: splits,
          ),
        );

        if (resp.isSuccessful && mounted) {
          unawaited(_fetchResults());
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _syncAndPop();
      },
      child: Scaffold(
        backgroundColor: isDark ? FtColors.bgDark : const Color(0xFFF7F9FC),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              // Top Search Bar Header
              Padding(
                padding: const EdgeInsets.only(
                  left: 4,
                  right: 16,
                  top: 8,
                  bottom: 6,
                ),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: isDark ? Colors.white : FtColors.navy,
                      onPressed: _syncAndPop,
                    ),
                    Expanded(
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: isDark
                              ? FtColors.sectionHeaderDark
                              : const Color(0xFFEDF2F8),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: "Buscar movimientos",
                            hintStyle: TextStyle(
                              color: isDark
                                  ? FtColors.textMutedDark
                                  : FtColors.textMuted,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                      });
                                      _fetchResults();
                                    },
                                  )
                                : Icon(
                                    Icons.search,
                                    color: FtColors.blueOf(context),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    if (_hasActiveFilters) ...<Widget>[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        tooltip: "Quitar filtros",
                        color: FtColors.coralOf(context),
                        onPressed: _clearFilters,
                      ),
                    ],
                  ],
                ),
              ),

              // Filter Pills Row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      if (_hasActiveFilters) ...<Widget>[
                        _buildClearFiltersPill(context),
                        const SizedBox(width: 8),
                      ],
                      // Pill: Fecha
                      _buildFilterPill(
                        context,
                        label: _dateLabel,
                        isActive: _dateLabel != "Fecha",
                        onTap: () async {
                          final DateFilterResult? res =
                              await DateFilterSheet.show(
                                context,
                                currentLabel: _dateLabel,
                                currentStart: _startDate,
                                currentEnd: _endDate,
                              );
                          if (res != null) {
                            setState(() {
                              _startDate = res.start;
                              _endDate = res.end;
                              _dateLabel = res.label;
                            });
                            unawaited(_fetchResults());
                          }
                        },
                      ),
                      const SizedBox(width: 8),

                      // Pill: Importe
                      _buildFilterPill(
                        context,
                        label: _amountPillLabel(),
                        isActive: _minAmount != null || _maxAmount != null,
                        onTap: () async {
                          final AmountFilterResult? res =
                              await AmountFilterSheet.show(
                                context,
                                initialMin: _minAmount,
                                initialMax: _maxAmount,
                              );
                          if (res != null) {
                            setState(() {
                              _minAmount = res.minAmount;
                              _maxAmount = res.maxAmount;
                            });
                            unawaited(_fetchResults());
                          }
                        },
                      ),
                      const SizedBox(width: 8),

                      // Pill: Categorías
                      _buildFilterPill(
                        context,
                        label: _selectedCategories.isEmpty
                            ? "Categorías"
                            : "Categorías (${_selectedCategories.length})",
                        isActive: _selectedCategories.isNotEmpty,
                        onTap: () async {
                          final List<CategoryRead>? res =
                              await CategoriesFilterSheet.show(
                                context,
                                initialSelected: _selectedCategories,
                              );
                          if (res != null) {
                            setState(() {
                              _selectedCategories = res;
                            });
                            unawaited(_fetchResults());
                          }
                        },
                      ),
                      const SizedBox(width: 8),

                      // Pill: Cuentas y tarjetas
                      _buildFilterPill(
                        context,
                        label: _selectedAccounts.isEmpty
                            ? "Cuentas y tarjetas"
                            : "Cuentas (${_selectedAccounts.length})",
                        isActive: _selectedAccounts.isNotEmpty,
                        onTap: () async {
                          final List<AccountRead>? res =
                              await AccountsFilterSheet.show(
                                context,
                                initialSelected: _selectedAccounts,
                              );
                          if (res != null) {
                            setState(() {
                              _selectedAccounts = res;
                            });
                            unawaited(_fetchResults());
                          }
                        },
                      ),
                      const SizedBox(width: 8),

                      // Pill: Presupuesto
                      _buildFilterPill(
                        context,
                        label: _selectedBudget == null
                            ? "Presupuesto"
                            : "Presupuesto: ${_selectedBudget!.attributes.name}",
                        isActive: _selectedBudget != null,
                        onTap: () async {
                          final BudgetFilterResult? res =
                              await BudgetFilterSheet.show(
                                context,
                                initialSelected: _selectedBudget,
                              );
                          if (res != null) {
                            setState(() {
                              _selectedBudget = res.budget;
                            });
                            unawaited(_fetchResults());
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1, thickness: 1),

              // Results List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Error al cargar movimientos",
                              style: TextStyle(
                                color: isDark
                                    ? FtColors.textMutedDark
                                    : FtColors.textMuted,
                              ),
                            ),
                            TextButton(
                              onPressed: _fetchResults,
                              child: const Text("Reintentar"),
                            ),
                          ],
                        ),
                      )
                    : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.search_off,
                              size: 52,
                              color: isDark
                                  ? FtColors.textMutedDark
                                  : FtColors.textMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "No se encontraron movimientos",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : FtColors.navy,
                              ),
                            ),
                            if (_hasActiveFilters) ...<Widget>[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _clearFilters,
                                icon: const Icon(
                                  Icons.filter_alt_off_outlined,
                                  size: 18,
                                ),
                                label: const Text("Quitar filtros"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: FtColors.coralOf(context),
                                  side: BorderSide(
                                    color: FtColors.coralOf(
                                      context,
                                    ).withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : _buildGroupedList(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClearFiltersPill(BuildContext context) {
    final Color coral = FtColors.coralOf(context);

    return InkWell(
      onTap: _clearFilters,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: coral.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: coral.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.filter_alt_off_outlined, size: 15, color: coral),
            const SizedBox(width: 6),
            Text(
              "Quitar filtros",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: coral,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(
    BuildContext context, {
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color blue = FtColors.blueOf(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? blue.withValues(alpha: 0.08)
              : (isDark ? FtColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? blue
                : (isDark ? FtColors.borderDark : const Color(0xFFD4DCE8)),
            width: isActive ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? blue
                    : (isDark ? Colors.white70 : FtColors.navy),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: isActive
                  ? blue
                  : (isDark ? FtColors.textMutedDark : FtColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList(BuildContext context) {
    final Map<DateTime, List<TransactionRead>> groups =
        _groupTransactionsByDate(_results);
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final CurrencyRead defaultCurrency = context
        .read<FireflyService>()
        .defaultCurrency;

    return ListView.builder(
      itemCount: groups.keys.length,
      itemBuilder: (BuildContext context, int groupIndex) {
        final DateTime date = groups.keys.elementAt(groupIndex);
        final List<TransactionRead> txList = groups[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Date Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: isDark
                  ? FtColors.sectionHeaderDark.withValues(alpha: 0.6)
                  : const Color(0xFFEDF2F8),
              child: Text(
                _formatDateHeader(date),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark
                      ? FtColors.textMutedDark
                      : const Color(0xFF5A6B84),
                ),
              ),
            ),

            // Movements in this date
            ...txList.map((TransactionRead item) {
              final List<TransactionSplit> splits =
                  item.attributes.transactions;
              final TransactionSplit split = splits.first;
              final bool isSplit = splits.length > 1;

              final String title =
                  item.attributes.groupTitle?.isNotEmpty ?? false
                  ? item.attributes.groupTitle!
                  : split.description;

              final Set<String> categories = splits
                  .map((TransactionSplit s) => s.categoryName ?? "")
                  .where((String c) => c.isNotEmpty)
                  .toSet();
              final String categoryName = categories.length > 1
                  ? "${categories.length} categorías"
                  : (categories.isNotEmpty ? categories.first : "");
              final bool hasCategory = categoryName.isNotEmpty;

              final Color catColor = hasCategory
                  ? FtColors.categoryColor(categoryName, isDark: isDark)
                  : split.type.color;
              final IconData catIcon = hasCategory
                  ? FtCategoryIcon.forName(categoryName)
                  : split.type.icon;

              final double amount = isSplit
                  ? splits.fold(
                      0.0,
                      (double prev, TransactionSplit s) =>
                          prev + (double.tryParse(s.amount) ?? 0.0),
                    )
                  : (double.tryParse(split.amount) ?? 0.0);
              final bool isIncome =
                  split.type == TransactionTypeProperty.deposit;

              final CurrencyRead cur = CurrencyRead(
                id: split.currencyId ?? "0",
                type: "currencies",
                attributes: CurrencyProperties(
                  code: split.currencyCode ?? defaultCurrency.attributes.code,
                  name: split.currencyName ?? defaultCurrency.attributes.name,
                  symbol:
                      split.currencySymbol ?? defaultCurrency.attributes.symbol,
                  decimalPlaces:
                      split.currencyDecimalPlaces ??
                      defaultCurrency.attributes.decimalPlaces,
                ),
              );

              return Material(
                color: isDark ? FtColors.surfaceDark : Colors.white,
                child: InkWell(
                  onTap: () async {
                    final bool? refreshed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute<bool>(
                        builder: (BuildContext context) =>
                            TransactionConsultPage(transaction: item),
                      ),
                    );
                    if ((refreshed ?? false) && context.mounted) {
                      unawaited(_fetchResults());
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? FtColors.borderDark
                              : const Color(0xFFEEF2F6),
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        // Icon
                        FtCategoryIconWidget(
                          icon: catIcon,
                          color: catColor,
                          size: 24,
                          padding: 10,
                        ),
                        const SizedBox(width: 14),

                        // Title & Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  if (isSplit) ...<Widget>[
                                    Icon(
                                      Icons.call_split,
                                      size: 14,
                                      color: FtColors.blueOf(context),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: isDark
                                                ? Colors.white
                                                : FtColors.navy,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              hasCategory
                                  ? Text(
                                      categoryName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? FtColors.textMutedDark
                                            : FtColors.textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : GestureDetector(
                                      onTap: () => _recategorize(item),
                                      child: Text(
                                        "Recategorizar",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: FtColors.blueOf(context),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Amount & Chevron
                        Text(
                          isIncome
                              ? "+${cur.fmt(amount.abs(), context: context)}"
                              : "-${cur.fmt(amount.abs(), context: context)}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isIncome
                                ? FtColors.incomeOf(context)
                                : (isDark ? Colors.white : FtColors.navy),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: FtColors.blueOf(context),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

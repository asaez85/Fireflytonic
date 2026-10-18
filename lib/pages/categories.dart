import 'dart:async';

import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/categories/addedit.dart';
import 'package:waterflyiii/pages/home/analysis_period.dart';
import 'package:waterflyiii/pages/home/category_detail.dart';
import 'package:waterflyiii/pages/navigation.dart';
import 'package:waterflyiii/settings.dart';
import 'package:waterflyiii/stock.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';
import 'package:waterflyiii/widgets/ft_progress_bar.dart';

final Logger log = Logger("Pages.Categories");

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final Logger log = Logger("Pages.Categories.Page");
  late DateTime selectedMonth;
  late DateTime now;
  late CatStock stock;

  CategoryArray? _categories;
  List<CategoryRead>? _allCategories;
  bool _isLoading = true;
  String? _error;
  bool _isSearchOpen = false;
  int _selectedFilterSegment = 0; // 0: Todas, 1: Gastos, 2: Ingresos
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();

    now = context.read<FireflyService>().tzHandler.sNow().setTimeOfDay(
      const TimeOfDay(hour: 12, minute: 0),
    );
    selectedMonth = DateTime(now.year, now.month, 1);

    stock = CatStock(
      context.read<FireflyService>().api,
      context.read<FireflyService>().defaultCurrency,
    );

    _searchController.addListener(() {
      final String q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() {
          _searchQuery = q;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateNavElements();
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isCurrentMonth =>
      selectedMonth.year == now.year && selectedMonth.month == now.month;

  DateTime get _stockDate {
    if (_isCurrentMonth) {
      return selectedMonth.copyWith(day: now.day);
    } else {
      return selectedMonth.copyWith(day: 0, month: selectedMonth.month + 1);
    }
  }

  Future<void> _fetchAllCategories() async {
    try {
      final FireflyIii api = context.read<FireflyService>().api;
      final Response<CategoryArray> resp = await api.v1CategoriesGet(
        page: 1,
        limit: 100,
      );
      if (resp.isSuccessful && resp.body != null) {
        if (mounted) {
          setState(() {
            _allCategories = resp.body!.data;
          });
        }
      }
    } catch (e) {
      log.fine("Error fetching all categories: $e");
    }
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    if (_isLoading && !isRefresh) return;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final DateTime stockDate = _stockDate;
      final CategoryArray updated = await stock.get(stockDate);
      await _fetchAllCategories();
      if (mounted) {
        setState(() {
          _categories = updated;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      log.severe("Error loading categories", e, s);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    if (_isLoading) return;
    await stock.reset();
    await _loadData(isRefresh: true);
  }

  void _previousMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
    });
    _updateNavElements();
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
    });
    _updateNavElements();
    _loadData();
  }

  void _currentMonth() {
    setState(() {
      selectedMonth = DateTime(now.year, now.month, 1);
    });
    _updateNavElements();
    _loadData();
  }

  Future<void> _openAddCategory() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) =>
          const CategoryAddEditDialog(category: null),
    );
    if ((ok ?? false) && mounted) {
      await _handleRefresh();
    }
  }

  void _updateNavElements() {
    if (!mounted) return;
    final NavPageElements nav = context.read<NavPageElements>();

    nav.appBarTitle = Text(S.of(context).navigationCategories);

    nav.appBarActions = <Widget>[
      IconButton(
        icon: Icon(
          _isSearchOpen ? Icons.search_off_outlined : Icons.search_outlined,
        ),
        tooltip: _isSearchOpen ? 'Cerrar búsqueda' : 'Buscar categoría',
        onPressed: () {
          setState(() {
            _isSearchOpen = !_isSearchOpen;
            if (!_isSearchOpen) {
              _searchController.clear();
              _searchQuery = "";
            }
          });
        },
      ),
      IconButton(
        icon: const Icon(Icons.add),
        tooltip: S.of(context).categoryTitleAdd,
        onPressed: _openAddCategory,
      ),
    ];

    nav.fab = FloatingActionButton(
      heroTag: 'categories_add_fab',
      tooltip: S.of(context).categoryTitleAdd,
      onPressed: _openAddCategory,
      child: const Icon(Icons.add),
    );
  }

  @override
  Widget build(BuildContext context) {
    log.fine(() => "build");
    final DateTime stockDate = _stockDate;

    final Widget content;
    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator.adaptive());
    } else if (_error != null) {
      log.severe("Error loading categories: $_error");
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              S.of(context).categoryErrorLoading,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => _loadData(isRefresh: true),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    } else if (_categories != null) {
      content = _buildCategoryList(_categories!, stockDate);
    } else {
      content = const Center(child: CircularProgressIndicator.adaptive());
    }

    return content;
  }

  Widget _buildMonthSelector(BuildContext context) {
    final String monthName = DateFormat(
      'MMMM yyyy',
      'es_ES',
    ).format(selectedMonth);
    final String capitalizedMonth =
        monthName.substring(0, 1).toUpperCase() + monthName.substring(1);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
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

  Widget _buildSummaryCard(
    BuildContext context, {
    required CurrencyRead currency,
    required double totalSpent,
    required double totalEarned,
    required int activeCount,
    required int excludedCount,
  }) {
    final double netBalance = totalSpent + totalEarned;
    final Color netColor = netBalance < 0
        ? FtColors.coralOf(context)
        : (netBalance > 0
              ? FtColors.incomeOf(context)
              : Theme.of(context).colorScheme.onSurface);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'GASTADO',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: FtColors.coralOf(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currency.fmt(totalSpent, context: context),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: FtColors.coralOf(context),
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 38,
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'INGRESADO',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: FtColors.incomeOf(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currency.fmt(totalEarned, context: context),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: FtColors.incomeOf(context),
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
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Balance mensual',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  currency.fmt(netBalance, context: context),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: netColor,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Icon(
                  Icons.category_outlined,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '$activeCount categorías activas',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (excludedCount > 0) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    '•  $excludedCount excluida(s)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FtColors.warningOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(CategoryArray categoryData, DateTime stockDate) {
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;
    final List<String> categoriesSumExcluded = context
        .watch<SettingsProvider>()
        .categoriesSumExcluded;

    // Combinar categorías del mes con catálogo completo si está disponible
    final Map<String, CategoryRead> mergedMap = <String, CategoryRead>{};

    for (final CategoryRead cat in categoryData.data) {
      mergedMap[cat.id] = cat;
    }

    if (_allCategories != null) {
      for (final CategoryRead cat in _allCategories!) {
        if (!mergedMap.containsKey(cat.id)) {
          mergedMap[cat.id] = CategoryRead(
            id: cat.id,
            type: 'categories',
            attributes: CategoryWithSum(
              name: cat.attributes.name,
              spent: <ArrayEntryWithCurrencyAndSum>[],
              earned: <ArrayEntryWithCurrencyAndSum>[],
            ),
          );
        }
      }
    }

    final List<CategoryRead> allCategoriesList = mergedMap.values.toList();

    // Totales calculados solo sobre categorías que computan
    final double totalEarned = allCategoriesList.fold<double>(
      0,
      (double p, CategoryRead e) => p += categoriesSumExcluded.contains(e.id)
          ? 0
          : e.attributes.sumEarned,
    );
    final double totalSpent = allCategoriesList.fold<double>(
      0,
      (double p, CategoryRead e) =>
          p += categoriesSumExcluded.contains(e.id) ? 0 : e.attributes.sumSpent,
    );

    // Filtrado por segmento y búsqueda
    final List<CategoryRead> filtered = allCategoriesList.where((
      CategoryRead cat,
    ) {
      final String name = cat.attributes.name == "L10NNONE"
          ? S.of(context).catNone
          : cat.attributes.name;

      if (_searchQuery.isNotEmpty) {
        if (!name.toLowerCase().contains(_searchQuery)) {
          return false;
        }
      }

      if (_selectedFilterSegment == 1) {
        // Gastos
        return cat.attributes.sumSpent != 0;
      } else if (_selectedFilterSegment == 2) {
        // Ingresos
        return cat.attributes.sumEarned != 0;
      }
      return true;
    }).toList();

    // Ordenar: primero las que tienen movimientos este mes (por mayor gasto), luego alfabético
    filtered.sort((CategoryRead a, CategoryRead b) {
      final double activityA =
          a.attributes.sumSpent.abs() + a.attributes.sumEarned.abs();
      final double activityB =
          b.attributes.sumSpent.abs() + b.attributes.sumEarned.abs();

      if (activityA != activityB) {
        return activityB.compareTo(activityA);
      }
      if (a.attributes.sumSpent != b.attributes.sumSpent) {
        return a.attributes.sumSpent.compareTo(b.attributes.sumSpent);
      }
      return a.attributes.name.toLowerCase().compareTo(
        b.attributes.name.toLowerCase(),
      );
    });

    final int activeCount = allCategoriesList.where((CategoryRead c) {
      return c.attributes.sumSpent != 0 || c.attributes.sumEarned != 0;
    }).length;

    final int excludedCount = allCategoriesList
        .where((CategoryRead c) => categoriesSumExcluded.contains(c.id))
        .length;

    return RefreshIndicator.adaptive(
      onRefresh: () => _handleRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: <Widget>[
          _buildMonthSelector(context),
          const SizedBox(height: 12),
          _buildSummaryCard(
            context,
            currency: currency,
            totalSpent: totalSpent,
            totalEarned: totalEarned,
            activeCount: activeCount,
            excludedCount: excludedCount,
          ),
          const SizedBox(height: 16),
          if (_isSearchOpen) ...<Widget>[
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar categoría...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SegmentedButton<int>(
            segments: <ButtonSegment<int>>[
              ButtonSegment<int>(
                value: 0,
                label: Text('Todas (${allCategoriesList.length})'),
              ),
              const ButtonSegment<int>(value: 1, label: Text('Gastos')),
              const ButtonSegment<int>(value: 2, label: Text('Ingresos')),
            ],
            selected: <int>{_selectedFilterSegment},
            onSelectionChanged: (Set<int> newSelection) {
              setState(() {
                _selectedFilterSegment = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.search_off,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No se encontraron categorías para "$_searchQuery"'
                          : 'No hay categorías en este filtro',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => _searchController.clear(),
                        child: const Text('Limpiar búsqueda'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...<Widget>[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (BuildContext ctx, int index) {
                final CategoryRead category = filtered[index];
                final bool excluded = categoriesSumExcluded.contains(
                  category.id,
                );
                return _CategoryTile(
                  category: category,
                  currency: currency,
                  totalSpent: totalSpent,
                  totalEarned: totalEarned,
                  excluded: excluded,
                  month: selectedMonth,
                  now: now,
                  onRefreshNeeded: () => _handleRefresh(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.currency,
    required this.totalSpent,
    required this.totalEarned,
    required this.excluded,
    required this.month,
    required this.now,
    required this.onRefreshNeeded,
  });

  final CategoryRead category;
  final CurrencyRead currency;
  final double totalSpent;
  final double totalEarned;
  final bool excluded;
  final DateTime month;
  final DateTime now;
  final VoidCallback onRefreshNeeded;

  @override
  Widget build(BuildContext context) {
    final CategoryProperties attrs = category.attributes;
    final bool isNoCat =
        category.attributes.name == "L10NNONE" || category.id == "-1";
    final String displayName = isNoCat
        ? S.of(context).catNone
        : category.attributes.name;
    final Color tint = FtColors.categoryColor(displayName, context: context);

    final double spent = attrs.sumSpent;
    final double earned = attrs.sumEarned;
    final double net = spent + earned;

    final bool hasSpent = spent != 0;
    final bool hasEarned = earned != 0;

    // Proporción de gasto respecto al total mensual
    final double spentFraction = (totalSpent.abs() > 0 && hasSpent)
        ? (spent.abs() / totalSpent.abs()).clamp(0.0, 1.0)
        : 0.0;

    // Proporción de ingreso respecto al total mensual
    final double earnedFraction = (totalEarned > 0 && hasEarned)
        ? (earned / totalEarned).clamp(0.0, 1.0)
        : 0.0;

    final int diffMonths =
        (now.year - month.year) * 12 + (now.month - month.month);

    void openDetail() {
      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => CategoryDetailPage(
                categoryName: displayName,
                category: isNoCat ? null : category,
                period: AnalysisPeriod.month,
                initialOffset: diffMonths >= 0 ? diffMonths : 0,
                initialSelected: 5,
                isIncome: !hasSpent && hasEarned,
              ),
            ),
          )
          .then((_) => onRefreshNeeded());
    }

    Future<void> openEdit() async {
      if (isNoCat) return;
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) =>
            CategoryAddEditDialog(category: category),
      );
      if (ok ?? false) {
        onRefreshNeeded();
      }
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: openDetail,
        onLongPress: isNoCat ? null : openEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  FtCategoryIconWidget(
                    icon: FtCategoryIcon.forName(displayName),
                    color: tint,
                    size: 22,
                    padding: 10,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: excluded
                                          ? Theme.of(context).disabledColor
                                          : null,
                                    ),
                              ),
                            ),
                            if (excluded) ...<Widget>[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: FtColors.warningOf(
                                    context,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Excluido',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: FtColors.warningOf(context),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (hasSpent && totalSpent.abs() > 0) ...<Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: FtProgressBar(
                                  progress: spentFraction,
                                  color: tint,
                                  height: 4,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(spentFraction * 100).toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ] else if (hasEarned && totalEarned > 0) ...<Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: FtProgressBar(
                                  progress: earnedFraction,
                                  color: FtColors.incomeOf(context),
                                  height: 4,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(earnedFraction * 100).toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: FtColors.incomeOf(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ] else ...<Widget>[
                          Text(
                            'Sin movimientos este mes',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        currency.fmt(
                          hasSpent && !hasEarned
                              ? spent
                              : (hasEarned && !hasSpent ? earned : net),
                          context: context,
                        ),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: hasSpent && !hasEarned
                                  ? FtColors.coralOf(context)
                                  : (hasEarned && !hasSpent
                                        ? FtColors.incomeOf(context)
                                        : (net < 0
                                              ? FtColors.coralOf(context)
                                              : (net > 0
                                                    ? FtColors.incomeOf(context)
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant))),
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                      if (hasSpent && hasEarned) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          '${currency.fmt(spent, context: context)} | ${currency.fmt(earned, context: context)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 10,
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
                  const SizedBox(width: 4),
                  if (!isNoCat)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: 'Opciones',
                      onSelected: (String action) {
                        if (action == 'detail') {
                          openDetail();
                        } else if (action == 'edit') {
                          openEdit();
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'detail',
                              child: Row(
                                children: <Widget>[
                                  Icon(Icons.analytics_outlined, size: 18),
                                  SizedBox(width: 10),
                                  Text('Ver movimientos'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: <Widget>[
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 10),
                                  Text('Editar categoría'),
                                ],
                              ),
                            ),
                          ],
                    )
                  else
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

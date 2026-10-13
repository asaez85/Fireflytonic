import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';

class BudgetFilterResult {
  final BudgetRead? budget; // null significa quitar filtro
  const BudgetFilterResult(this.budget);
}

class BudgetFilterSheet extends StatefulWidget {
  final BudgetRead? initialSelected;

  const BudgetFilterSheet({super.key, this.initialSelected});

  static Future<BudgetFilterResult?> show(
    BuildContext context, {
    BudgetRead? initialSelected,
  }) {
    return showModalBottomSheet<BudgetFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) =>
          BudgetFilterSheet(initialSelected: initialSelected),
    );
  }

  @override
  State<BudgetFilterSheet> createState() => _BudgetFilterSheetState();
}

class _BudgetFilterSheetState extends State<BudgetFilterSheet> {
  List<BudgetRead> _allBudgets = <BudgetRead>[];
  BudgetRead? _selectedBudget;
  bool _isLoading = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedBudget = widget.initialSelected;
    _fetchBudgets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchBudgets() async {
    try {
      final FireflyIii api = context.read<FireflyService>().api;
      final List<BudgetRead> budgets = <BudgetRead>[];
      int page = 1;
      while (true) {
        final Response<BudgetArray> resp = await api.v1BudgetsGet(page: page);
        for (final BudgetRead b in resp.body?.data ?? <BudgetRead>[]) {
          if (b.attributes.active ?? true) {
            budgets.add(b);
          }
        }
        final int totalPages = resp.body?.meta.pagination?.totalPages ?? 1;
        if (page >= totalPages || (resp.body?.data.isEmpty ?? true)) {
          break;
        }
        page++;
      }

      budgets.sort(
        (BudgetRead a, BudgetRead b) => a.attributes.name
            .toLowerCase()
            .compareTo(b.attributes.name.toLowerCase()),
      );

      if (mounted) {
        setState(() {
          _allBudgets = budgets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final List<BudgetRead> filtered = _allBudgets.where((BudgetRead b) {
      if (_searchQuery.isEmpty) return true;
      return b.attributes.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? FtColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: <Widget>[
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Presupuestos',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              onChanged: (String q) => setState(() => _searchQuery = q.trim()),
              decoration: InputDecoration(
                hintText: 'Buscar presupuesto...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? FtColors.sectionHeaderDark
                    : const Color(0xFFEDF2F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // List of budgets
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: <Widget>[
                      // Option: Todos / Sin filtro
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDark
                              ? Colors.white12
                              : Colors.black.withValues(alpha: 0.06),
                          child: Icon(
                            Icons.all_inclusive,
                            color: theme.colorScheme.onSurface,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Todos los movimientos (sin filtro)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: _selectedBudget == null
                            ? Icon(
                                Icons.check,
                                color: FtColors.coralOf(context),
                              )
                            : null,
                        onTap: () {
                          setState(() => _selectedBudget = null);
                        },
                      ),
                      const Divider(height: 1, indent: 72),
                      ...filtered.map((BudgetRead b) {
                        final bool isSelected = _selectedBudget?.id == b.id;
                        final IconData icon = FtCategoryIcon.forName(
                          b.attributes.name,
                        );
                        final Color color = FtColors.categoryColor(
                          b.attributes.name,
                          context: context,
                        );

                        return ListTile(
                          leading: FtCategoryIconWidget(
                            icon: icon,
                            color: color,
                            size: 20,
                            padding: 8,
                          ),
                          title: Text(
                            b.attributes.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: FtColors.coralOf(context),
                                )
                              : null,
                          onTap: () {
                            setState(() => _selectedBudget = b);
                          },
                        );
                      }),
                    ],
                  ),
          ),

          // Bottom buttons
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: isDark ? FtColors.surfaceDark : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                if (_selectedBudget != null)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, const BudgetFilterResult(null));
                    },
                    child: Text(
                      'Quitar filtro',
                      style: TextStyle(
                        color: FtColors.coralOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: FtColors.coralOf(context),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context, BudgetFilterResult(_selectedBudget));
                  },
                  child: const Text(
                    'Aplicar',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

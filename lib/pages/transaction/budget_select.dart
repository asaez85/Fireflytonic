import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';

class BudgetSelectResult {
  final BudgetRead? budget;

  /// [budget] es null cuando se elige "Sin presupuesto" (quitar presupuesto).
  /// El valor null devuelto por [show] indica que el usuario canceló.
  const BudgetSelectResult(this.budget);
}

class BudgetSelectPage extends StatefulWidget {
  final String? selectedBudgetName;

  const BudgetSelectPage({super.key, this.selectedBudgetName});

  static Future<BudgetSelectResult?> show(
    BuildContext context, {
    String? selectedBudgetName,
  }) {
    return Navigator.push<BudgetSelectResult>(
      context,
      MaterialPageRoute<BudgetSelectResult>(
        builder: (BuildContext context) =>
            BudgetSelectPage(selectedBudgetName: selectedBudgetName),
      ),
    );
  }

  @override
  State<BudgetSelectPage> createState() => _BudgetSelectPageState();
}

class _BudgetSelectPageState extends State<BudgetSelectPage> {
  final TextEditingController _searchController = TextEditingController();
  List<BudgetRead> _allBudgets = <BudgetRead>[];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
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
        if (resp.isSuccessful && resp.body != null) {
          for (final BudgetRead b in resp.body!.data) {
            if (b.attributes.active ?? true) {
              budgets.add(b);
            }
          }
          final int totalPages = resp.body!.meta.pagination?.totalPages ?? 1;
          if (page >= totalPages || resp.body!.data.isEmpty) {
            break;
          }
          page++;
        } else {
          break;
        }
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(S.of(context).generalBudget)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final List<BudgetRead> filtered = _allBudgets.where((BudgetRead b) {
      if (_searchQuery.isEmpty) return true;
      return b.attributes.name.toLowerCase().contains(_searchQuery);
    }).toList();

    final bool hasSelection = widget.selectedBudgetName?.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(S.of(context).generalBudget),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(28.0),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Buscar presupuesto",
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 16.0,
                  ),
                  prefixIconColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: <Widget>[
                // Opción para quitar/limpiar el presupuesto
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  leading: FtCategoryIconWidget(
                    icon: Icons.payments,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    padding: 8,
                  ),
                  title: Text(
                    S.of(context).generalUnknown,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: hasSelection
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  trailing: !hasSelection
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 24,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context, const BudgetSelectResult(null));
                  },
                ),
                const Divider(height: 1),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text("No se encontraron presupuestos"),
                    ),
                  )
                else
                  ...filtered.map((BudgetRead b) {
                    final bool isSelected =
                        widget.selectedBudgetName != null &&
                        widget.selectedBudgetName!.toLowerCase() ==
                            b.attributes.name.toLowerCase();
                    final IconData icon = FtCategoryIcon.forName(
                      b.attributes.name,
                    );
                    final Color color = FtColors.categoryColor(
                      b.attributes.name,
                      context: context,
                    );

                    return Column(
                      children: <Widget>[
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          leading: FtCategoryIconWidget(
                            icon: icon,
                            color: color,
                            padding: 8,
                          ),
                          title: Text(
                            b.attributes.name,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  size: 24,
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(context, BudgetSelectResult(b));
                          },
                        ),
                        const Divider(height: 1),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

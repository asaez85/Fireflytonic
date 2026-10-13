import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';

enum CategoryTabType { expense, income, transfer }

class CategorySelectPage extends StatefulWidget {
  final String selectedCategoryName;

  const CategorySelectPage({super.key, required this.selectedCategoryName});

  @override
  State<CategorySelectPage> createState() => _CategorySelectPageState();
}

class _CategorySelectPageState extends State<CategorySelectPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  List<CategoryRead> _allCategories = <CategoryRead>[];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _fetchCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final FireflyIii api = context.read<FireflyService>().api;
      final List<CategoryRead> allCats = <CategoryRead>[];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final Response<CategoryArray> response = await api.v1CategoriesGet(
          page: page,
          limit: 100,
        );
        if (response.isSuccessful && response.body != null) {
          final List<CategoryRead> data = response.body!.data;
          allCats.addAll(data);
          if (data.length < 100) {
            hasMore = false;
          } else {
            page++;
          }
        } else {
          hasMore = false;
        }
      }

      if (allCats.isNotEmpty) {
        setState(() {
          _allCategories = allCats;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewCategory() async {
    final TextEditingController newCatController = TextEditingController();
    final String? newCatName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Nueva categoría"),
          content: TextField(
            controller: newCatController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "Nombre de la categoría",
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, newCatController.text.trim());
              },
              child: const Text("Crear"),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (newCatName != null && newCatName.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });
      try {
        final NavigatorState navigator = Navigator.of(context);
        final FireflyIii api = context.read<FireflyService>().api;
        final Response<CategorySingle> response = await api.v1CategoriesPost(
          body: CategoryStore(name: newCatName, notes: ""),
        );
        if (response.isSuccessful && response.body != null) {
          navigator.pop(newCatName);
        } else {
          setState(() {
            _isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error al crear la categoría")),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al crear la categoría")),
        );
      }
    }
  }

  CategoryTabType _getCategoryTabType(CategoryRead cat) {
    final bool isExpense =
        cat.attributes.spent?.any(
          (ArrayEntryWithCurrencyAndSum e) =>
              double.tryParse(e.sum ?? '0') != 0,
        ) ??
        false;
    final bool isIncome =
        cat.attributes.earned?.any(
          (ArrayEntryWithCurrencyAndSum e) =>
              double.tryParse(e.sum ?? '0') != 0,
        ) ??
        false;
    final bool isTransfer =
        cat.attributes.transferred?.any(
          (ArrayEntryWithCurrencyAndSum e) =>
              double.tryParse(e.sum ?? '0') != 0,
        ) ??
        false;

    if (isExpense) return CategoryTabType.expense;
    if (isIncome) return CategoryTabType.income;
    if (isTransfer) return CategoryTabType.transfer;

    // Fallback based on name keywords
    final String name = cat.attributes.name.toLowerCase();
    if (name.contains("nómina") ||
        name.contains("nomina") ||
        name.contains("ingreso") ||
        name.contains("salario") ||
        name.contains("sueldo")) {
      return CategoryTabType.income;
    }
    if (name.contains("transferencia") ||
        name.contains("ahorro") ||
        name.contains("traspaso") ||
        name.contains("bizum") ||
        name.contains("ajuste")) {
      return CategoryTabType.transfer;
    }

    return CategoryTabType.expense; // Default
  }

  Map<String, List<CategoryRead>> _groupCategories(
    List<CategoryRead> categories,
    String selectedCategory,
  ) {
    final Map<String, List<CategoryRead>> grouped =
        <String, List<CategoryRead>>{
          "SUGERIDAS": <CategoryRead>[],
          "OCIO Y TRANSPORTE": <CategoryRead>[],
          "HOGAR Y SUMINISTROS": <CategoryRead>[],
          "COMPRAS Y OTROS": <CategoryRead>[],
        };

    // Add selected category to SUGERIDAS first
    final CategoryRead? selectedCatObj = categories
        .cast<CategoryRead?>()
        .firstWhere(
          (CategoryRead? c) =>
              c?.attributes.name.toLowerCase() ==
              selectedCategory.toLowerCase(),
          orElse: () => null,
        );

    if (selectedCatObj != null) {
      grouped["SUGERIDAS"]!.add(selectedCatObj);
    }

    // Process other categories
    for (CategoryRead cat in categories) {
      final String name = cat.attributes.name;
      final String n = name.toLowerCase();

      // Skip selected category in general list if it is already in SUGERIDAS
      if (n == selectedCategory.toLowerCase()) {
        continue;
      }

      // Determine original group
      String targetGroup = "COMPRAS Y OTROS";
      if (n.contains("restaur") ||
          n.contains("ocio") ||
          n.contains("cine") ||
          n.contains("música") ||
          n.contains("musica") ||
          n.contains("café") ||
          n.contains("cafe") ||
          n.contains("bar") ||
          n.contains("viaje") ||
          n.contains("hotel") ||
          n.contains("gasolina") ||
          n.contains("combust") ||
          n.contains("coche") ||
          n.contains("taller") ||
          n.contains("peaje") ||
          n.contains("parking") ||
          n.contains("aparcamient") ||
          n.contains("taxi") ||
          n.contains("uber") ||
          n.contains("cabify") ||
          n.contains("metro") ||
          n.contains("bus") ||
          n.contains("tren") ||
          n.contains("bici") ||
          n.contains("moto")) {
        targetGroup = "OCIO Y TRANSPORTE";
      } else if (n.contains("alquiler") ||
          n.contains("hipoteca") ||
          n.contains("agua") ||
          n.contains("luz") ||
          n.contains("electric") ||
          n.contains("gas") ||
          n.contains("internet") ||
          n.contains("fibra") ||
          n.contains("móvil") ||
          n.contains("movil") ||
          n.contains("teléfono") ||
          n.contains("comunidad") ||
          n.contains("limpieza") ||
          n.contains("casa") ||
          n.contains("hogar")) {
        targetGroup = "HOGAR Y SUMINISTROS";
      }

      // Add to target group
      grouped[targetGroup]!.add(cat);

      // Also copy to SUGERIDAS if it's not full yet
      if (grouped["SUGERIDAS"]!.length < 5) {
        grouped["SUGERIDAS"]!.add(cat);
      }
    }

    // Clean empty groups
    grouped.removeWhere(
      (String key, List<CategoryRead> value) => value.isEmpty,
    );

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Seleccionar categoría")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Filter categories by search
    final List<CategoryRead> filteredList = _allCategories.where((
      CategoryRead cat,
    ) {
      return cat.attributes.name.toLowerCase().contains(_searchQuery);
    }).toList();

    // Split filtered list by tabs
    final List<CategoryRead> expenseCats = filteredList
        .where(
          (CategoryRead cat) =>
              _getCategoryTabType(cat) == CategoryTabType.expense,
        )
        .toList();
    final List<CategoryRead> incomeCats = filteredList
        .where(
          (CategoryRead cat) =>
              _getCategoryTabType(cat) == CategoryTabType.income,
        )
        .toList();
    final List<CategoryRead> transferCats = filteredList
        .where(
          (CategoryRead cat) =>
              _getCategoryTabType(cat) == CategoryTabType.transfer,
        )
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("Seleccionar categoría"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      body: Column(
        children: <Widget>[
          // Search box
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
                  hintText: "Buscar categoría",
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

          // TabBar
          TabBar(
            controller: _tabController,
            indicatorColor: Theme.of(context).colorScheme.secondary,
            labelColor: Theme.of(context).colorScheme.secondary,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
            tabs: const <Widget>[
              Tab(text: "Gastos"),
              Tab(text: "Ingresos"),
              Tab(text: "No computable"),
            ],
          ),

          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildCategoryList(expenseCats),
                _buildCategoryList(incomeCats),
                _buildCategoryList(transferCats),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(List<CategoryRead> categories) {
    if (categories.isEmpty) {
      return const Center(child: Text("No se encontraron categorías"));
    }

    final Map<String, List<CategoryRead>> grouped = _groupCategories(
      categories,
      widget.selectedCategoryName,
    );

    return ListView.builder(
      itemCount: grouped.keys.length,
      itemBuilder: (BuildContext context, int index) {
        final String groupName = grouped.keys.elementAt(index);
        final List<CategoryRead> groupCats = grouped[groupName]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header
            Container(
              width: double.infinity,
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    groupName,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  if (groupName == "SUGERIDAS")
                    TextButton(
                      onPressed: _createNewCategory,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                      child: Text(
                        "¡Nuevo!",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Items
            ...groupCats.map((CategoryRead cat) {
              final bool isDark =
                  Theme.of(context).brightness == Brightness.dark;
              final String name = cat.attributes.name;
              final bool isSelected =
                  name.toLowerCase() ==
                  widget.selectedCategoryName.toLowerCase();
              final String notes = cat.attributes.notes ?? "";
              final Color catColor = FtColors.categoryColor(
                name,
                isDark: isDark,
              );
              final IconData catIcon = FtCategoryIcon.forName(name);

              return Column(
                children: <Widget>[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 8.0,
                    ),
                    leading: FtCategoryIconWidget(
                      icon: catIcon,
                      color: catColor,
                      padding: 8,
                    ),
                    title: Text(
                      name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: notes.isNotEmpty
                        ? Text(
                            notes,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          )
                        : null,
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.secondary,
                            size: 24,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context, name);
                    },
                  ),
                  const Divider(height: 1),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}

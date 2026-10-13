import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';

class CategoriesFilterSheet extends StatefulWidget {
  final List<CategoryRead> initialSelected;

  const CategoriesFilterSheet({
    super.key,
    this.initialSelected = const <CategoryRead>[],
  });

  static Future<List<CategoryRead>?> show(
    BuildContext context, {
    List<CategoryRead> initialSelected = const <CategoryRead>[],
  }) {
    return showModalBottomSheet<List<CategoryRead>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) =>
          CategoriesFilterSheet(initialSelected: initialSelected),
    );
  }

  @override
  State<CategoriesFilterSheet> createState() => _CategoriesFilterSheetState();
}

class _CategoriesFilterSheetState extends State<CategoriesFilterSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  List<CategoryRead> _allCategories = <CategoryRead>[];
  final Map<String, CategoryRead> _selectedCategories =
      <String, CategoryRead>{};
  bool _isLoading = true;
  String _searchQuery = "";

  static const Map<String, String> _categorySubtitles = <String, String>{
    'restaurante': 'Y cafetería, bar, discoteca...',
    'restaurantes': 'Y cafetería, bar, discoteca...',
    'parking y peaje': 'Estacionamiento regulado también va aquí.',
    'parking': 'Estacionamiento regulado también va aquí.',
    'peaje': 'Peajes de autopista y túneles.',
    'transportes': 'Bus, metro, taxi, tren, ferry, avión, bici...',
    'transporte': 'Bus, metro, taxi, tren, ferry, avión, bici...',
    'gasolina': 'Y diésel, etanol, recarga eléctrica...',
    'combustible': 'Y diésel, etanol, recarga eléctrica...',
    'espectáculos': 'Cine, teatro, danza, partidos, conciertos...',
    'espectaculos': 'Cine, teatro, danza, partidos, conciertos...',
    'hotel': 'Y parador, albergue, camping, casa rural...',
    'hoteles': 'Y parador, albergue, camping, casa rural...',
    'viajes': 'Vuelos, hoteles, paquetes vacacionales...',
    'loterías': 'Y apuestas, bingo, casino...',
    'loterias': 'Y apuestas, bingo, casino...',
    'alquiler vehículos': 'Coche, moto, furgoneta, carsharing...',
    'alquiler vehiculos': 'Coche, moto, furgoneta, carsharing...',
    'otros ocio': 'Cruceros, multiaventuras, hobbies...',
    'ocio': 'Cruceros, multiaventuras, hobbies...',
    'supermercado': 'Alimentación, ultramarinos, bebida...',
    'supermercados': 'Alimentación, ultramarinos, bebida...',
    'alimentación': 'Supermercado, comida, ultramarinos...',
    'alimentacion': 'Supermercado, comida, ultramarinos...',
    'farmacia': 'Medicamentos, óptica, parafarmacia...',
    'médico': 'Dentista, consultas, análisis, clínica...',
    'medico': 'Dentista, consultas, análisis, clínica...',
    'agua': 'Suministro de agua, saneamiento, canon...',
    'electricidad': 'Factura de luz, energía, potencia...',
    'luz': 'Factura de luz, energía...',
    'gas': 'Factura de gas natural, butano...',
    'internet': 'Fibra óptica, ADSL, telefonía fija...',
    'móvil': 'Facturas móvil, líneas adicionales, recargas...',
    'movil': 'Facturas móvil, líneas adicionales, recargas...',
    'televisión': 'Plataformas de streaming, cable, TV...',
    'television': 'Plataformas de streaming, cable, TV...',
    'hogar': 'Mobiliario, electrodomésticos, menaje, bricolaje...',
    'alquiler': 'Renta mensual de vivienda o local...',
    'hipoteca': 'Cuota mensual de préstamo hipotecario...',
    'comunidad': 'Gastos ordinarios y derramas de comunidad...',
    'seguro auto': 'Póliza de coche, moto o ciclomotor...',
    'seguro hogar': 'Póliza multirriesgo de vivienda...',
    'seguro vida': 'Póliza de vida, accidentes...',
    'seguro salud': 'Seguro médico privado, mutua...',
    'seguros': 'Pólizas y coberturas aseguradoras...',
    'nómina': 'Sueldo, salario mensual, paga extra...',
    'nomina': 'Sueldo, salario mensual, paga extra...',
    'salario': 'Ingreso regular por trabajo por cuenta ajena...',
    'transferencias': 'Traspasos, Bizum, movimientos internos...',
    'transferencia': 'Traspasos, Bizum, movimientos internos...',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    for (CategoryRead c in widget.initialSelected) {
      _selectedCategories[c.id] = c;
    }
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
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

      if (mounted) {
        setState(() {
          _allCategories = allCats;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int _getTabCategoryType(CategoryRead cat) {
    // 0: Gasto, 1: Ingreso, 2: No computable / Transferencias
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

    if (isExpense) return 0;
    if (isIncome) return 1;
    if (isTransfer) return 2;

    final String name = cat.attributes.name.toLowerCase();
    if (name.contains("nómina") ||
        name.contains("nomina") ||
        name.contains("ingreso") ||
        name.contains("salario") ||
        name.contains("sueldo") ||
        name.contains("pensión") ||
        name.contains("pension")) {
      return 1;
    }
    if (name.contains("transferencia") ||
        name.contains("ahorro") ||
        name.contains("traspaso") ||
        name.contains("bizum") ||
        name.contains("inversión") ||
        name.contains("inversion") ||
        name.contains("ajuste")) {
      return 2;
    }

    return 0; // Default to Gastos
  }

  String _getCategorySubtitle(String catName) {
    final String norm = catName.trim().toLowerCase();
    if (_categorySubtitles.containsKey(norm)) {
      return _categorySubtitles[norm]!;
    }
    for (MapEntry<String, String> entry in _categorySubtitles.entries) {
      if (norm.contains(entry.key)) {
        return entry.value;
      }
    }
    return "";
  }

  Map<String, List<CategoryRead>> _groupBySection(
    List<CategoryRead> categories,
  ) {
    final Map<String, List<CategoryRead>> groups = <String, List<CategoryRead>>{
      "OCIO Y TRANSPORTE": <CategoryRead>[],
      "HOGAR Y SUMINISTROS": <CategoryRead>[],
      "SEGUROS Y FINANZAS": <CategoryRead>[],
      "ALIMENTACIÓN Y SALUD": <CategoryRead>[],
      "OTROS": <CategoryRead>[],
    };

    for (CategoryRead cat in categories) {
      final String n = cat.attributes.name.toLowerCase();
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
          n.contains("moto") ||
          n.contains("espectác") ||
          n.contains("espectac") ||
          n.contains("loterí") ||
          n.contains("loteri")) {
        groups["OCIO Y TRANSPORTE"]!.add(cat);
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
          n.contains("telefono") ||
          n.contains("comunidad") ||
          n.contains("limpieza") ||
          n.contains("casa") ||
          n.contains("hogar")) {
        groups["HOGAR Y SUMINISTROS"]!.add(cat);
      } else if (n.contains("seguro") ||
          n.contains("póliza") ||
          n.contains("poliza") ||
          n.contains("banco") ||
          n.contains("comisión") ||
          n.contains("comision") ||
          n.contains("impuesto") ||
          n.contains("tasa")) {
        groups["SEGUROS Y FINANZAS"]!.add(cat);
      } else if (n.contains("supermerc") ||
          n.contains("aliment") ||
          n.contains("comida") ||
          n.contains("farmac") ||
          n.contains("médic") ||
          n.contains("medic") ||
          n.contains("salud") ||
          n.contains("ópt") ||
          n.contains("opt")) {
        groups["ALIMENTACIÓN Y SALUD"]!.add(cat);
      } else {
        groups["OTROS"]!.add(cat);
      }
    }

    groups.removeWhere((_, List<CategoryRead> list) => list.isEmpty);
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final double sheetHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      height: sheetHeight,
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
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? FtColors.sectionHeaderDark
                    : const Color(0xFFF1F4F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Buscar categoría",
                  hintStyle: TextStyle(
                    color: isDark ? FtColors.textMutedDark : FtColors.textMuted,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: FtColors.blueOf(context),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // Tabs: Gastos | Ingresos | No computable
          TabBar(
            controller: _tabController,
            labelColor: FtColors.blueOf(context),
            unselectedLabelColor: isDark
                ? FtColors.textMutedDark
                : FtColors.textMuted,
            indicatorColor: FtColors.blueOf(context),
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: const <Widget>[
              Tab(text: "Gastos"),
              Tab(text: "Ingresos"),
              Tab(text: "No computable"),
            ],
          ),

          const Divider(height: 1, thickness: 1),

          // Tab content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: <Widget>[
                      _buildCategoryList(tabType: 0),
                      _buildCategoryList(tabType: 1),
                      _buildCategoryList(tabType: 2),
                    ],
                  ),
          ),

          // Bottom Action Bar
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: isDark ? FtColors.surfaceDark : Colors.white,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                if (_selectedCategories.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategories.clear();
                      });
                    },
                    child: Text(
                      "Limpiar",
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
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context, _selectedCategories.values.toList());
                  },
                  child: Text(
                    _selectedCategories.isEmpty
                        ? "Cerrar"
                        : "Aplicar (${_selectedCategories.length})",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList({required int tabType}) {
    final List<CategoryRead> tabCategories = _allCategories.where((
      CategoryRead c,
    ) {
      if (_searchQuery.isNotEmpty) {
        return c.attributes.name.toLowerCase().contains(_searchQuery);
      }
      return _getTabCategoryType(c) == tabType;
    }).toList();

    if (tabCategories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _searchQuery.isNotEmpty
                ? "No se encontraron categorías"
                : "No hay categorías en esta sección",
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? FtColors.textMutedDark
                  : FtColors.textMuted,
            ),
          ),
        ),
      );
    }

    final Map<String, List<CategoryRead>> grouped = _groupBySection(
      tabCategories,
    );

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: grouped.keys.length,
      itemBuilder: (BuildContext context, int index) {
        final String sectionTitle = grouped.keys.elementAt(index);
        final List<CategoryRead> items = grouped[sectionTitle]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Section Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: Theme.of(context).brightness == Brightness.dark
                  ? FtColors.sectionHeaderDark.withValues(alpha: 0.5)
                  : const Color(0xFFF7F9FC),
              child: Text(
                sectionTitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? FtColors.textMutedDark
                      : FtColors.textMuted,
                ),
              ),
            ),

            // Items
            ...items.map((CategoryRead cat) {
              final String catName = cat.attributes.name;
              final bool isDark =
                  Theme.of(context).brightness == Brightness.dark;
              final Color catColor = FtColors.categoryColor(
                catName,
                isDark: isDark,
              );
              final IconData catIcon = FtCategoryIcon.forName(catName);
              final String subtitle = _getCategorySubtitle(catName);
              final bool isSelected = _selectedCategories.containsKey(cat.id);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 2,
                ),
                leading: FtCategoryIconWidget(
                  icon: catIcon,
                  color: catColor,
                  size: 24,
                  padding: 10,
                ),
                title: Text(
                  catName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: subtitle.isNotEmpty
                    ? Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? FtColors.textMutedDark
                              : FtColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: Switch.adaptive(
                  value: isSelected,
                  activeThumbColor: FtColors.coralOf(context),
                  onChanged: (bool value) {
                    setState(() {
                      if (value) {
                        _selectedCategories[cat.id] = cat;
                      } else {
                        _selectedCategories.remove(cat.id);
                      }
                    });
                  },
                ),
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedCategories.remove(cat.id);
                    } else {
                      _selectedCategories[cat.id] = cat;
                    }
                  });
                },
              );
            }),
          ],
        );
      },
    );
  }
}

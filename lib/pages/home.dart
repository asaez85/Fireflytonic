import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/home/analysis.dart';
import 'package:waterflyiii/pages/home/budgets.dart';
import 'package:waterflyiii/pages/home/evolution.dart';
import 'package:waterflyiii/pages/home/summary.dart';
import 'package:waterflyiii/pages/home/transactions.dart';
import 'package:waterflyiii/pages/navigation.dart';
import 'package:waterflyiii/widgets/fabs.dart';

final Logger log = Logger("Pages.Home");

class PageActions extends ChangeNotifier {
  final Map<Key, List<Widget>> _map = <Key, List<Widget>>{};
  List<Widget>? get(Key key) => _map[key];

  final Logger log = Logger("Pages.Home.PageActions");

  void set(Key key, List<Widget>? actions) {
    if (actions == null) {
      _map.remove(key);
    } else {
      _map[key] = actions;
    }
    log.finest(() => "notify PageActions->set()");
    notifyListeners();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final Logger log = Logger("Pages.Home.Page");

  late TabController _tabController;
  Widget? _newTransactionFab;

  final PageActions _actions = PageActions();

  final GlobalKey<HomeTransactionsState> _transactionsKey =
      GlobalKey<HomeTransactionsState>();
  AccountRead? pendingAccountFilter;
  BudgetRead? pendingBudgetFilter;
  ({int segment, DateTime start, DateTime end})? pendingTypeFilter;

  static const List<String> _sectionTitles = <String>[
    "Inicio",
    "Movimientos",
    "Presupuestos",
    "Análisis",
    "Evolución",
  ];

  late final List<Widget> tabPages;

  @override
  void initState() {
    super.initState();

    tabPages = <Widget>[
      const HomeSummary(key: Key("HomeSummary")),
      HomeTransactions(key: _transactionsKey),
      HomeBudgets(
        key: const Key("HomeBudgets"),
        onOpenBudgetTransactions: openTransactionsForBudget,
      ),
      const HomeAnalysis(key: Key("HomeAnalysis")),
      const HomeEvolution(key: Key("HomeEvolution")),
    ];

    _tabController = TabController(vsync: this, length: 5);
    _tabController.addListener(_handleTabChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Navegación inferior estilo Fintonic (en lugar de las pestañas
      // superiores originales). Se monta dentro de un Scaffold propio en build.
      // Call once to set fab/page actions
      _handleTabChange();
      if (mounted) {
        setState(() {
          _newTransactionFab = NewTransactionFab(context: context);
        });
      }
    });

    _actions.addListener(() => _handleTabChange());
  }

  void _onSelectTab(int index) {
    if (_tabController.index == index) {
      return;
    }
    _tabController.animateTo(index);
    setState(() {});
    _handleTabChange();
  }

  void openTransactionsForAccount(AccountRead account) {
    if (_transactionsKey.currentState != null) {
      _transactionsKey.currentState!.setAccountFilter(account);
    } else {
      pendingAccountFilter = account;
    }
    _onSelectTab(1);
  }

  void openTransactionsForBudget(BudgetRead budget) {
    if (_transactionsKey.currentState != null) {
      _transactionsKey.currentState!.setBudgetFilter(budget);
    } else {
      pendingBudgetFilter = budget;
    }
    _onSelectTab(1);
  }

  void openTransactionsForMonthType({
    required int segment,
    required DateTime start,
    required DateTime end,
  }) {
    if (_transactionsKey.currentState != null) {
      _transactionsKey.currentState!.setTypeFilter(
        segment: segment,
        start: start,
        end: end,
      );
    } else {
      pendingTypeFilter = (segment: segment, start: start, end: end);
    }
    _onSelectTab(1);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();

    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      log.finer(() => "_handleTabChange(${_tabController.index})");
      // El FAB ahora vive en el Scaffold propio de esta página (acoplado
      // sobre la barra inferior), así que el del NavPage exterior se oculta.
      context.read<NavPageElements>().fab = null;
      context.read<NavPageElements>().appBarTitle = Text(
        _sectionTitles[_tabController.index],
      );
      context.read<NavPageElements>().appBarActions = _actions.get(
        tabPages[_tabController.index].key ?? const Key(''),
      );
    }
  }

  late List<Tab> tabs;

  @override
  Widget build(BuildContext context) {
    log.finest(() => "build(tab: ${_tabController.index})");
    return ChangeNotifierProvider<PageActions>.value(
      value: _actions,
      child: PopScope(
        canPop: _tabController.index == 0,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          if (_tabController.index != 0) {
            _onSelectTab(0);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: (_tabController.index < 2)
              ? _newTransactionFab
              : null,
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: tabPages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabController.index,
            onDestinationSelected: _onSelectTab,
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: "Inicio",
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: "Movimientos",
              ),
              NavigationDestination(
                icon: Icon(Icons.donut_small_outlined),
                selectedIcon: Icon(Icons.donut_small),
                label: "Presupuestos",
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: "Análisis",
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: "Evolución",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

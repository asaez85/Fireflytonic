import 'package:animations/animations.dart';
import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/animations.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/accounts/search.dart';
import 'package:waterflyiii/pages/home/accounts/row.dart';
import 'package:waterflyiii/pages/navigation.dart';
import 'package:waterflyiii/settings.dart';
import 'package:waterflyiii/widgets/listview_pagedchildbuilder.dart';

final Logger log = Logger("Pages.Accounts");

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Logger log = Logger("Pages.Accounts.Page");

  @override
  void initState() {
    super.initState();

    _tabController = TabController(vsync: this, length: 4);
    _tabController.addListener(_handleTabChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavPageElements>().appBarBottom = TabBar(
        isScrollable: true,
        controller: _tabController,
        tabAlignment: TabAlignment.start,
        tabs: <Tab>[
          Tab(text: S.of(context).accountsLabelAsset),
          Tab(text: S.of(context).accountsLabelExpense),
          Tab(text: S.of(context).accountsLabelRevenue),
          Tab(text: S.of(context).accountsLabelLiabilities),
        ],
      );

      context.read<NavPageElements>().appBarActions = <Widget>[
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: MaterialLocalizations.of(context).searchFieldLabel,
          onPressed: () {
            log.finest(() => "pressed search button");
            Navigator.of(context).push(
              PageRouteBuilder<Widget>(
                pageBuilder: (BuildContext context, _, _) =>
                    AccountSearch(type: _accountTypes[_tabController.index]),
                transitionDuration: animDurationEmphasizedDecelerate,
                reverseTransitionDuration: animDurationEmphasizedAccelerate,
                transitionsBuilder:
                    (
                      BuildContext context,
                      Animation<double> primaryAnimation,
                      Animation<double> secondaryAnimation,
                      Widget child,
                    ) => SharedAxisTransition(
                      animation: primaryAnimation,
                      secondaryAnimation: secondaryAnimation,
                      transitionType: .horizontal,
                      child: child,
                    ),
              ),

              /*    CupertinoPageRoute<bool>(
                builder: (BuildContext context) => AccountSearch(
                  type: _accountTypes[_tabController.index],
                ),
                fullscreenDialog: false,
              ),*/
            );
          },
        ),
      ];

      // Call once to set fab/page actions
      _handleTabChange();
    });
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
    }
  }

  static const List<AccountTypeFilter> _accountTypes = <AccountTypeFilter>[
    .asset,
    .expense,
    .revenue,
    .liabilities,
  ];
  final List<Widget> _tabPages = _accountTypes
      .map<Widget>((AccountTypeFilter t) => AccountDetails(accountType: t))
      .toList();

  @override
  Widget build(BuildContext context) {
    log.fine(() => "build(tab: ${_tabController.index})");
    return TabBarView(controller: _tabController, children: _tabPages);
  }
}

class AccountDetails extends StatefulWidget {
  const AccountDetails({super.key, required this.accountType});

  final AccountTypeFilter accountType;

  @override
  State<AccountDetails> createState() => _AccountDetailsState();
}

class _AccountDetailsState extends State<AccountDetails>
    with AutomaticKeepAliveClientMixin {
  final int _numberOfItemsPerRequest = 50;
  PagingState<int, AccountRead> _pagingState = PagingState<int, AccountRead>();

  bool _isRefreshing = false;

  final Logger log = Logger("Pages.Accounts.Details");

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    try {
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

    try {
      final FireflyIii api = context.read<FireflyService>().api;

      if (!isRefresh) {
        setState(() {
          _pagingState = _pagingState.copyWith(isLoading: true, error: null);
        });
      }

      final int pageKey = isRefresh ? 1 : ((_pagingState.keys?.last ?? 0) + 1);
      log.finest(
        "Getting page $pageKey (isRefresh: $isRefresh, ${_pagingState.pages?.length} pages loaded)",
      );

      final Response<AccountArray> respAccounts = await api.v1AccountsGet(
        type: widget.accountType,
        page: pageKey,
      );
      apiThrowErrorIfEmpty(respAccounts, mounted ? context : null);

      final List<AccountRead> accountList = respAccounts.body!.data;
      final bool isLastPage = accountList.length < _numberOfItemsPerRequest;

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _pagingState = PagingState<int, AccountRead>(
              pages: <List<AccountRead>>[accountList],
              keys: <int>[pageKey],
              hasNextPage: !isLastPage,
              isLoading: false,
              error: null,
            );
          } else {
            _pagingState = _pagingState.copyWith(
              pages: <List<AccountRead>>[...?_pagingState.pages, accountList],
              keys: <int>[...?_pagingState.keys, pageKey],
              hasNextPage: !isLastPage,
              isLoading: false,
              error: null,
            );
          }
        });
      }
    } catch (e, stackTrace) {
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

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    log.fine(() => "build()");
    context.watch<SettingsProvider>();

    final Widget list = RefreshIndicator.adaptive(
      onRefresh: _handleRefresh,
      child: PagedListView<int, AccountRead>(
        state: _pagingState,
        fetchNextPage: () => _fetchPage(),
        builderDelegate: customPagedChildBuilderDelegate<AccountRead>(
          itemBuilder: (BuildContext context, AccountRead item, int index) =>
              accountRowBuilder(context, item, index, _handleRefresh),
        ),
      ),
    );

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
}

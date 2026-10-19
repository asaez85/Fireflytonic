import 'dart:async';

import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/accounts/addedit.dart';
import 'package:waterflyiii/pages/home/accounts/row.dart';
import 'package:waterflyiii/pages/navigation.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/bank_logo_badge.dart';

final Logger log = Logger('Pages.Accounts');

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<AccountRead>? _allAccounts;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;

  int _filterType = 0; // 0: Todas, 1: Activos, 2: Pasivos, 3: Otras
  bool _showInactive = false;
  bool _isSearchOpen = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final String query = _searchController.text.trim().toLowerCase();
      if (_searchQuery != query) {
        setState(() {
          _searchQuery = query;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateNavElements();
      _fetchAccounts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _updateNavElements() {
    if (!mounted) return;
    final NavPageElements nav = context.read<NavPageElements>();

    nav.appBarTitle = Text(S.of(context).navigationAccounts);
    nav.appBarBottom = null;

    nav.appBarActions = <Widget>[
      IconButton(
        icon: Icon(
          _isSearchOpen ? Icons.search_off_outlined : Icons.search_outlined,
        ),
        tooltip: _isSearchOpen ? 'Cerrar búsqueda' : 'Buscar cuenta',
        onPressed: () {
          setState(() {
            _isSearchOpen = !_isSearchOpen;
            if (!_isSearchOpen) {
              _searchController.clear();
              _searchQuery = '';
            } else {
              _searchFocusNode.requestFocus();
            }
          });
        },
      ),
    ];

    nav.fab = FloatingActionButton(
      heroTag: 'accounts_add_fab',
      tooltip: 'Añadir cuenta',
      onPressed: _openAddAccount,
      child: const Icon(Icons.add),
    );
  }

  Future<void> _fetchAccounts({bool isRefresh = false}) async {
    if (_isLoading && !isRefresh) return;

    setState(() {
      if (isRefresh) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
      _error = null;
    });

    try {
      final FireflyIii api = context.read<FireflyService>().api;

      final List<Response<AccountArray>> responses =
          await Future.wait<Response<AccountArray>>(<
            Future<Response<AccountArray>>
          >[
            api.v1AccountsGet(type: AccountTypeFilter.assetAccount, limit: 100),
            api.v1AccountsGet(type: AccountTypeFilter.liabilities, limit: 100),
            api.v1AccountsGet(type: AccountTypeFilter.expense, limit: 100),
            api.v1AccountsGet(type: AccountTypeFilter.revenue, limit: 100),
          ]);

      final List<AccountRead> fetched = <AccountRead>[];
      for (final Response<AccountArray> resp in responses) {
        if (resp.isSuccessful && resp.body != null) {
          fetched.addAll(resp.body!.data);
        }
      }

      if (mounted) {
        setState(() {
          _allAccounts = fetched;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e, stackTrace) {
      log.severe('Error fetching accounts: $e', e, stackTrace);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _openAddAccount() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => const AccountAddEditDialog(),
    );
    if ((ok ?? false) && mounted) {
      await _fetchAccounts(isRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _allAccounts == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_error != null && (_allAccounts == null || _allAccounts!.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.error_outline_rounded,
                size: 52,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'No se pudieron cargar las cuentas',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: () => _fetchAccounts(),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final List<AccountRead> accounts = _allAccounts ?? <AccountRead>[];
    final CurrencyRead currency = context
        .read<FireflyService>()
        .defaultCurrency;

    final Widget body = _buildContent(context, accounts, currency);

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
          Expanded(child: body),
        ],
      );
    }

    return body;
  }

  Widget _buildContent(
    BuildContext context,
    List<AccountRead> accounts,
    CurrencyRead currency,
  ) {
    // Categorización de cuentas
    final List<AccountRead> assets = <AccountRead>[];
    final List<AccountRead> liabilities = <AccountRead>[];
    final List<AccountRead> others = <AccountRead>[];

    double totalAssets = 0.0;
    double totalLiabilities = 0.0; // deuda real pendiente (positiva)
    double totalReceivables = 0.0; // préstamos/créditos a favor (positivo)
    int activeCount = 0;
    int inactiveCount = 0;

    for (final AccountRead acc in accounts) {
      final bool isActive = acc.attributes.active ?? true;
      if (isActive) {
        activeCount++;
      } else {
        inactiveCount++;
      }

      final double bal =
          double.tryParse(acc.attributes.currentBalance ?? '0') ?? 0.0;
      final ShortAccountTypeProperty type = acc.attributes.type;

      if (type == ShortAccountTypeProperty.asset) {
        assets.add(acc);
        totalAssets += bal;
      } else if (type == ShortAccountTypeProperty.liability ||
          type == ShortAccountTypeProperty.liabilities) {
        liabilities.add(acc);
        if (acc.isCreditLiability) {
          totalReceivables += bal.abs();
        } else if (acc.isDebitLiability) {
          totalLiabilities += bal.abs();
        }
      } else {
        others.add(acc);
      }
    }

    // Filtrado por inactividad
    List<AccountRead> filterByActive(List<AccountRead> list) {
      if (_showInactive) return list;
      return list
          .where((AccountRead a) => a.attributes.active ?? true)
          .toList();
    }

    // Filtrado por texto de búsqueda
    List<AccountRead> filterBySearch(List<AccountRead> list) {
      if (_searchQuery.isEmpty) return list;
      return list.where((AccountRead a) {
        final String name = a.attributes.name.toLowerCase();
        final String iban = (a.attributes.iban ?? '').toLowerCase();
        final String number = (a.attributes.accountNumber ?? '').toLowerCase();
        final String notes = (a.attributes.notes ?? '').toLowerCase();
        return name.contains(_searchQuery) ||
            iban.contains(_searchQuery) ||
            number.contains(_searchQuery) ||
            notes.contains(_searchQuery);
      }).toList();
    }

    final List<AccountRead> filteredAssets = filterBySearch(
      filterByActive(assets),
    );
    final List<AccountRead> filteredLiabilities = filterBySearch(
      filterByActive(liabilities),
    );
    final List<AccountRead> filteredOthers = filterBySearch(
      filterByActive(others),
    );

    final List<AccountRead> allFiltered = <AccountRead>[
      ...filteredAssets,
      ...filteredLiabilities,
      ...filteredOthers,
    ];

    return RefreshIndicator(
      onRefresh: () => _fetchAccounts(isRefresh: true),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: <Widget>[
          // 1. Tarjeta resumen general de activos y pasivos
          _buildSummaryCard(
            context,
            currency: currency,
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities,
            totalReceivables: totalReceivables,
            activeCount: activeCount,
            inactiveCount: inactiveCount,
          ),
          const SizedBox(height: 16),

          // 2. Barra de búsqueda rápida si está abierta
          if (_isSearchOpen) ...<Widget>[
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, banco o IBAN...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 3. Selector de categoría (Todas, Activos, Pasivos, Otras)
          SegmentedButton<int>(
            segments: <ButtonSegment<int>>[
              ButtonSegment<int>(
                value: 0,
                label: Text('Todas (${allFiltered.length})'),
              ),
              ButtonSegment<int>(
                value: 1,
                label: Text('Activos (${filteredAssets.length})'),
              ),
              ButtonSegment<int>(
                value: 2,
                label: Text('Pasivos (${filteredLiabilities.length})'),
              ),
              ButtonSegment<int>(
                value: 3,
                label: Text('Otras (${filteredOthers.length})'),
              ),
            ],
            selected: <int>{_filterType},
            onSelectionChanged: (Set<int> newSelection) {
              setState(() {
                _filterType = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 12),

          // 4. Chip para ver inactivas cuando existan
          if (inactiveCount > 0) ...<Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                FilterChip(
                  label: Text('Inactivas ($inactiveCount)'),
                  selected: _showInactive,
                  onSelected: (bool selected) {
                    setState(() {
                      _showInactive = selected;
                    });
                  },
                  avatar: Icon(
                    _showInactive
                        ? Icons.visibility
                        : Icons.visibility_off_outlined,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // 5. Lista de cuentas según filtro
          if (_filterType == 0) ...<Widget>[
            if (allFiltered.isEmpty)
              _buildEmptyState(context)
            else ...<Widget>[
              if (filteredAssets.isNotEmpty) ...<Widget>[
                _buildSectionHeader(
                  context,
                  'Cuentas de Activo',
                  filteredAssets.length,
                ),
                const SizedBox(height: 8),
                ...filteredAssets.map(
                  (AccountRead a) => _buildAccountItem(context, a, currency),
                ),
                const SizedBox(height: 16),
              ],
              if (filteredLiabilities.isNotEmpty) ...<Widget>[
                _buildSectionHeader(
                  context,
                  'Tarjetas y Pasivos',
                  filteredLiabilities.length,
                ),
                const SizedBox(height: 8),
                ...filteredLiabilities.map(
                  (AccountRead a) => _buildAccountItem(context, a, currency),
                ),
                const SizedBox(height: 16),
              ],
              if (filteredOthers.isNotEmpty) ...<Widget>[
                _buildSectionHeader(
                  context,
                  'Otras Cuentas',
                  filteredOthers.length,
                ),
                const SizedBox(height: 8),
                ...filteredOthers.map(
                  (AccountRead a) => _buildAccountItem(context, a, currency),
                ),
              ],
            ],
          ] else if (_filterType == 1) ...<Widget>[
            if (filteredAssets.isEmpty)
              _buildEmptyState(context)
            else
              ...filteredAssets.map(
                (AccountRead a) => _buildAccountItem(context, a, currency),
              ),
          ] else if (_filterType == 2) ...<Widget>[
            if (filteredLiabilities.isEmpty)
              _buildEmptyState(context)
            else
              ...filteredLiabilities.map(
                (AccountRead a) => _buildAccountItem(context, a, currency),
              ),
          ] else ...<Widget>[
            if (filteredOthers.isEmpty)
              _buildEmptyState(context)
            else
              ...filteredOthers.map(
                (AccountRead a) => _buildAccountItem(context, a, currency),
              ),
          ],
          const SizedBox(height: 80), // Margen inferior para el FAB
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required CurrencyRead currency,
    required double totalAssets,
    required double totalLiabilities,
    required double totalReceivables,
    required int activeCount,
    required int inactiveCount,
  }) {
    final double netWorth = totalAssets - totalLiabilities + totalReceivables;
    final Color netColor = netWorth < 0
        ? FtColors.coralOf(context)
        : (netWorth > 0
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
                        'ACTIVOS TOTALES',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: FtColors.incomeOf(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currency.fmt(totalAssets, context: context),
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
                        'DEUDA / PASIVOS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: FtColors.coralOf(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currency.fmt(totalLiabilities, context: context),
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
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'PATRIMONIO NETO',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currency.fmt(netWorth, context: context),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.account_balance,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$activeCount activas',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
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

  Widget _buildSectionHeader(BuildContext context, String title, int count) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountItem(
    BuildContext context,
    AccountRead account,
    CurrencyRead currency,
  ) {
    final double balance =
        double.tryParse(account.attributes.currentBalance ?? '0') ?? 0.0;
    final ShortAccountTypeProperty type = account.attributes.type;
    final bool isActive = account.attributes.active ?? true;

    Color balanceColor;
    if (type == ShortAccountTypeProperty.liability ||
        type == ShortAccountTypeProperty.liabilities) {
      if (account.isCreditLiability) {
        balanceColor = FtColors.incomeOf(context);
      } else if (account.isDebitLiability) {
        balanceColor = FtColors.coralOf(context);
      } else {
        balanceColor = balance != 0
            ? FtColors.coralOf(context)
            : Theme.of(context).colorScheme.onSurface;
      }
    } else if (type == ShortAccountTypeProperty.asset) {
      balanceColor = balance > 0
          ? FtColors.incomeOf(context)
          : (balance < 0
                ? FtColors.coralOf(context)
                : Theme.of(context).colorScheme.onSurface);
    } else {
      balanceColor = Theme.of(context).colorScheme.onSurface;
    }

    String? subtitleText;
    if (account.attributes.iban != null &&
        account.attributes.iban!.isNotEmpty) {
      final String iban = account.attributes.iban!;
      if (iban.length > 8) {
        subtitleText =
            '${iban.substring(0, 4)} ... ${iban.substring(iban.length - 4)}';
      } else {
        subtitleText = iban;
      }
    } else if (account.attributes.accountRole != null) {
      subtitleText = account.attributes.accountRole!.friendlyName(context);
    } else if (account.attributes.accountNumber != null &&
        account.attributes.accountNumber!.isNotEmpty) {
      subtitleText = account.attributes.accountNumber;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => AccountTXpage(
                      account: account,
                      nameUpdateFunc: (_) => _fetchAccounts(isRefresh: true),
                    ),
                  ),
                )
                .then((_) => _fetchAccounts(isRefresh: true));
          },
          onLongPress: () => _openEditAccount(account),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                BankLogoBadge(
                  accountName: account.attributes.name,
                  iban: account.attributes.iban,
                  type: account.attributes.type,
                  size: 42,
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
                              account.attributes.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: !isActive
                                        ? Theme.of(context).disabledColor
                                        : null,
                                  ),
                            ),
                          ),
                          if (!isActive) ...<Widget>[
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
                                'Inactiva',
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
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              account.attributes.accountRole != null
                                  ? account.attributes.accountRole!
                                        .friendlyName(context)
                                  : (type == ShortAccountTypeProperty.asset
                                        ? 'Activo'
                                        : (type ==
                                                      ShortAccountTypeProperty
                                                          .liability ||
                                                  type ==
                                                      ShortAccountTypeProperty
                                                          .liabilities
                                              ? 'Pasivo'
                                              : type.name)),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (subtitleText != null &&
                              subtitleText !=
                                  account.attributes.accountRole?.friendlyName(
                                    context,
                                  )) ...<Widget>[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                subtitleText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      currency.fmt(balance, context: context),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: balanceColor,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    if (account.attributes.interest != null &&
                        account.attributes.interest!.isNotEmpty &&
                        account.attributes.interest != '0') ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        '${account.attributes.interest}% TAE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: FtColors.coralOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (String action) {
                    if (action == 'tx') {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) => AccountTXpage(
                                account: account,
                                nameUpdateFunc: (_) =>
                                    _fetchAccounts(isRefresh: true),
                              ),
                            ),
                          )
                          .then((_) => _fetchAccounts(isRefresh: true));
                    } else if (action == 'edit') {
                      _openEditAccount(account);
                    }
                  },
                  itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'tx',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.receipt_long_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Ver movimientos'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Editar cuenta'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditAccount(AccountRead account) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AccountAddEditDialog(account: account),
    );
    if ((ok ?? false) && mounted) {
      await _fetchAccounts(isRefresh: true);
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 56,
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No se encontraron cuentas con "$_searchQuery"'
                  : 'No hay cuentas en esta categoría',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            if (_searchQuery.isNotEmpty)
              FilledButton.tonal(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
                child: const Text('Limpiar búsqueda'),
              )
            else
              FilledButton.tonalIcon(
                onPressed: _openAddAccount,
                icon: const Icon(Icons.add),
                label: const Text('Crear cuenta'),
              ),
          ],
        ),
      ),
    );
  }
}

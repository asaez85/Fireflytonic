import 'package:animations/animations.dart';
import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/home/transactions.dart';
import 'package:waterflyiii/pages/home/transactions/filter.dart';
import 'package:waterflyiii/widgets/fabs.dart';

class HomeBalance extends StatefulWidget {
  const HomeBalance({super.key});

  @override
  State<HomeBalance> createState() => _HomeBalanceState();
}

class _HomeBalanceState extends State<HomeBalance>
    with AutomaticKeepAliveClientMixin {
  final Logger log = Logger("Pages.Home.Balance");

  Future<AccountArray> _fetchAccounts() async {
    final FireflyIii api = context.read<FireflyService>().api;

    final Response<AccountArray> respAccounts = await api.v1AccountsGet(
      type: .assetAccount,
    );
    apiThrowErrorIfEmpty(respAccounts, mounted ? context : null);

    return Future<AccountArray>.value(respAccounts.body);
  }

  AccountArray? _cachedAccounts;
  bool _isRefreshing = false;

  Future<void> _refreshStats() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    try {
      final AccountArray accounts = await _fetchAccounts();
      if (mounted) {
        setState(() {
          _cachedAccounts = accounts;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    log.finest(() => "build()");

    final Widget content;
    if (_cachedAccounts != null) {
      content = _buildAccountList(_cachedAccounts!);
    } else {
      content = FutureBuilder<AccountArray>(
        future: _fetchAccounts(),
        builder: (BuildContext context, AsyncSnapshot<AccountArray> snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData &&
              snapshot.data != null) {
            _cachedAccounts = snapshot.data;
            return _buildAccountList(snapshot.data!);
          } else if (snapshot.hasError) {
            log.severe(
              "error fetching accounts",
              snapshot.error,
              snapshot.stackTrace,
            );
            return Text(snapshot.error!.toString());
          } else {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }
        },
      );
    }

    final Widget refreshList = RefreshIndicator.adaptive(
      onRefresh: _refreshStats,
      child: content,
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
          Expanded(child: refreshList),
        ],
      );
    }
    return refreshList;
  }

  Widget _buildAccountList(AccountArray accounts) {
    return ListView(
      cacheExtent: 1000,
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...accounts.data.map((AccountRead account) {
          if (!(account.attributes.active ?? false)) {
            return const SizedBox.shrink();
          }
          final double balance =
              double.tryParse(account.attributes.currentBalance ?? "") ?? 0.0;
          final CurrencyRead currency = CurrencyRead(
            id: account.attributes.currencyId ?? "",
            type: "currencies",
            attributes: CurrencyProperties(
              code: account.attributes.currencyCode ?? "",
              name: "",
              symbol: account.attributes.currencySymbol ?? "",
              decimalPlaces: account.attributes.currencyDecimalPlaces,
            ),
          );

          return OpenContainer(
            openBuilder: (BuildContext context, Function closedContainer) =>
                Scaffold(
                  appBar: AppBar(title: Text(account.attributes.name)),
                  floatingActionButton: NewTransactionFab(
                    context: context,
                    accountId: account.id,
                  ),
                  body: HomeTransactions(
                    filters: TransactionFilters(account: account),
                  ),
                ),
            openColor: Theme.of(context).cardColor,
            closedColor: Theme.of(context).cardColor,
            closedShape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
            closedElevation: 0,
            closedBuilder: (BuildContext context, Function openContainer) =>
                ListTile(
                  title: Text(account.attributes.name),
                  subtitle: Text(
                    account.attributes.accountRole?.friendlyName(context) ??
                        S.of(context).generalUnknown,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  isThreeLine: false,
                  trailing: RichText(
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: <InlineSpan>[
                        TextSpan(
                          text: currency.fmt(balance, context: context),
                          style: Theme.of(context).textTheme.titleMedium!
                              .copyWith(
                                color: (balance < 0)
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontFeatures: const <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                        const TextSpan(text: "\n"),
                        TextSpan(
                          text: account.attributes.lastActivity != null
                              ? DateFormat.yMd().add_Hms().format(
                                  account.attributes.lastActivity!.toLocal(),
                                )
                              : S.of(context).generalNever,
                        ),
                      ],
                    ),
                  ),
                  onTap: () => openContainer(),
                ),
          );
        }),
      ],
    );
  }
}

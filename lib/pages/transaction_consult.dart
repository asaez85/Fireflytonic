import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/l10n/app_localizations.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/transaction.dart';
import 'package:waterflyiii/pages/transaction/category_select.dart';
import 'package:waterflyiii/settings.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/timezonehandler.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';
import 'package:waterflyiii/auth.dart';

class TransactionConsultPage extends StatefulWidget {
  final TransactionRead transaction;

  const TransactionConsultPage({super.key, required this.transaction});

  @override
  State<TransactionConsultPage> createState() => _TransactionConsultPageState();
}

class _TransactionConsultPageState extends State<TransactionConsultPage> {
  late TransactionRead _transaction;
  bool _isUpdating = false;
  bool _hasBeenUpdated = false;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
  }

  TransactionSplitUpdate _txFilterSameFields(
    TransactionSplitUpdate txU,
    TransactionSplit tx,
  ) {
    return txU.copyWith(
      amount: tx.amount == txU.amount ? null : txU.amount,
      foreignAmount: tx.foreignAmount == txU.foreignAmount
          ? null
          : txU.foreignAmount,
      foreignCurrencyId: tx.foreignCurrencyId == txU.foreignCurrencyId
          ? null
          : txU.foreignCurrencyId,
      sourceName: tx.sourceName == txU.sourceName ? null : txU.sourceName,
      destinationName: tx.destinationName == txU.destinationName
          ? null
          : txU.destinationName,
    );
  }

  Future<void> _updateCategory(String newCategoryName) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final FireflyIii api = context.read<FireflyService>().api;
      final String id = _transaction.id;

      final List<TransactionSplitUpdate> txS = <TransactionSplitUpdate>[];
      for (int i = 0; i < _transaction.attributes.transactions.length; i++) {
        final TransactionSplit oldSplit =
            _transaction.attributes.transactions[i];

        final TransactionSplitUpdate txSs = TransactionSplitUpdate(
          amount: oldSplit.amount,
          billId: oldSplit.billId ?? "0",
          budgetName: oldSplit.budgetName ?? "",
          categoryName: newCategoryName,
          date: oldSplit.date,
          description: oldSplit.description,
          destinationName: oldSplit.destinationName ?? "",
          foreignAmount: oldSplit.foreignCurrencyId != null
              ? oldSplit.foreignAmount ?? "0"
              : "0",
          foreignCurrencyId: oldSplit.foreignCurrencyId,
          notes: oldSplit.notes ?? "",
          order: i,
          sourceName: oldSplit.sourceName ?? "",
          tags: oldSplit.tags ?? <String>[],
          transactionJournalId: oldSplit.transactionJournalId,
          type: oldSplit.type,
          reconciled: oldSplit.reconciled ?? false,
        );

        txS.add(_txFilterSameFields(txSs, oldSplit));
      }

      final TransactionUpdate txUpdate = TransactionUpdate(
        groupTitle: _transaction.attributes.groupTitle,
        transactions: txS,
      );

      final Response<TransactionSingle> resp = await api.v1TransactionsIdPut(
        id: id,
        body: txUpdate,
      );
      if (resp.isSuccessful && resp.body != null) {
        await _reloadTransaction();
      } else {
        setState(() {
          _isUpdating = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Error al recategorizar")));
      }
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Error al recategorizar")));
    }
  }

  Future<void> _reloadTransaction() async {
    setState(() {
      _isUpdating = true;
    });
    try {
      final FireflyIii api = context.read<FireflyService>().api;
      final Response<TransactionSingle> reloadResp = await api
          .v1TransactionsIdGet(id: _transaction.id);
      if (reloadResp.isSuccessful && reloadResp.body != null) {
        setState(() {
          _transaction = reloadResp.body!.data;
          _hasBeenUpdated = true;
          _isUpdating = false;
        });
      } else {
        setState(() {
          _isUpdating = false;
        });
      }
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<TransactionSplit> splits = _transaction.attributes.transactions;
    if (splits.isEmpty) {
      return Scaffold(
        appBar: AppBar(elevation: 0),
        body: const Center(child: Text("Error: No transaction data")),
      );
    }
    final TransactionSplit t = splits.first;

    // Determine type & colors
    final bool isIncome = t.type == TransactionTypeProperty.deposit;
    final Color amountColor = isIncome
        ? FtColors.incomeOf(context)
        : Theme.of(context).colorScheme.onSurface;

    // Amount
    final double amount = double.tryParse(t.amount) ?? 0.0;
    final CurrencyRead currency = CurrencyRead(
      id: t.currencyId ?? "0",
      type: "currencies",
      attributes: CurrencyProperties(
        code: t.currencyCode ?? "",
        name: t.currencyName ?? "",
        symbol: t.currencySymbol ?? "",
        decimalPlaces: t.currencyDecimalPlaces,
      ),
    );

    // Date
    final TimeZoneHandler tzHandler = context.read<FireflyService>().tzHandler;
    final DateTime date = tzHandler.sTime(t.date).toLocal();
    final String dateString = DateFormat.yMMMMEEEEd().format(date);

    // Category
    final String category = t.categoryName ?? "";
    final bool hasCategory = category.isNotEmpty;
    final Color catColor = hasCategory
        ? FtColors.categoryColor(category, context: context)
        : t.type.colorOf(context);
    final IconData catIcon = hasCategory
        ? FtCategoryIcon.forName(category)
        : t.type.icon;

    Widget bodyContent = Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Amount
                Text(
                  (isIncome ? "+" : "-") +
                      currency.fmt(amount, context: context),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  t.description,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),

                // Date
                Text(
                  dateString,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // Account
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.account_balance,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isIncome
                            ? (t.destinationName ?? "")
                            : (t.sourceName ?? ""),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(height: 1),

                // Category
                InkWell(
                  onTap: _isUpdating
                      ? null
                      : () async {
                          final String? newCategory =
                              await Navigator.push<String>(
                                context,
                                MaterialPageRoute<String>(
                                  builder: (BuildContext context) =>
                                      CategorySelectPage(
                                        selectedCategoryName: category,
                                      ),
                                ),
                              );
                          if (newCategory != null && newCategory != category) {
                            await _updateCategory(newCategory);
                          }
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      children: <Widget>[
                        FtCategoryIconWidget(
                          icon: catIcon,
                          color: catColor,
                          padding: 8,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            hasCategory
                                ? category
                                : S.of(context).generalUnknown,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),

                // Notes & Tags
                if ((t.notes != null && t.notes!.isNotEmpty) ||
                    (t.tags != null && t.tags!.isNotEmpty)) ...<Widget>[
                  const SizedBox(height: 24),
                  if (t.notes != null && t.notes!.isNotEmpty) ...<Widget>[
                    Text(
                      t.notes!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (t.tags != null && t.tags!.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: t.tags!
                          .map(
                            (String tag) => Chip(
                              label: Text(tag),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHigh,
                              side: BorderSide.none,
                            ),
                          )
                          .toList(),
                    ),
                ],
              ],
            ),
          ),
        ),

        // Bottom Action Buttons
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isUpdating
                        ? null
                        : () async {
                            final String? newCategory =
                                await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute<String>(
                                    builder: (BuildContext context) =>
                                        CategorySelectPage(
                                          selectedCategoryName: category,
                                        ),
                                  ),
                                );
                            if (newCategory != null &&
                                newCategory != category) {
                              await _updateCategory(newCategory);
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text("Recategorizar"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text("Dividir"),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isUpdating
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<bool>(
                              builder: (BuildContext context) =>
                                  TransactionPage(transaction: _transaction),
                            ),
                          ).then((bool? modified) {
                            if (modified ?? false) {
                              _reloadTransaction();
                            }
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                    padding: const EdgeInsets.all(16),
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.edit),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (_isUpdating) {
      bodyContent = Stack(
        children: <Widget>[
          bodyContent,
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black12,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (!_isUpdating) {
          Navigator.pop(context, _hasBeenUpdated);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (!_isUpdating) {
                Navigator.pop(context, _hasBeenUpdated);
              }
            },
          ),
          actions: <Widget>[
            IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
            IconButton(
              icon: Icon(
                context.watch<SettingsProvider>().hideAmounts
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              tooltip: context.watch<SettingsProvider>().hideAmounts
                  ? 'Mostrar importes'
                  : 'Ocultar importes',
              onPressed: () {
                final SettingsProvider settings = context
                    .read<SettingsProvider>();
                settings.hideAmounts = !settings.hideAmounts;
              },
            ),
          ],
        ),
        body: SafeArea(child: bodyContent),
      ),
    );
  }
}

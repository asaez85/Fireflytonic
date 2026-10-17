import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/bank_logo_badge.dart';

export 'package:waterflyiii/widgets/bank_logo_badge.dart';

class AccountsFilterSheet extends StatefulWidget {
  final List<AccountRead> initialSelected;

  const AccountsFilterSheet({
    super.key,
    this.initialSelected = const <AccountRead>[],
  });

  static Future<List<AccountRead>?> show(
    BuildContext context, {
    List<AccountRead> initialSelected = const <AccountRead>[],
  }) {
    return showModalBottomSheet<List<AccountRead>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) =>
          AccountsFilterSheet(initialSelected: initialSelected),
    );
  }

  @override
  State<AccountsFilterSheet> createState() => _AccountsFilterSheetState();
}

class _AccountsFilterSheetState extends State<AccountsFilterSheet> {
  List<AccountRead> _allAccounts = <AccountRead>[];
  final Map<String, AccountRead> _selectedAccounts = <String, AccountRead>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    for (AccountRead a in widget.initialSelected) {
      _selectedAccounts[a.id] = a;
    }
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    try {
      final FireflyIii api = context.read<FireflyService>().api;
      final (
        Response<AccountArray> assetResp,
        Response<AccountArray> liabilityResp,
      ) = await (
        api.v1AccountsGet(type: .assetAccount),
        api.v1AccountsGet(type: .liabilities),
      ).wait;

      final List<AccountRead> accounts = <AccountRead>[];
      if (assetResp.isSuccessful && assetResp.body != null) {
        accounts.addAll(assetResp.body!.data);
      }
      if (liabilityResp.isSuccessful && liabilityResp.body != null) {
        accounts.addAll(liabilityResp.body!.data);
      }

      if (mounted) {
        setState(() {
          _allAccounts = accounts;
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

  String _formatAccountTitle(AccountRead acc) {
    final String? iban = acc.attributes.iban;
    final String? accNumber = acc.attributes.accountNumber;
    String digits = "";

    if (iban != null && iban.length >= 4) {
      digits = iban.substring(iban.length - 4);
    } else if (accNumber != null && accNumber.length >= 4) {
      digits = accNumber.substring(accNumber.length - 4);
    }

    if (digits.isNotEmpty) {
      return "($digits) · ${acc.attributes.name}";
    }
    return acc.attributes.name;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final double sheetHeight = MediaQuery.of(context).size.height * 0.85;

    final bool allSelected =
        _allAccounts.isNotEmpty &&
        _selectedAccounts.length == _allAccounts.length;

    final String syncTime =
        "Hoy, ${DateFormat('HH:mm').format(DateTime.now())}h";

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
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: "Seleccionar todos" / "Buscar en todas mis cuentas y tarjetas"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        "Seleccionar todos",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: isDark ? Colors.white : FtColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Buscar en todas mis cuentas y tarjetas",
                        style: TextStyle(
                          color: isDark
                              ? FtColors.textMutedDark
                              : FtColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: allSelected,
                  activeThumbColor: FtColors.coralOf(context),
                  onChanged: (bool value) {
                    setState(() {
                      _selectedAccounts.clear();
                      if (value) {
                        for (AccountRead a in _allAccounts) {
                          _selectedAccounts[a.id] = a;
                        }
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Accounts List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allAccounts.isEmpty
                ? Center(
                    child: Text(
                      "No se encontraron cuentas",
                      style: TextStyle(
                        color: isDark
                            ? FtColors.textMutedDark
                            : FtColors.textMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _allAccounts.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const Divider(indent: 76, height: 1, thickness: 0.5),
                    itemBuilder: (BuildContext context, int index) {
                      final AccountRead acc = _allAccounts[index];
                      final bool isSelected = _selectedAccounts.containsKey(
                        acc.id,
                      );

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: BankLogoBadge(
                          accountName: acc.attributes.name,
                          iban: acc.attributes.iban,
                          type: acc.attributes.type,
                        ),
                        title: Text(
                          _formatAccountTitle(acc),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.sync,
                              size: 14,
                              color: Color(0xFF1D6FEE),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              syncTime,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark
                                    ? FtColors.textMutedDark
                                    : FtColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        trailing: Switch.adaptive(
                          value: isSelected,
                          activeThumbColor: FtColors.coralOf(context),
                          onChanged: (bool value) {
                            setState(() {
                              if (value) {
                                _selectedAccounts[acc.id] = acc;
                              } else {
                                _selectedAccounts.remove(acc.id);
                              }
                            });
                          },
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedAccounts.remove(acc.id);
                            } else {
                              _selectedAccounts[acc.id] = acc;
                            }
                          });
                        },
                      );
                    },
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
                if (_selectedAccounts.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedAccounts.clear();
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
                    Navigator.pop(context, _selectedAccounts.values.toList());
                  },
                  child: Text(
                    _selectedAccounts.isEmpty
                        ? "Cerrar"
                        : "Aplicar (${_selectedAccounts.length})",
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
}

import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/pages/home/transactions/services/csv_export_service.dart';
import 'package:waterflyiii/pages/home/transactions/widgets/accounts_filter_sheet.dart';
import 'package:waterflyiii/theme.dart';

class ExportTransactionsPage extends StatefulWidget {
  const ExportTransactionsPage({super.key});

  @override
  State<ExportTransactionsPage> createState() => _ExportTransactionsPageState();
}

class _ExportTransactionsPageState extends State<ExportTransactionsPage> {
  late DateTime _startDate;
  late DateTime _endDate;
  DateTime? _oldestDate;
  bool _isLoadingOldestDate = true;

  bool _isLoadingAccounts = true;
  final List<AccountRead> _assetAccounts = <AccountRead>[];
  final List<AccountRead> _liabilityAccounts = <AccountRead>[];
  final Map<String, AccountRead> _accountsMap = <String, AccountRead>{};
  final Set<String> _selectedAccountIds = <String>{};

  bool _isExporting = false;
  String _exportStatus = '';

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final FireflyIii api = context.read<FireflyService>().api;
    await Future.wait(<Future<void>>[
      _fetchOldestDate(api),
      _fetchAccounts(api),
    ]);
  }

  Future<void> _fetchOldestDate(FireflyIii api) async {
    try {
      final DateTime? oldest =
          await CsvExportService.fetchOldestTransactionDate(api);
      if (mounted) {
        setState(() {
          _oldestDate = oldest;
          _isLoadingOldestDate = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingOldestDate = false;
        });
      }
    }
  }

  Future<void> _fetchAccounts(FireflyIii api) async {
    try {
      final (
        Response<AccountArray> assetResp,
        Response<AccountArray> liabilityResp,
      ) = await (
        api.v1AccountsGet(type: AccountTypeFilter.assetAccount),
        api.v1AccountsGet(type: AccountTypeFilter.liabilities),
      ).wait;

      final List<AccountRead> assets = <AccountRead>[];
      final List<AccountRead> liabilities = <AccountRead>[];
      final Map<String, AccountRead> map = <String, AccountRead>{};
      final Set<String> selected = <String>{};

      if (assetResp.isSuccessful && assetResp.body != null) {
        for (final AccountRead acc in assetResp.body!.data) {
          assets.add(acc);
          map[acc.id] = acc;
          selected.add(acc.id);
        }
      }

      if (liabilityResp.isSuccessful && liabilityResp.body != null) {
        for (final AccountRead acc in liabilityResp.body!.data) {
          liabilities.add(acc);
          map[acc.id] = acc;
          selected.add(acc.id);
        }
      }

      if (mounted) {
        setState(() {
          _assetAccounts.clear();
          _assetAccounts.addAll(assets);
          _liabilityAccounts.clear();
          _liabilityAccounts.addAll(liabilities);
          _accountsMap.clear();
          _accountsMap.addAll(map);
          _selectedAccountIds.clear();
          _selectedAccountIds.addAll(selected);
          _isLoadingAccounts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingAccounts = false;
        });
      }
    }
  }

  String _formatAccountTitle(AccountRead acc) {
    final String? iban = acc.attributes.iban;
    final String? accNumber = acc.attributes.accountNumber;
    String digits = '';

    if (iban != null && iban.length >= 4) {
      digits = iban.substring(iban.length - 4);
    } else if (accNumber != null && accNumber.length >= 4) {
      digits = accNumber.substring(accNumber.length - 4);
    }

    if (digits.isNotEmpty) {
      return '($digits) · ${acc.attributes.name}';
    }
    return acc.attributes.name;
  }

  Future<void> _selectStartDate() async {
    final DateTime firstPossible = _oldestDate ?? DateTime(2000);
    final DateTime lastPossible = _endDate;
    final DateTime initial = _startDate.isBefore(firstPossible)
        ? firstPossible
        : (_startDate.isAfter(lastPossible) ? lastPossible : _startDate);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstPossible,
      lastDate: lastPossible,
      helpText: 'Selecciona fecha desde',
    );

    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime firstPossible = _startDate;
    final DateTime lastPossible = DateTime.now();
    final DateTime initial = _endDate.isBefore(firstPossible)
        ? firstPossible
        : (_endDate.isAfter(lastPossible) ? lastPossible : _endDate);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstPossible,
      lastDate: lastPossible,
      helpText: 'Selecciona fecha hasta',
    );

    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _startExport() async {
    if (_selectedAccountIds.isEmpty || _isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
      _exportStatus = 'Consultando movimientos...';
    });

    try {
      final FireflyIii api = context.read<FireflyService>().api;

      final List<TransactionSplit> splits =
          await CsvExportService.fetchTransactionsForExport(
            api: api,
            startDate: _startDate,
            endDate: _endDate,
            selectedAccountIds: _selectedAccountIds,
            onProgress: (int current, int? total) {
              if (mounted) {
                setState(() {
                  if (total != null && total > 0) {
                    _exportStatus = 'Descargando página $current de $total...';
                  } else {
                    _exportStatus = 'Descargando página $current...';
                  }
                });
              }
            },
          );

      if (!mounted) return;

      setState(() {
        _exportStatus = 'Generando informe CSV...';
      });

      final String csvString = CsvExportService.generateCsv(
        splits: splits,
        accountsMap: _accountsMap,
        selectedAccountIds: _selectedAccountIds,
      );

      final String startStr = DateFormat('yyyyMMdd').format(_startDate);
      final String endStr = DateFormat('yyyyMMdd').format(_endDate);
      final String fileName = 'movimientos_${startStr}_$endStr.csv';

      final String? savedPath = await CsvExportService.saveCsv(
        csvContent: csvString,
        fileName: fileName,
      );

      if (!mounted) return;

      setState(() {
        _isExporting = false;
        _exportStatus = '';
      });

      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Informe CSV generado con ${splits.length} movimientos.',
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Abrir',
              textColor: FtColors.coralOf(context),
              onPressed: () async {
                await OpenFile.open(savedPath);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _exportStatus = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar CSV: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final int totalAccounts = _assetAccounts.length + _liabilityAccounts.length;
    final bool allSelected =
        totalAccounts > 0 && _selectedAccountIds.length == totalAccounts;

    final DateFormat dateDisplayFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: isDark ? FtColors.bgDark : FtColors.bg,
      appBar: AppBar(
        title: Text(
          'Descargar movimientos',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoadingAccounts
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    children: <Widget>[
                      // Rango de fechas
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _buildDateCard(
                              context: context,
                              label: 'Desde',
                              dateStr: dateDisplayFormat.format(_startDate),
                              onTap: _isExporting ? null : _selectStartDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateCard(
                              context: context,
                              label: 'Hasta',
                              dateStr: dateDisplayFormat.format(_endDate),
                              onTap: _isExporting ? null : _selectEndDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Texto informativo fecha más antigua
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _isLoadingOldestDate
                              ? 'Consultando fecha inicial...'
                              : _oldestDate != null
                              ? 'Tienes información financiera desde ${dateDisplayFormat.format(_oldestDate!)}. Selecciona a partir de esta fecha.'
                              : 'Selecciona el rango de fechas para exportar.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? FtColors.textMutedDark
                                : FtColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Cabecera selector global
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? FtColors.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? FtColors.borderDark
                                : FtColors.border,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Activar sección / Seleccionar todas',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      color: isDark
                                          ? Colors.white
                                          : FtColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Incluir todas las cuentas y tarjetas',
                                    style: TextStyle(
                                      color: isDark
                                          ? FtColors.textMutedDark
                                          : FtColors.textMuted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: allSelected,
                              activeThumbColor: FtColors.coralOf(context),
                              onChanged: _isExporting
                                  ? null
                                  : (bool value) {
                                      setState(() {
                                        if (value) {
                                          _selectedAccountIds.addAll(
                                            _accountsMap.keys,
                                          );
                                        } else {
                                          _selectedAccountIds.clear();
                                        }
                                      });
                                    },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cuentas personales
                      if (_assetAccounts.isNotEmpty) ...<Widget>[
                        _buildSectionHeader(
                          context: context,
                          title: 'Cuentas personales',
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? FtColors.surfaceDark : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? FtColors.borderDark
                                  : FtColors.border,
                            ),
                          ),
                          child: Column(
                            children: List<Widget>.generate(
                              _assetAccounts.length,
                              (int index) {
                                final AccountRead acc = _assetAccounts[index];
                                final bool isSelected = _selectedAccountIds
                                    .contains(acc.id);
                                final bool isLast =
                                    index == _assetAccounts.length - 1;
                                return Column(
                                  children: <Widget>[
                                    _buildAccountTile(
                                      context: context,
                                      account: acc,
                                      isSelected: isSelected,
                                      onChanged: _isExporting
                                          ? null
                                          : (bool val) {
                                              setState(() {
                                                if (val) {
                                                  _selectedAccountIds.add(
                                                    acc.id,
                                                  );
                                                } else {
                                                  _selectedAccountIds.remove(
                                                    acc.id,
                                                  );
                                                }
                                              });
                                            },
                                    ),
                                    if (!isLast)
                                      Divider(
                                        height: 1,
                                        thickness: 0.5,
                                        indent: 72,
                                        color: isDark
                                            ? FtColors.borderDark
                                            : FtColors.border,
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Tarjetas de crédito
                      if (_liabilityAccounts.isNotEmpty) ...<Widget>[
                        _buildSectionHeader(
                          context: context,
                          title: 'Tarjetas de crédito',
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? FtColors.surfaceDark : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? FtColors.borderDark
                                  : FtColors.border,
                            ),
                          ),
                          child: Column(
                            children: List<Widget>.generate(
                              _liabilityAccounts.length,
                              (int index) {
                                final AccountRead acc =
                                    _liabilityAccounts[index];
                                final bool isSelected = _selectedAccountIds
                                    .contains(acc.id);
                                final bool isLast =
                                    index == _liabilityAccounts.length - 1;
                                return Column(
                                  children: <Widget>[
                                    _buildAccountTile(
                                      context: context,
                                      account: acc,
                                      isSelected: isSelected,
                                      onChanged: _isExporting
                                          ? null
                                          : (bool val) {
                                              setState(() {
                                                if (val) {
                                                  _selectedAccountIds.add(
                                                    acc.id,
                                                  );
                                                } else {
                                                  _selectedAccountIds.remove(
                                                    acc.id,
                                                  );
                                                }
                                              });
                                            },
                                    ),
                                    if (!isLast)
                                      Divider(
                                        height: 1,
                                        thickness: 0.5,
                                        indent: 72,
                                        color: isDark
                                            ? FtColors.borderDark
                                            : FtColors.border,
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),

                // Barra de acción inferior fija
                Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 12,
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? FtColors.surfaceDark : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? FtColors.borderDark : FtColors.border,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: FtColors.coralOf(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: (_selectedAccountIds.isEmpty || _isExporting)
                          ? null
                          : _startExport,
                      child: _isExporting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _exportStatus,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Descargar CSV',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDateCard({
    required BuildContext context,
    required String label,
    required String dateStr,
    required VoidCallback? onTap,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? FtColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? FtColors.borderDark : FtColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? FtColors.textMutedDark : FtColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  dateStr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? Colors.white : FtColors.navy,
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: FtColors.coralOf(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: isDark ? Colors.white70 : FtColors.navySoft,
        ),
      ),
    );
  }

  Widget _buildAccountTile({
    required BuildContext context,
    required AccountRead account,
    required bool isSelected,
    required ValueChanged<bool>? onChanged,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: <Widget>[
          BankLogoBadge(
            accountName: account.attributes.name,
            iban: account.attributes.iban,
            type: account.attributes.type,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _formatAccountTitle(account),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (account.attributes.currentBalance != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    'Saldo: ${account.attributes.currentBalance} ${account.attributes.currencySymbol ?? ''}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? FtColors.textMutedDark
                          : FtColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: isSelected,
            activeThumbColor: FtColors.coralOf(context),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

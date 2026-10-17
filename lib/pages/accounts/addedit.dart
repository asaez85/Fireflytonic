import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/extensions.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/widgets/bank_logo_badge.dart';

final Logger log = Logger('Pages.Accounts.AddEdit');

class AccountAddEditDialog extends StatefulWidget {
  const AccountAddEditDialog({super.key, this.account});

  final AccountRead? account;

  @override
  State<AccountAddEditDialog> createState() => _AccountAddEditDialogState();
}

class _AccountAddEditDialogState extends State<AccountAddEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _ibanController;
  late TextEditingController _bicController;
  late TextEditingController _accountNumberController;
  late TextEditingController _openingBalanceController;
  late TextEditingController _interestController;
  late TextEditingController _notesController;

  late ShortAccountTypeProperty _type;
  AccountRoleProperty? _role;
  LiabilityTypeProperty? _liabilityType;
  LiabilityDirectionProperty? _liabilityDirection;
  InterestPeriodProperty? _interestPeriod;
  bool _active = true;
  bool _isSaving = false;
  bool _isDeleting = false;

  String _previewName = '';
  String _previewIban = '';

  @override
  void initState() {
    super.initState();

    final AccountRead? acc = widget.account;
    _nameController = TextEditingController(text: acc?.attributes.name ?? '');
    _ibanController = TextEditingController(text: acc?.attributes.iban ?? '');
    _bicController = TextEditingController(text: acc?.attributes.bic ?? '');
    _accountNumberController = TextEditingController(
      text: acc?.attributes.accountNumber ?? '',
    );
    _openingBalanceController = TextEditingController(
      text: acc?.attributes.openingBalance ?? '',
    );
    _interestController = TextEditingController(
      text: acc?.attributes.interest ?? '',
    );
    _notesController = TextEditingController(text: acc?.attributes.notes ?? '');

    _type = acc?.attributes.type ?? ShortAccountTypeProperty.asset;
    _role = acc?.attributes.accountRole ?? AccountRoleProperty.defaultasset;
    _liabilityType = acc?.attributes.liabilityType;
    _liabilityDirection = acc?.attributes.liabilityDirection;
    _interestPeriod = acc?.attributes.interestPeriod;
    _active = acc?.attributes.active ?? true;

    _previewName = _nameController.text;
    _previewIban = _ibanController.text;

    _nameController.addListener(() {
      if (_previewName != _nameController.text) {
        setState(() {
          _previewName = _nameController.text;
        });
      }
    });
    _ibanController.addListener(() {
      if (_previewIban != _ibanController.text) {
        setState(() {
          _previewIban = _ibanController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ibanController.dispose();
    _bicController.dispose();
    _accountNumberController.dispose();
    _openingBalanceController.dispose();
    _interestController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: 32,
        ),
        title: const Text('¿Eliminar cuenta?'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${widget.account!.attributes.name}"? Esta acción no se puede deshacer.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(MaterialLocalizations.of(ctx).deleteButtonTooltip),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final FireflyIii api = context.read<FireflyService>().api;
      final Response<dynamic> resp = await api.v1AccountsIdDelete(
        id: widget.account!.id,
      );
      if (!resp.isSuccessful) {
        throw Exception('Error eliminando cuenta: ${resp.error}');
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      log.severe('Error deleting account: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar la cuenta: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final FireflyIii api = context.read<FireflyService>().api;
      final CurrencyRead defaultCurrency = context
          .read<FireflyService>()
          .defaultCurrency;

      final String name = _nameController.text.trim();
      final String? iban = _ibanController.text.trim().isEmpty
          ? null
          : _ibanController.text.trim();
      final String? bic = _bicController.text.trim().isEmpty
          ? null
          : _bicController.text.trim();
      final String? accNumber = _accountNumberController.text.trim().isEmpty
          ? null
          : _accountNumberController.text.trim();
      final String? notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
      final String? interest = _interestController.text.trim().isEmpty
          ? null
          : _interestController.text.trim();

      if (widget.account == null) {
        // Crear cuenta
        final String? openingBalance =
            _openingBalanceController.text.trim().isEmpty
            ? null
            : _openingBalanceController.text.trim();

        final AccountStore store = AccountStore(
          name: name,
          type: _type,
          iban: iban,
          bic: bic,
          accountNumber: accNumber,
          openingBalance: openingBalance,
          openingBalanceDate: openingBalance != null ? DateTime.now() : null,
          currencyCode: defaultCurrency.attributes.code,
          accountRole: _type == ShortAccountTypeProperty.asset ? _role : null,
          liabilityType:
              _type == ShortAccountTypeProperty.liability ||
                  _type == ShortAccountTypeProperty.liabilities
              ? _liabilityType
              : null,
          liabilityDirection:
              _type == ShortAccountTypeProperty.liability ||
                  _type == ShortAccountTypeProperty.liabilities
              ? _liabilityDirection
              : null,
          interest: interest,
          interestPeriod: _interestPeriod,
          active: _active,
          notes: notes,
        );

        final Response<AccountSingle> resp = await api.v1AccountsPost(
          body: store,
        );
        if (!resp.isSuccessful || resp.body == null) {
          throw Exception(resp.error ?? 'Error desconocido al crear cuenta');
        }
      } else {
        // Editar cuenta existente
        final AccountUpdate update = AccountUpdate(
          name: name,
          iban: iban,
          bic: bic,
          accountNumber: accNumber,
          accountRole: _type == ShortAccountTypeProperty.asset ? _role : null,
          liabilityType:
              _type == ShortAccountTypeProperty.liability ||
                  _type == ShortAccountTypeProperty.liabilities
              ? _liabilityType
              : null,
          interest: interest,
          interestPeriod: _interestPeriod,
          active: _active,
          notes: notes,
        );

        final Response<AccountSingle> resp = await api.v1AccountsIdPut(
          id: widget.account!.id,
          body: update,
        );
        if (!resp.isSuccessful || resp.body == null) {
          throw Exception(
            resp.error ?? 'Error desconocido al actualizar cuenta',
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      log.severe('Error saving account: $e');
      String errorMsg = e.toString();
      try {
        if (e is Response && e.error != null) {
          final dynamic decoded = json.decode(e.error.toString());
          if (decoded is Map && decoded['message'] != null) {
            errorMsg = decoded['message'].toString();
          }
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMsg'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.account != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: <Widget>[
          BankLogoBadge(
            accountName: _previewName,
            iban: _previewIban,
            type: _type,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEdit ? 'Editar cuenta' : 'Nueva cuenta',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (isEdit) ...<Widget>[
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: _isSaving || _isDeleting ? null : _deleteAccount,
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving || _isDeleting
              ? null
              : () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _isSaving || _isDeleting ? null : _saveAccount,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre de la cuenta',
                    hintText: 'ej. Cuenta Nómina BBVA, Revolut, Hipoteca...',
                    prefixIcon: const Icon(Icons.account_balance_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (String? val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Por favor ingresa un nombre para la cuenta';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<ShortAccountTypeProperty>(
                  initialValue: _type,
                  decoration: InputDecoration(
                    labelText: 'Tipo de cuenta',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const <DropdownMenuItem<ShortAccountTypeProperty>>[
                    DropdownMenuItem<ShortAccountTypeProperty>(
                      value: ShortAccountTypeProperty.asset,
                      child: Text('Activos (Banco, Efectivo, Ahorros)'),
                    ),
                    DropdownMenuItem<ShortAccountTypeProperty>(
                      value: ShortAccountTypeProperty.liability,
                      child: Text('Pasivos (Deuda, Préstamo, Tarjeta)'),
                    ),
                    DropdownMenuItem<ShortAccountTypeProperty>(
                      value: ShortAccountTypeProperty.expense,
                      child: Text('Cuentas de gastos'),
                    ),
                    DropdownMenuItem<ShortAccountTypeProperty>(
                      value: ShortAccountTypeProperty.revenue,
                      child: Text('Cuentas de ingresos'),
                    ),
                  ],
                  onChanged: isEdit
                      ? null
                      : (ShortAccountTypeProperty? val) {
                          if (val != null) {
                            setState(() {
                              _type = val;
                            });
                          }
                        },
                ),
                if (_type == ShortAccountTypeProperty.asset) ...<Widget>[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<AccountRoleProperty>(
                    initialValue: _role,
                    decoration: InputDecoration(
                      labelText: 'Rol de la cuenta',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: <DropdownMenuItem<AccountRoleProperty>>[
                      DropdownMenuItem<AccountRoleProperty>(
                        value: AccountRoleProperty.defaultasset,
                        child: Text(
                          AccountRoleProperty.defaultasset.friendlyName(
                            context,
                          ),
                        ),
                      ),
                      DropdownMenuItem<AccountRoleProperty>(
                        value: AccountRoleProperty.savingasset,
                        child: Text(
                          AccountRoleProperty.savingasset.friendlyName(context),
                        ),
                      ),
                      DropdownMenuItem<AccountRoleProperty>(
                        value: AccountRoleProperty.ccasset,
                        child: Text(
                          AccountRoleProperty.ccasset.friendlyName(context),
                        ),
                      ),
                      DropdownMenuItem<AccountRoleProperty>(
                        value: AccountRoleProperty.cashwalletasset,
                        child: Text(
                          AccountRoleProperty.cashwalletasset.friendlyName(
                            context,
                          ),
                        ),
                      ),
                      DropdownMenuItem<AccountRoleProperty>(
                        value: AccountRoleProperty.sharedasset,
                        child: Text(
                          AccountRoleProperty.sharedasset.friendlyName(context),
                        ),
                      ),
                    ],
                    onChanged: (AccountRoleProperty? val) {
                      setState(() {
                        _role = val;
                      });
                    },
                  ),
                ],
                if (_type == ShortAccountTypeProperty.liability ||
                    _type == ShortAccountTypeProperty.liabilities) ...<Widget>[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<LiabilityTypeProperty>(
                    initialValue: _liabilityType ?? LiabilityTypeProperty.debt,
                    decoration: InputDecoration(
                      labelText: 'Tipo de pasivo',
                      prefixIcon: const Icon(Icons.credit_card_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const <DropdownMenuItem<LiabilityTypeProperty>>[
                      DropdownMenuItem<LiabilityTypeProperty>(
                        value: LiabilityTypeProperty.debt,
                        child: Text('Deuda general'),
                      ),
                      DropdownMenuItem<LiabilityTypeProperty>(
                        value: LiabilityTypeProperty.loan,
                        child: Text('Préstamo'),
                      ),
                      DropdownMenuItem<LiabilityTypeProperty>(
                        value: LiabilityTypeProperty.mortgage,
                        child: Text('Hipoteca'),
                      ),
                    ],
                    onChanged: (LiabilityTypeProperty? val) {
                      setState(() {
                        _liabilityType = val;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _interestController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Interés (%)',
                            hintText: 'ej. 2.5',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<InterestPeriodProperty>(
                          initialValue:
                              _interestPeriod ?? InterestPeriodProperty.monthly,
                          decoration: InputDecoration(
                            labelText: 'Periodo',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items:
                              const <DropdownMenuItem<InterestPeriodProperty>>[
                                DropdownMenuItem<InterestPeriodProperty>(
                                  value: InterestPeriodProperty.monthly,
                                  child: Text('Mensual'),
                                ),
                                DropdownMenuItem<InterestPeriodProperty>(
                                  value: InterestPeriodProperty.quarterly,
                                  child: Text('Trimestral'),
                                ),
                                DropdownMenuItem<InterestPeriodProperty>(
                                  value: InterestPeriodProperty.halfYear,
                                  child: Text('Semestral'),
                                ),
                                DropdownMenuItem<InterestPeriodProperty>(
                                  value: InterestPeriodProperty.yearly,
                                  child: Text('Anual'),
                                ),
                              ],
                          onChanged: (InterestPeriodProperty? val) {
                            setState(() {
                              _interestPeriod = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _ibanController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'IBAN (opcional)',
                    hintText: 'ES00 0000 0000 0000 0000 0000',
                    prefixIcon: const Icon(Icons.numbers_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (!isEdit) ...<Widget>[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _openingBalanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Saldo inicial (opcional)',
                      hintText: '0.00',
                      prefixIcon: const Icon(Icons.attach_money_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notas (opcional)',
                    hintText: 'Observaciones sobre la cuenta...',
                    prefixIcon: const Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cuenta activa'),
                  subtitle: const Text(
                    'Las cuentas inactivas se ocultan de las listas habituales',
                  ),
                  value: _active,
                  onChanged: (bool val) {
                    setState(() {
                      _active = val;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

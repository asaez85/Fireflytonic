import 'package:chopper/chopper.dart' show Response;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:waterflyiii/auth.dart';
import 'package:waterflyiii/generated/swagger_fireflyiii_api/firefly_iii.swagger.dart';
import 'package:waterflyiii/theme.dart';
import 'package:waterflyiii/widgets/ft_category_icon.dart';

class AddEditBudgetDialog extends StatefulWidget {
  final BudgetRead? budget;
  final BudgetLimitRead? limit;
  final DateTime selectedMonth;

  const AddEditBudgetDialog({
    super.key,
    this.budget,
    this.limit,
    required this.selectedMonth,
  });

  static Future<bool?> show(
    BuildContext context, {
    BudgetRead? budget,
    BudgetLimitRead? limit,
    required DateTime selectedMonth,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AddEditBudgetDialog(
        budget: budget,
        limit: limit,
        selectedMonth: selectedMonth,
      ),
    );
  }

  @override
  State<AddEditBudgetDialog> createState() => _AddEditBudgetDialogState();
}

class _AddEditBudgetDialogState extends State<AddEditBudgetDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  bool _autoRenew = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.budget?.attributes.name ?? '',
    );

    double initialAmount = 0.0;
    if (widget.limit != null) {
      initialAmount =
          double.tryParse(widget.limit?.attributes.amount ?? '') ?? 0.0;
    } else if (widget.budget?.attributes.autoBudgetAmount != null) {
      initialAmount =
          double.tryParse(widget.budget!.attributes.autoBudgetAmount!) ?? 0.0;
    }

    _amountController = TextEditingController(
      text: initialAmount > 0 ? initialAmount.toStringAsFixed(0) : '',
    );

    _autoRenew =
        widget.budget == null ||
        widget.budget?.attributes.autoBudgetType != AutoBudgetType.none;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final FireflyService ff = context.read<FireflyService>();
    final FireflyIii api = ff.api;
    final CurrencyRead currency = ff.defaultCurrency;

    final String name = _nameController.text.trim();
    final double amount =
        double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;

    final DateTime startOfMonth = DateTime(
      widget.selectedMonth.year,
      widget.selectedMonth.month,
      1,
    );
    final DateTime endOfMonth = DateTime(
      widget.selectedMonth.year,
      widget.selectedMonth.month + 1,
      0,
    );

    try {
      String budgetId;
      if (widget.budget != null) {
        budgetId = widget.budget!.id;
        await api.v1BudgetsIdPut(
          id: budgetId,
          body: BudgetUpdate(
            name: name,
            autoBudgetType: _autoRenew
                ? AutoBudgetType.reset
                : AutoBudgetType.none,
            autoBudgetPeriod: _autoRenew ? AutoBudgetPeriod.monthly : null,
            autoBudgetAmount: _autoRenew ? amount.toStringAsFixed(2) : null,
            autoBudgetCurrencyId: currency.id,
          ),
        );
      } else {
        final Response<BudgetSingle> resp = await api.v1BudgetsPost(
          body: BudgetStore(
            name: name,
            autoBudgetType: _autoRenew
                ? AutoBudgetType.reset
                : AutoBudgetType.none,
            autoBudgetPeriod: _autoRenew ? AutoBudgetPeriod.monthly : null,
            autoBudgetAmount: _autoRenew ? amount.toStringAsFixed(2) : null,
            autoBudgetCurrencyId: currency.id,
          ),
        );
        budgetId = resp.body!.data.id;
      }

      if (widget.limit != null) {
        await api.v1BudgetsIdLimitsLimitIdPut(
          id: budgetId,
          limitId: widget.limit!.id,
          body: BudgetLimitUpdate(
            start: startOfMonth,
            end: endOfMonth,
            amount: amount.toStringAsFixed(2),
            currencyId: currency.id,
          ),
        );
      } else {
        await api.v1BudgetsIdLimitsPost(
          id: budgetId,
          body: BudgetLimitStore(
            start: startOfMonth,
            end: endOfMonth,
            amount: amount.toStringAsFixed(2),
            currencyId: currency.id,
          ),
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar presupuesto: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
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
    final bool isEditing = widget.budget != null;
    final String monthName = DateFormat(
      'MMMM yyyy',
      'es_ES',
    ).format(widget.selectedMonth);

    return AlertDialog(
      title: Text(isEditing ? 'Editar presupuesto' : 'Nuevo presupuesto'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_nameController.text.isNotEmpty) ...<Widget>[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FtCategoryIconWidget(
                      icon: FtCategoryIcon.forName(_nameController.text),
                      color: FtColors.categoryColor(
                        _nameController.text,
                        context: context,
                      ),
                      size: 32,
                      padding: 14,
                    ),
                  ),
                ),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre / Categoría',
                  hintText: 'ej. Supermercado, Ocio...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (String? val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Introduce un nombre';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Límite mensual (€)',
                  hintText: 'ej. 200',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.euro),
                  helperText: 'Límite para $monthName',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (String? val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Introduce un importe';
                  }
                  final double? numVal = double.tryParse(
                    val.replaceAll(',', '.'),
                  );
                  if (numVal == null || numVal <= 0) {
                    return 'Introduce un importe positivo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: FtColors.coralOf(context),
                title: const Text('Renovación mensual'),
                subtitle: const Text(
                  'Reiniciar este límite automáticamente cada mes',
                  style: TextStyle(fontSize: 12),
                ),
                value: _autoRenew,
                onChanged: (bool val) {
                  setState(() {
                    _autoRenew = val;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: FtColors.coralOf(context),
          ),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : Text(isEditing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}

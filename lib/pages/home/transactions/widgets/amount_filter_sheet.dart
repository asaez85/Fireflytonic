import 'package:flutter/material.dart';
import 'package:waterflyiii/theme.dart';

class AmountFilterResult {
  final double? minAmount;
  final double? maxAmount;

  const AmountFilterResult({this.minAmount, this.maxAmount});
}

class AmountFilterSheet extends StatefulWidget {
  final double? initialMin;
  final double? initialMax;

  const AmountFilterSheet({super.key, this.initialMin, this.initialMax});

  static Future<AmountFilterResult?> show(
    BuildContext context, {
    double? initialMin,
    double? initialMax,
  }) {
    return showModalBottomSheet<AmountFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) =>
          AmountFilterSheet(initialMin: initialMin, initialMax: initialMax),
    );
  }

  @override
  State<AmountFilterSheet> createState() => _AmountFilterSheetState();
}

class _AmountFilterSheetState extends State<AmountFilterSheet> {
  final TextEditingController _minController = TextEditingController();
  final TextEditingController _maxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialMin != null) {
      _minController.text = _formatAmount(widget.initialMin!);
    }
    if (widget.initialMax != null) {
      _maxController.text = _formatAmount(widget.initialMax!);
    }
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  String _formatAmount(double value) {
    final String s = value.toStringAsFixed(2);
    if (s.endsWith('.00')) {
      return s.substring(0, s.length - 3);
    }
    if (s.contains('.') && s.endsWith('0')) {
      return s.substring(0, s.length - 1);
    }
    return s;
  }

  double? _parseAmount(String value) {
    if (value.trim().isEmpty) {
      return null;
    }
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  void _apply() {
    final double? minAmount = _parseAmount(_minController.text);
    final double? maxAmount = _parseAmount(_maxController.text);
    Navigator.pop(
      context,
      AmountFilterResult(minAmount: minAmount, maxAmount: maxAmount),
    );
  }

  void _clear() {
    setState(() {
      _minController.clear();
      _maxController.clear();
    });
  }

  bool get _hasInput =>
      _minController.text.trim().isNotEmpty ||
      _maxController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? FtColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Importe",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : FtColors.navy,
                  fontSize: 22,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Inputs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _minController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Desde",
                        hintText: "Mínimo",
                        prefixIcon: Icon(Icons.euro),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _maxController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Hasta",
                        hintText: "Máximo",
                        prefixIcon: Icon(Icons.euro),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 12,
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
                  if (_hasInput)
                    TextButton(
                      onPressed: _clear,
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
                    onPressed: _apply,
                    child: const Text(
                      "Aplicar",
                      style: TextStyle(
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
      ),
    );
  }
}

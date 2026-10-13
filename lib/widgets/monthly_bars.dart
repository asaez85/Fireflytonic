import 'package:flutter/material.dart';

import 'package:waterflyiii/theme.dart';

/// Datos de un periodo (mes, semana, trimestre, año…) para el gráfico de barras.
class MonthBarData {
  const MonthBarData({
    required this.label,
    required this.income,
    required this.expense,
  });
  final String label;
  final double income; // positivo
  final double expense; // positivo
}

/// Gráfico de barras por mes al estilo Fintonic.
///
/// - Modo doble (por defecto): dos barras por mes (ingresos + gastos).
/// - Modo [expenseOnly]: una sola barra de gasto por mes.
/// - Modo [incomeOnly]: una sola barra de ingreso por mes.
///
/// Los meses no seleccionados se muestran atenuados; el seleccionado, en color
/// (ingresos en azul/verde, gastos en coral) y con la etiqueta subrayada.
class MonthlyBars extends StatelessWidget {
  const MonthlyBars({
    super.key,
    required this.data,
    required this.selectedIndex,
    required this.onSelect,
    this.expenseOnly = false,
    this.incomeOnly = false,
    this.onPrevious,
    this.onNext,
  });

  final List<MonthBarData> data;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool expenseOnly;
  final bool incomeOnly;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }
    double maxVal = 0;
    for (final MonthBarData m in data) {
      maxVal = <double>[
        maxVal,
        if (!incomeOnly) m.expense,
        if (!expenseOnly) m.income,
      ].reduce((double a, double b) => a > b ? a : b);
    }
    if (maxVal <= 0) {
      maxVal = 1;
    }

    final Color muted = Theme.of(context).colorScheme.surfaceContainerHigh;
    const double barAreaHeight = 120;
    final bool isCompact = data.length > 6;
    final bool isSingle = expenseOnly || incomeOnly;
    final double barWidth = isCompact
        ? (isSingle ? 9 : 5.5)
        : (isSingle ? 14 : 11);
    final double barGap = isCompact ? 2 : 3;
    final double indicatorWidth = isCompact ? 14 : 22;
    final double labelFontSize = isCompact ? 10 : 12;
    final double barRadius = isCompact ? 2 : 3;

    final bool hasExplicitNav = onPrevious != null || onNext != null;
    final VoidCallback? prevAction = hasExplicitNav
        ? onPrevious
        : (selectedIndex > 0 ? () => onSelect(selectedIndex - 1) : null);
    final VoidCallback? nextAction = hasExplicitNav
        ? onNext
        : (selectedIndex < data.length - 1
              ? () => onSelect(selectedIndex + 1)
              : null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        _buildNavButton(
          context: context,
          icon: Icons.chevron_left,
          onPressed: prevAction,
        ),
        for (int i = 0; i < data.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    height: barAreaHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        if (!expenseOnly)
                          _bar(
                            context,
                            data[i].income / maxVal * barAreaHeight,
                            i == selectedIndex
                                ? (incomeOnly
                                      ? FtColors.incomeOf(context)
                                      : Theme.of(context).colorScheme.secondary)
                                : muted,
                            width: barWidth,
                            radius: barRadius,
                          ),
                        if (!expenseOnly && !incomeOnly)
                          SizedBox(width: barGap),
                        if (!incomeOnly)
                          _bar(
                            context,
                            data[i].expense / maxVal * barAreaHeight,
                            i == selectedIndex
                                ? FtColors.coralOf(context)
                                : muted,
                            width: barWidth,
                            radius: barRadius,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data[i].label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontSize: labelFontSize,
                      color: i == selectedIndex
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: i == selectedIndex
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 2.5,
                    width: indicatorWidth,
                    decoration: BoxDecoration(
                      color: i == selectedIndex
                          ? Theme.of(context).colorScheme.secondary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        _buildNavButton(
          context: context,
          icon: Icons.chevron_right,
          onPressed: nextAction,
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final Color activeColor = Theme.of(context).colorScheme.secondary;
    final Color disabledColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.18);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: IconButton(
        icon: Icon(icon, size: 22),
        color: activeColor,
        disabledColor: disabledColor,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 36),
        onPressed: onPressed,
      ),
    );
  }

  Widget _bar(
    BuildContext context,
    double height,
    Color color, {
    required double width,
    required double radius,
  }) => Container(
    width: width,
    height: height.clamp(3, double.infinity),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
    ),
  );
}

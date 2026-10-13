import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:waterflyiii/theme.dart';

class DateFilterResult {
  final DateTime? start;
  final DateTime? end;
  final String label;

  const DateFilterResult({
    required this.start,
    required this.end,
    required this.label,
  });
}

class DateFilterSheet extends StatelessWidget {
  final String? currentLabel;
  final DateTime? currentStart;
  final DateTime? currentEnd;

  const DateFilterSheet({
    super.key,
    this.currentLabel,
    this.currentStart,
    this.currentEnd,
  });

  static Future<DateFilterResult?> show(
    BuildContext context, {
    String? currentLabel,
    DateTime? currentStart,
    DateTime? currentEnd,
  }) {
    return showModalBottomSheet<DateFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => DateFilterSheet(
        currentLabel: currentLabel,
        currentStart: currentStart,
        currentEnd: currentEnd,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? FtColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Title "Selecciona"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Selecciona",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : FtColors.navy,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Option: Último mes
          _buildOption(
            context,
            title: "Último mes",
            isSelected: currentLabel == "Último mes",
            onTap: () {
              final DateTime now = DateTime.now();
              final DateTime start = now.subtract(const Duration(days: 30));
              Navigator.pop(
                context,
                DateFilterResult(
                  start: DateTime(start.year, start.month, start.day),
                  end: DateTime(now.year, now.month, now.day, 23, 59, 59),
                  label: "Último mes",
                ),
              );
            },
          ),

          // Option: Últimos 3 meses
          _buildOption(
            context,
            title: "Últimos 3 meses",
            isSelected: currentLabel == "Últimos 3 meses",
            onTap: () {
              final DateTime now = DateTime.now();
              final DateTime start = now.subtract(const Duration(days: 90));
              Navigator.pop(
                context,
                DateFilterResult(
                  start: DateTime(start.year, start.month, start.day),
                  end: DateTime(now.year, now.month, now.day, 23, 59, 59),
                  label: "Últimos 3 meses",
                ),
              );
            },
          ),

          // Option: Último año
          _buildOption(
            context,
            title: "Último año",
            isSelected: currentLabel == "Último año",
            onTap: () {
              final DateTime now = DateTime.now();
              final DateTime start = now.subtract(const Duration(days: 365));
              Navigator.pop(
                context,
                DateFilterResult(
                  start: DateTime(start.year, start.month, start.day),
                  end: DateTime(now.year, now.month, now.day, 23, 59, 59),
                  label: "Último año",
                ),
              );
            },
          ),

          // Option: Personalizado
          _buildOption(
            context,
            title: "Personalizado",
            isSelected:
                currentLabel == "Personalizado" ||
                (currentLabel != null &&
                    currentLabel != "Último mes" &&
                    currentLabel != "Últimos 3 meses" &&
                    currentLabel != "Último año" &&
                    currentLabel != "Fecha"),
            onTap: () async {
              final DateTime now = DateTime.now();
              final DateTimeRange? picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2010),
                lastDate: DateTime(now.year + 5),
                initialDateRange: (currentStart != null && currentEnd != null)
                    ? DateTimeRange(start: currentStart!, end: currentEnd!)
                    : null,
                builder: (BuildContext context, Widget? child) {
                  return Theme(
                    data: theme.copyWith(
                      colorScheme: theme.colorScheme.copyWith(
                        primary: FtColors.coralOf(context),
                      ),
                    ),
                    child: child!,
                  );
                },
              );

              if (picked != null && context.mounted) {
                final DateFormat fmt = DateFormat('dd/MM/yy', 'es_ES');
                final String customLabel =
                    "${fmt.format(picked.start)} - ${fmt.format(picked.end)}";
                Navigator.pop(
                  context,
                  DateFilterResult(
                    start: picked.start,
                    end: DateTime(
                      picked.end.year,
                      picked.end.month,
                      picked.end.day,
                      23,
                      59,
                      59,
                    ),
                    label: customLabel,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? FtColors.blueOf(context)
                      : (isDark ? Colors.white70 : FtColors.navy),
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check, color: FtColors.blueOf(context), size: 20),
          ],
        ),
      ),
    );
  }
}

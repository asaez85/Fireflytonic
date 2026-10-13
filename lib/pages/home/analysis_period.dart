import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Granularidad del análisis (selector tipo Fintonic).
enum AnalysisPeriod { week, month, quarter, year, custom }

extension AnalysisPeriodLabel on AnalysisPeriod {
  String get label => switch (this) {
    AnalysisPeriod.week => 'Semana',
    AnalysisPeriod.month => 'Mes',
    AnalysisPeriod.quarter => 'Trimestre',
    AnalysisPeriod.year => 'Año',
    AnalysisPeriod.custom => 'Personalizado',
  };
}

/// Un periodo concreto con su rango y etiquetas.
class PeriodBucket {
  const PeriodBucket({
    required this.start,
    required this.end,
    required this.shortLabel,
  });
  final DateTime start;
  final DateTime end;
  final String shortLabel; // etiqueta corta para la barra (ene, T1, 2026…)

  /// Rango legible para la cabecera, p. ej. "1 jun – 30 jun 2026".
  String get rangeLabel {
    final DateFormat d = DateFormat('d MMM');
    final DateFormat dy = DateFormat('d MMM yyyy');
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return dy.format(start);
    }
    return '${d.format(start)} – ${dy.format(end)}';
  }
}

/// Genera la lista de periodos a mostrar (los [count] anteriores según [offset]).
List<PeriodBucket> generateBuckets(
  AnalysisPeriod period, {
  DateTimeRange? custom,
  int count = 6,
  int offset = 0,
}) {
  final DateTime now = DateTime.now();
  final int bucketCount = count;
  switch (period) {
    case AnalysisPeriod.week:
      final List<PeriodBucket> out = <PeriodBucket>[];
      // Lunes de la semana de referencia desplazada por offset semanas.
      final DateTime thisMonday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1 + 7 * offset));
      for (int i = bucketCount - 1; i >= 0; i--) {
        final DateTime s = thisMonday.subtract(Duration(days: 7 * i));
        final DateTime e = s.add(const Duration(days: 6));
        out.add(
          PeriodBucket(
            start: s,
            end: e,
            shortLabel: DateFormat('d/M').format(s),
          ),
        );
      }
      return out;
    case AnalysisPeriod.month:
      final List<PeriodBucket> out = <PeriodBucket>[];
      for (int i = bucketCount - 1; i >= 0; i--) {
        final DateTime s = DateTime(now.year, now.month - offset - i, 1);
        final DateTime e = DateTime(now.year, now.month - offset - i + 1, 0);
        final String raw = DateFormat.MMM()
            .format(s)
            .replaceAll('.', '')
            .trim();
        final String trimmed = raw.length > 3 ? raw.substring(0, 3) : raw;
        final String label = trimmed.isNotEmpty
            ? '${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}'
            : trimmed;
        out.add(PeriodBucket(start: s, end: e, shortLabel: label));
      }
      return out;
    case AnalysisPeriod.quarter:
      final List<PeriodBucket> out = <PeriodBucket>[];
      for (int i = bucketCount - 1; i >= 0; i--) {
        final int totalQ =
            ((now.year * 4) + ((now.month - 1) ~/ 3)) - offset - i;
        final int year = totalQ ~/ 4;
        final int q = totalQ % 4;
        final DateTime s = DateTime(year, q * 3 + 1, 1);
        final DateTime e = DateTime(year, q * 3 + 4, 0);
        out.add(PeriodBucket(start: s, end: e, shortLabel: 'T${q + 1}'));
      }
      return out;
    case AnalysisPeriod.year:
      final List<PeriodBucket> out = <PeriodBucket>[];
      final int curYear = now.year - offset;
      final int yc = bucketCount - 1;
      for (int i = yc; i >= 0; i--) {
        final int year = curYear - i;
        out.add(
          PeriodBucket(
            start: DateTime(year, 1, 1),
            end: DateTime(year, 12, 31),
            shortLabel: '$year',
          ),
        );
      }
      return out;
    case AnalysisPeriod.custom:
      final DateTimeRange r =
          custom ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      return <PeriodBucket>[
        PeriodBucket(
          start: r.start,
          end: r.end,
          shortLabel: DateFormat('d/M').format(r.start),
        ),
      ];
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:waterflyiii/pages/home/evolution.dart';
import 'package:waterflyiii/settings.dart';

void main() {
  group('Evolution Enums & Data Points Tests', () {
    test('EvolutionViewMode provides correct labels and icons', () {
      expect(EvolutionViewMode.netWorth.label, 'Patrimonio');
      expect(EvolutionViewMode.balance.label, 'Saldo');
      expect(EvolutionViewMode.cashFlow.label, 'Flujo');
      expect(EvolutionViewMode.categories.label, 'Categorías');
    });

    test('EvolutionPeriodPreset provides correct chips labels', () {
      expect(EvolutionPeriodPreset.oneMonth.label, '1M');
      expect(EvolutionPeriodPreset.threeMonths.label, '3M');
      expect(EvolutionPeriodPreset.sixMonths.label, '6M');
      expect(EvolutionPeriodPreset.oneYear.label, '1A');
      expect(EvolutionPeriodPreset.all.label, 'Todo');
      expect(EvolutionPeriodPreset.custom.label, '📅');
    });

    test('EvolutionPeriodPreset converts to and from HomePatrimonyPeriod', () {
      expect(
        EvolutionPeriodPresetExt.fromHomePeriod(HomePatrimonyPeriod.oneMonth),
        EvolutionPeriodPreset.oneMonth,
      );
      expect(
        EvolutionPeriodPresetExt.fromHomePeriod(
          HomePatrimonyPeriod.threeMonths,
        ),
        EvolutionPeriodPreset.threeMonths,
      );
      expect(
        EvolutionPeriodPresetExt.fromHomePeriod(HomePatrimonyPeriod.sixMonths),
        EvolutionPeriodPreset.sixMonths,
      );
      expect(
        EvolutionPeriodPresetExt.fromHomePeriod(HomePatrimonyPeriod.oneYear),
        EvolutionPeriodPreset.oneYear,
      );
      expect(
        EvolutionPeriodPresetExt.fromHomePeriod(HomePatrimonyPeriod.allTime),
        EvolutionPeriodPreset.all,
      );

      expect(
        EvolutionPeriodPreset.oneMonth.toHomePeriod(),
        HomePatrimonyPeriod.oneMonth,
      );
      expect(
        EvolutionPeriodPreset.threeMonths.toHomePeriod(),
        HomePatrimonyPeriod.threeMonths,
      );
      expect(
        EvolutionPeriodPreset.sixMonths.toHomePeriod(),
        HomePatrimonyPeriod.sixMonths,
      );
      expect(
        EvolutionPeriodPreset.oneYear.toHomePeriod(),
        HomePatrimonyPeriod.oneYear,
      );
      expect(
        EvolutionPeriodPreset.all.toHomePeriod(),
        HomePatrimonyPeriod.allTime,
      );
      expect(EvolutionPeriodPreset.custom.toHomePeriod(), isNull);
    });

    test('ChartDataPoint models point data correctly', () {
      final DateTime now = DateTime.now();
      final ChartDataPoint point = ChartDataPoint(
        date: now,
        value: 1250.50,
        secondaryValue: 300.0,
        label: 'May',
      );
      expect(point.date, now);
      expect(point.value, 1250.50);
      expect(point.secondaryValue, 300.0);
      expect(point.label, 'May');
    });
  });

  group('Adaptive Y-Axis Range Tests', () {
    test('returns null when points is empty', () {
      expect(computeAdaptiveYAxisRange(<ChartDataPoint>[]), isNull);
    });

    test('centers range on the mean for fluctuating values above zero', () {
      final List<ChartDataPoint> points = <ChartDataPoint>[
        for (int i = 0; i < 5; i++)
          ChartDataPoint(
            date: DateTime(2026, 1, i + 1),
            value: 10000.0 + (i - 2) * 200.0,
          ),
      ];
      final ({double min, double max})? range = computeAdaptiveYAxisRange(points);
      expect(range, isNotNull);
      expect(range!.min, greaterThan(0));
      expect(range.max, greaterThan(range.min));

      final double mean = points.map((ChartDataPoint p) => p.value).reduce((double a, double b) => a + b) / points.length;
      expect((range.min + range.max) / 2, equals(mean));
    });

    test('handles a single data point without collapsing the range', () {
      final List<ChartDataPoint> points = <ChartDataPoint>[
        ChartDataPoint(date: DateTime(2026, 1, 1), value: 50000.0),
      ];
      final ({double min, double max})? range = computeAdaptiveYAxisRange(points);
      expect(range, isNotNull);
      expect(range!.min, lessThan(50000.0));
      expect(range.max, greaterThan(50000.0));
      expect((range.min + range.max) / 2, equals(50000.0));
    });

    test('handles identical flat values without collapsing the range', () {
      final List<ChartDataPoint> points = <ChartDataPoint>[
        for (int i = 0; i < 3; i++)
          ChartDataPoint(date: DateTime(2026, 1, i + 1), value: 12345.0),
      ];
      final ({double min, double max})? range = computeAdaptiveYAxisRange(points);
      expect(range, isNotNull);
      expect(range!.min, lessThan(12345.0));
      expect(range.max, greaterThan(12345.0));
      expect((range.min + range.max) / 2, equals(12345.0));
    });
  });
}

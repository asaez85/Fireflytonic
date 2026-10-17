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
}

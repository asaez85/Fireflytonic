import 'package:flutter_test/flutter_test.dart';
import 'package:waterflyiii/pages/home/evolution.dart';

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

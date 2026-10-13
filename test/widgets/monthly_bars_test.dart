import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waterflyiii/pages/home/analysis_period.dart';
import 'package:waterflyiii/widgets/monthly_bars.dart';

void main() {
  group('AnalysisPeriod & generateBuckets', () {
    test('generateBuckets generates 6 buckets for AnalysisPeriod.month', () {
      final List<PeriodBucket> buckets = generateBuckets(AnalysisPeriod.month);
      expect(buckets.length, equals(6));
      for (final PeriodBucket b in buckets) {
        expect(b.shortLabel.isNotEmpty, isTrue);
        expect(b.shortLabel.length <= 4, isTrue);
        expect(b.start.isBefore(b.end), isTrue);
      }
    });

    test('generateBuckets generates 6 buckets for AnalysisPeriod.week', () {
      final List<PeriodBucket> buckets = generateBuckets(AnalysisPeriod.week);
      expect(buckets.length, equals(6));
    });

    test('generateBuckets respects explicit count', () {
      final List<PeriodBucket> buckets = generateBuckets(
        AnalysisPeriod.month,
        count: 3,
      );
      expect(buckets.length, equals(3));
    });

    test('generateBuckets respects offset', () {
      final List<PeriodBucket> current = generateBuckets(
        AnalysisPeriod.month,
        offset: 0,
      );
      final List<PeriodBucket> shifted = generateBuckets(
        AnalysisPeriod.month,
        offset: 1,
      );
      expect(current.length, equals(6));
      expect(shifted.length, equals(6));
      // shifted last bucket should match current second to last bucket
      expect(
        shifted.last.start.month,
        equals(current[current.length - 2].start.month),
      );
    });
  });

  group('MonthlyBars widget', () {
    testWidgets('renders 12 bars without overflow and handles selection', (
      WidgetTester tester,
    ) async {
      int selected = 11;
      final List<MonthBarData> data = List<MonthBarData>.generate(
        12,
        (int i) => MonthBarData(
          label: 'M${i + 1}',
          income: (i + 1) * 100.0,
          expense: (i + 1) * 80.0,
        ),
      );

      // Test on standard mobile screen width (360 x 640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return MonthlyBars(
                  data: data,
                  selectedIndex: selected,
                  onSelect: (int idx) {
                    setState(() {
                      selected = idx;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('M1'), findsOneWidget);
      expect(find.text('M12'), findsOneWidget);

      // Tap on first month (M1)
      await tester.tap(find.text('M1'));
      await tester.pump();
      expect(selected, equals(0));
    });

    testWidgets('renders expenseOnly mode for 12 months without overflow', (
      WidgetTester tester,
    ) async {
      int selected = 5;
      final List<MonthBarData> data = List<MonthBarData>.generate(
        12,
        (int i) => MonthBarData(
          label: 'M${i + 1}',
          income: 0.0,
          expense: (i + 1) * 50.0,
        ),
      );

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return MonthlyBars(
                  data: data,
                  selectedIndex: selected,
                  onSelect: (int idx) {
                    setState(() {
                      selected = idx;
                    });
                  },
                  expenseOnly: true,
                );
              },
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('M6'), findsOneWidget);

      await tester.tap(find.text('M6'));
      await tester.pump();
      expect(selected, equals(5));
    });

    testWidgets('chevron arrows trigger onPrevious and onNext', (
      WidgetTester tester,
    ) async {
      int selected = 2;
      bool prevCalled = false;
      bool nextCalled = false;
      final List<MonthBarData> data = List<MonthBarData>.generate(
        6,
        (int i) =>
            MonthBarData(label: 'M${i + 1}', income: 100.0, expense: 80.0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthlyBars(
              data: data,
              selectedIndex: selected,
              onSelect: (int idx) => selected = idx,
              onPrevious: () => prevCalled = true,
              onNext: () => nextCalled = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(prevCalled, isTrue);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(nextCalled, isTrue);
    });

    testWidgets('default fallback navigation when callbacks omitted', (
      WidgetTester tester,
    ) async {
      int selected = 2;
      final List<MonthBarData> data = List<MonthBarData>.generate(
        6,
        (int i) =>
            MonthBarData(label: 'M${i + 1}', income: 100.0, expense: 80.0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return MonthlyBars(
                  data: data,
                  selectedIndex: selected,
                  onSelect: (int idx) {
                    setState(() {
                      selected = idx;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(selected, equals(1));

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(selected, equals(2));
    });
  });
}

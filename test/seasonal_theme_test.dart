import 'package:eCalendar/liquid_glass_components.dart';
import 'package:eCalendar/seasonal_theme.dart';
import 'package:eCalendar/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  String? on(SeasonConfig config, int year, int month, int day) => config.seasonOn(DateTime(year, month, day))?.id;

  group('SeasonConfig', () {
    test('automatic dates, including a season that runs over New Year', () {
      const config = SeasonConfig();
      expect(on(config, 2026, 12, 1), 'xmas');
      expect(on(config, 2027, 1, 6), 'xmas');
      expect(on(config, 2027, 1, 7), isNull);
      expect(on(config, 2027, 2, 14), 'hearts');
      expect(on(config, 2027, 4, 10), 'summer');
      expect(on(config, 2027, 7, 1), 'rainy');
      expect(on(config, 2026, 11, 13), isNull);
    });

    test('off shows nothing, a forced season shows on any date', () {
      expect(on(SeasonConfig.off, 2026, 12, 25), isNull);
      expect(on(const SeasonConfig(mode: 'summer'), 2026, 12, 25), 'summer');
    });

    test('one-time fiesta dates win over the season they fall in, that year only', () {
      final config = SeasonConfig.fromJson({
        'mode': 'auto',
        'dates': {
          'fiesta': {'start': '2027-05-12', 'end': '2027-05-15'},
        },
      });
      expect(on(config, 2027, 5, 14), 'fiesta');
      expect(on(config, 2027, 5, 16), 'summer');
      expect(on(config, 2028, 5, 14), 'summer');
    });

    test('a bad saved value falls back to the built-in dates', () {
      expect(on(SeasonConfig.fromJson('nonsense'), 2026, 12, 25), 'xmas');
      final broken = SeasonConfig.fromJson({
        'dates': {
          'xmas': {'start': 'soon', 'end': 5},
          'summer': {'start': '3-1', 'end': '05-31'},
        },
      });
      expect(on(broken, 2026, 12, 25), 'xmas');
      expect(on(broken, 2027, 4, 10), isNull);
    });
  });

  group('ThemeController seasons', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a change made in the portal is picked up without an app update', () async {
      Object? server = {'mode': 'off'};
      final controller = ThemeController(
        initialSeasonConfig: const SeasonConfig(),
        now: () => DateTime(2026, 12, 25),
      )..seasonConfigFetcher = () async => server;
      expect(controller.activeSeason?.id, 'xmas');

      var notified = 0;
      controller.addListener(() => notified++);
      await controller.refreshSeasonConfig();
      expect(controller.activeSeason, isNull);
      expect(notified, 1);

      server = {'mode': 'fiesta'};
      await controller.refreshSeasonConfig();
      expect(controller.activeSeason?.id, 'fiesta');

      // The saved setting is what the next launch starts from.
      final reloaded = await ThemeController.load();
      expect(reloaded.activeSeason?.id, 'fiesta');
    });

    test('a failed fetch keeps the current season', () async {
      final controller = ThemeController(initialSeasonConfig: const SeasonConfig(mode: 'summer'))
        ..seasonConfigFetcher = () async => throw Exception('offline');
      await controller.refreshSeasonConfig();
      expect(controller.activeSeason?.id, 'summer');
    });

    test("a person's own Off and no-effects choices", () async {
      final controller = ThemeController(initialSeasonConfig: const SeasonConfig(mode: 'xmas'));
      expect(controller.seasonEffects, isTrue);
      await controller.setSeasonPref(SeasonPref.noEffects);
      expect(controller.activeSeason?.id, 'xmas');
      expect(controller.seasonEffects, isFalse);
      await controller.setSeasonPref(SeasonPref.off);
      expect(controller.activeSeason, isNull);
    });
  });

  group('season widgets', () {
    Widget app(Season? season, {bool effects = true}) => MaterialApp(
          home: SeasonScope(
            season: season,
            effects: effects,
            child: const Stack(children: [LiquidGlassBackdrop(), SeasonDecoration()]),
          ),
        );
    final xmas = seasons.firstWhere((season) => season.id == 'xmas');

    testWidgets('a season shows its decoration and falling effect', (tester) async {
      await tester.pumpWidget(app(xmas));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('season-decoration-xmas')), findsOneWidget);
      expect(find.byKey(const Key('season-effect')), findsOneWidget);
    });

    testWidgets('the effect can be off while the decoration stays', (tester) async {
      await tester.pumpWidget(app(xmas, effects: false));
      expect(find.byKey(const Key('season-decoration-xmas')), findsOneWidget);
      expect(find.byKey(const Key('season-effect')), findsNothing);
    });

    testWidgets('no season: nothing added', (tester) async {
      await tester.pumpWidget(app(null));
      expect(find.byKey(const Key('season-effect')), findsNothing);
      expect(find.byType(SeasonDecoration), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}

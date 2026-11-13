import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'l10n/app_localizations.dart';

/// What falls slowly behind the content while a season is on.
enum SeasonEffect { none, snow, rain, confetti }

/// One seasonal look: a highlight color (seeds the whole color scheme), the
/// three background glow colors, one decoration and an optional falling
/// effect. The looks are built in; *when* each one shows comes from the
/// server ([SeasonConfig]), so the superadmin changes seasons without an
/// app update.
class Season {
  const Season(this.id, this.seed, this.orbs, this.hero, this.asset, [this.effect = SeasonEffect.none]);

  final String id;
  final Color seed;
  final List<Color> orbs;

  /// The banner's two gradient colors, dark enough for white text (4.5:1).
  final List<Color> hero;
  final String asset;
  final SeasonEffect effect;
}

/// Where two seasons' dates overlap, the earlier one wins: fiesta first,
/// then the holidays (a few days each), then the long seasons they fall in.
const List<Season> seasons = [
  Season('fiesta', Color(0xFFE8703A), [Color(0xFFE84C7A), Color(0xFFF2B632), Color(0xFF19A7CE)],
      [Color(0xFFC2410C), Color(0xFF7C2D12)], 'assets/seasons/balloons.svg', SeasonEffect.confetti),
  Season('newyear', Color(0xFF5B4FCF), [Color(0xFF5B4FCF), Color(0xFFF2B632), Color(0xFFE84C7A)],
      [Color(0xFF3730A3), Color(0xFF1E1B4B)], 'assets/seasons/newyear.svg', SeasonEffect.confetti),
  Season('holyweek', Color(0xFF7B4FB0), [Color(0xFF7B4FB0), Color(0xFFF2B632), Color(0xFF4FA35A)],
      [Color(0xFF5B3A8C), Color(0xFF3B2363)], 'assets/seasons/holyweek.svg'),
  Season('independence', Color(0xFF0038A8), [Color(0xFF0038A8), Color(0xFFCE1126), Color(0xFFFCD116)],
      [Color(0xFF0B2A7A), Color(0xFF061440)], 'assets/seasons/flag.svg'),
  Season('wika', Color(0xFF1E8A52), [Color(0xFF1E8A52), Color(0xFFF2B632), Color(0xFFB9770E)],
      [Color(0xFF15803D), Color(0xFF14532D)], 'assets/seasons/kubo.svg'),
  Season('undas', Color(0xFF7A5AA8), [Color(0xFF7A5AA8), Color(0xFFF2B632), Color(0xFF3D7FC4)],
      [Color(0xFF4C3A78), Color(0xFF2A1F4D)], 'assets/seasons/candles.svg'),
  Season('xmas', Color(0xFFC8372D), [Color(0xFFC8372D), Color(0xFF1E8A52), Color(0xFFF2B632)],
      [Color(0xFFC8372D), Color(0xFF7E1A14)], 'assets/seasons/parol.svg', SeasonEffect.snow),
  Season('hearts', Color(0xFFE84C7A), [Color(0xFFE84C7A), Color(0xFF9B59B6), Color(0xFFF29E6B)],
      [Color(0xFFBE185D), Color(0xFF831843)], 'assets/seasons/heart.svg'),
  Season('summer', Color(0xFFF0932B), [Color(0xFFF2B632), Color(0xFF19A7CE), Color(0xFFFF8A3D)],
      [Color(0xFF0B6E94), Color(0xFF0B4F6C)], 'assets/seasons/sun.svg'),
  Season('rainy', Color(0xFF3D7FC4), [Color(0xFF3D7FC4), Color(0xFF5B6ACF), Color(0xFF3FA79B)],
      [Color(0xFF2C66A8), Color(0xFF1B3F73)], 'assets/seasons/rain.svg', SeasonEffect.rain),
];

/// The superadmin's setting (app_settings 'seasonal_theme', read through the
/// get_seasonal_theme RPC). [mode] is 'auto' (by date), 'off', or a season id
/// to force that season for everyone. Dates are 'MM-DD' (every year) or
/// 'YYYY-MM-DD' (one time, e.g. this year's fiesta); an empty date never
/// matches.
class SeasonConfig {
  const SeasonConfig({this.mode = 'auto', this.dates = defaultDates});

  static const off = SeasonConfig(mode: 'off');

  static const Map<String, (String, String)> defaultDates = {
    'xmas': ('12-01', '01-06'),
    'hearts': ('02-01', '02-14'),
    'summer': ('03-01', '05-31'),
    'rainy': ('06-01', '08-31'),
    'fiesta': ('', ''),
    'newyear': ('12-30', '01-02'),
    'holyweek': ('', ''), // empty = worked out each year, see [holyWeek]
    'independence': ('06-10', '06-12'),
    'wika': ('08-01', '08-31'),
    'undas': ('10-31', '11-02'),
  };

  /// Palm Sunday to Easter Sunday of [year], as one-time dates. Holy Week
  /// moves every year, so it is computed instead of set in the portal.
  static (String, String) holyWeek(int year) {
    // Anonymous Gregorian algorithm for Easter Sunday.
    final a = year % 19, b = year ~/ 100, c = year % 100;
    final h = (19 * a + b - b ~/ 4 - (b - (b + 8) ~/ 25 + 1) ~/ 3 + 15) % 30;
    final l = (32 + 2 * (b % 4) + 2 * (c ~/ 4) - h - c % 4) % 7;
    final n = h + l - 7 * ((a + 11 * h + 22 * l) ~/ 451) + 114;
    final month = n ~/ 31, day = n % 31 + 1;
    String iso(DateTime d) => d.toIso8601String().substring(0, 10);
    return (iso(DateTime(year, month, day - 7)), iso(DateTime(year, month, day)));
  }

  final String mode;
  final Map<String, (String, String)> dates;

  /// Anything missing or malformed falls back to the default, so a bad
  /// value saved in the portal can't break the app's look.
  factory SeasonConfig.fromJson(Object? json) {
    if (json is! Map) return const SeasonConfig();
    final dates = {...defaultDates};
    final rawDates = json['dates'];
    if (rawDates is Map) {
      for (final id in defaultDates.keys) {
        final range = rawDates[id];
        if (range is Map && range['start'] is String && range['end'] is String) {
          dates[id] = (range['start'] as String, range['end'] as String);
        }
      }
    }
    final mode = json['mode'];
    return SeasonConfig(mode: mode is String ? mode : 'auto', dates: dates);
  }

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'dates': {
          for (final entry in dates.entries) entry.key: {'start': entry.value.$1, 'end': entry.value.$2},
        },
      };

  Season? seasonOn(DateTime day) {
    if (mode == 'off') return null;
    for (final season in seasons) {
      if (mode == season.id) return season;
    }
    if (mode != 'auto') return null;
    for (final season in seasons) {
      var range = dates[season.id];
      if (season.id == 'holyweek' && range?.$1 == '') range = holyWeek(day.year);
      if (range != null && _inRange(day, range.$1, range.$2)) return season;
    }
    return null;
  }

  static bool _inRange(DateTime day, String start, String end) {
    // One-time dates compare with the year, yearly ones without it; the
    // zero-padded text sorts the same way the dates do.
    String two(int n) => n.toString().padLeft(2, '0');
    final monthDay = '${two(day.month)}-${two(day.day)}';
    final full = '${day.year.toString().padLeft(4, '0')}-$monthDay';
    final pattern = RegExp(r'^(\d{4}-)?\d{2}-\d{2}$');
    if (!pattern.hasMatch(start) || !pattern.hasMatch(end) || start.length != end.length) return false;
    final today = start.length == 10 ? full : monthDay;
    final afterStart = today.compareTo(start) >= 0;
    final beforeEnd = today.compareTo(end) <= 0;
    // A yearly range may run over New Year (Dec 1 to Jan 6).
    return start.compareTo(end) <= 0 ? afterStart && beforeEnd : afterStart || beforeEnd;
  }
}

/// The season showing right now, for everything below the MaterialApp.
class SeasonScope extends InheritedWidget {
  const SeasonScope({super.key, required this.season, required this.effects, required super.child});

  final Season? season;

  /// False when the person turned the falling effect off in Settings.
  final bool effects;

  static SeasonScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SeasonScope>();

  @override
  bool updateShouldNotify(SeasonScope oldWidget) => oldWidget.season != season || oldWidget.effects != effects;
}

/// The season's illustration (Christmas tree, beach, ...); nothing outside
/// a season.
class SeasonDecoration extends StatelessWidget {
  const SeasonDecoration({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    final season = SeasonScope.maybeOf(context)?.season;
    if (season == null) return const SizedBox.shrink();
    return SvgPicture.asset(season.asset, key: Key('season-decoration-${season.id}'), width: size, height: size);
  }
}

/// The season's banner on the Calendar tab: a greeting on the season's
/// colors beside its illustration. Nothing outside a season.
class SeasonHero extends StatelessWidget {
  const SeasonHero({super.key});

  @override
  Widget build(BuildContext context) {
    final season = SeasonScope.maybeOf(context)?.season;
    if (season == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Container(
      key: const Key('season-hero'),
      margin: const EdgeInsets.only(bottom: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: season.hero),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 4, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.seasonGreeting(season.id),
                    style: text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.seasonHeroSubtitle,
                    style: text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
          ),
          const SeasonDecoration(),
        ],
      ),
    );
  }
}

/// Snow, rain or confetti drifting down behind the content. Draws nothing
/// when the season has no effect, the person turned it off, or the device
/// asks for reduced motion.
class SeasonEffectLayer extends StatefulWidget {
  const SeasonEffectLayer({super.key});

  @override
  State<SeasonEffectLayer> createState() => _SeasonEffectLayerState();
}

class _SeasonEffectLayerState extends State<SeasonEffectLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 12));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = SeasonScope.maybeOf(context);
    final effect = scope?.season?.effect ?? SeasonEffect.none;
    final show = effect != SeasonEffect.none && scope!.effects && !MediaQuery.disableAnimationsOf(context);
    if (!show) {
      _controller.stop();
      return const SizedBox.shrink();
    }
    if (!_controller.isAnimating) _controller.repeat();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          key: const Key('season-effect'),
          size: Size.infinite,
          painter: _EffectPainter(_controller, effect, dark ? Colors.white : Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}

class _EffectPainter extends CustomPainter {
  _EffectPainter(this.progress, this.effect, this.color) : super(repaint: progress);

  final Animation<double> progress;
  final SeasonEffect effect;
  final Color color;

  static const _confetti = [Color(0xFFE84C7A), Color(0xFFF2B632), Color(0xFF19A7CE), Color(0xFF2FA36B)];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    // A few particles only: lively, never in the way of reading.
    for (var i = 0; i < 18; i++) {
      // Each particle loops 1-3 whole times per cycle, so the loop is seamless.
      final speed = 1 + i % 3;
      final t = (progress.value * speed + i * 0.137) % 1.0;
      final x = ((i * 61 + 13) % 100) / 100 * size.width + math.sin((t + i) * math.pi * 2) * 10;
      final y = t * (size.height + 30) - 15;
      switch (effect) {
        case SeasonEffect.snow:
          canvas.drawCircle(Offset(x, y), 2.0 + i % 2, paint..color = color.withValues(alpha: 0.45));
        case SeasonEffect.rain:
          canvas.drawLine(Offset(x, y), Offset(x - 3, y + 13),
              paint..color = color.withValues(alpha: 0.28)..strokeWidth = 1.5);
        case SeasonEffect.confetti:
          canvas.drawRect(Rect.fromLTWH(x, y, 4, 7), paint..color = _confetti[i % 4].withValues(alpha: 0.7));
        case SeasonEffect.none:
          break;
      }
    }
  }

  @override
  bool shouldRepaint(_EffectPainter oldDelegate) => oldDelegate.effect != effect || oldDelegate.color != color;
}

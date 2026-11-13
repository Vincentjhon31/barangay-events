import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// What falls slowly behind the content while a season is on.
enum SeasonEffect { none, snow, rain, confetti }

/// One seasonal look: a highlight color (seeds the whole color scheme), the
/// three background glow colors, one decoration and an optional falling
/// effect. The looks are built in; *when* each one shows comes from the
/// server ([SeasonConfig]), so the superadmin changes seasons without an
/// app update.
class Season {
  const Season(this.id, this.seed, this.orbs, this.asset, [this.effect = SeasonEffect.none]);

  final String id;
  final Color seed;
  final List<Color> orbs;
  final String asset;
  final SeasonEffect effect;
}

/// Fiesta first: where two seasons' dates overlap, the earlier one wins.
const List<Season> seasons = [
  Season('fiesta', Color(0xFFE8703A), [Color(0xFFE84C7A), Color(0xFFF2B632), Color(0xFF19A7CE)],
      'assets/seasons/balloons.svg', SeasonEffect.confetti),
  Season('xmas', Color(0xFFC8372D), [Color(0xFFC8372D), Color(0xFF1E8A52), Color(0xFFF2B632)],
      'assets/seasons/parol.svg', SeasonEffect.snow),
  Season('hearts', Color(0xFFE84C7A), [Color(0xFFE84C7A), Color(0xFF9B59B6), Color(0xFFF29E6B)],
      'assets/seasons/heart.svg'),
  Season('summer', Color(0xFFF0932B), [Color(0xFFF2B632), Color(0xFF19A7CE), Color(0xFFFF8A3D)],
      'assets/seasons/sun.svg'),
  Season('rainy', Color(0xFF3D7FC4), [Color(0xFF3D7FC4), Color(0xFF5B6ACF), Color(0xFF3FA79B)],
      'assets/seasons/rain.svg', SeasonEffect.rain),
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
  };

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
      final range = dates[season.id];
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

/// The season's 3D decoration (parol, sun, ...); nothing outside a season.
class SeasonDecoration extends StatelessWidget {
  const SeasonDecoration({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    final season = SeasonScope.maybeOf(context)?.season;
    if (season == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: SvgPicture.asset(season.asset, key: Key('season-decoration-${season.id}'), width: size, height: size),
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

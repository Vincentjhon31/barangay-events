import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';

/// Philippine Standard Time is a fixed UTC+8 with no daylight saving, so
/// Asia/Manila time is plain offset arithmetic — no timezone database
/// needed, and it stays correct on a device set to any other timezone.
const Duration manilaUtcOffset = Duration(hours: 8);

/// The Asia/Manila wall-clock reading of [instant]. The result is
/// UTC-flagged but carries Manila's fields (hour, day, ...) — only ever
/// format or compare it, never convert it again with `toLocal()`/`toUtc()`.
DateTime toManila(DateTime instant) => instant.toUtc().add(manilaUtcOffset);

/// The current Asia/Manila wall-clock time — see [toManila].
DateTime manilaNow() => toManila(DateTime.now());

/// A live clock showing the current Philippine (Asia/Manila) time, ticking
/// every second — shown in the Calendar tab's header next to the profile
/// avatar, and on the kiosk display.
class ManilaClock extends StatefulWidget {
  const ManilaClock({super.key});

  @override
  State<ManilaClock> createState() => _ManilaClockState();
}

class _ManilaClockState extends State<ManilaClock> {
  late DateTime _now = manilaNow();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  // A one-shot timer re-armed for the next whole second, rather than a
  // fixed 1s periodic one, so the display flips exactly on the second
  // instead of drifting up to a second behind the real clock.
  void _scheduleTick() {
    final wait = Duration(milliseconds: 1000 - DateTime.now().millisecond);
    _timer = Timer(wait, () {
      if (!mounted) return;
      setState(() => _now = manilaNow());
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Tabular figures keep the width steady as the digits change, so the
    // header doesn't jiggle every second.
    const tabular = [FontFeature.tabularFigures()];
    final time = DateFormat('h:mm:ss a').format(_now);
    final date = DateFormat('EEE, MMM d').format(_now);

    return Tooltip(
      message: l10n.manilaClockTooltip,
      child: Semantics(
        label: l10n.manilaClockSemantics(time, date),
        excludeSemantics: true,
        child: ConstrainedBox(
          // Never crowds the title or avatar out on a narrow phone — it
          // scales its text down instead.
          constraints: const BoxConstraints(maxWidth: 118),
          child: GlassPanel(
            key: const Key('manila-clock'),
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    time,
                    key: const Key('manila-clock-time'),
                    maxLines: 1,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: tabular,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$date · PHT',
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontFeatures: tabular,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

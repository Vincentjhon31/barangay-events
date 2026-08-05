import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'event_store.dart';

typedef EventTint = Color Function(BarangayEvent event);
typedef EventIcon = FaIconData Function(BarangayEvent event);

/// A single day's events laid out on an hour-gridded timeline, Google
/// Calendar-day-view style: each event is a colored block whose vertical
/// position/height reflect its start time and duration, with overlapping
/// events placed side-by-side in columns instead of stacked on top of
/// each other.
class DayTimelineView extends StatelessWidget {
  const DayTimelineView({
    super.key,
    required this.day,
    required this.events,
    required this.tintForEvent,
    required this.iconForEvent,
    required this.onEventTap,
    this.hourHeight = 64,
  });

  final DateTime day;
  final List<BarangayEvent> events;
  final EventTint tintForEvent;
  final EventIcon iconForEvent;
  final ValueChanged<BarangayEvent> onEventTap;
  final double hourHeight;

  static const _gutterWidth = 52.0;

  /// The hour the grid starts/ends at — the earliest event's start hour
  /// minus one hour of padding through the latest event's end hour plus
  /// one, clamped to a real day. A day with no events at all falls back
  /// to a plain 8 AM-6 PM "typical work day" window rather than either
  /// the full 24 hours (mostly empty scrolling) or nothing at all.
  ({int start, int end}) get _hourRange {
    if (events.isEmpty) return (start: 8, end: 18);
    var earliest = 24 * 60;
    var latest = 0;
    for (final event in events) {
      final window = event.minutesWindowForDay(day);
      if (window.startMinutes < earliest) earliest = window.startMinutes;
      if (window.endMinutes > latest) latest = window.endMinutes;
    }
    final start = ((earliest ~/ 60) - 1).clamp(0, 23);
    final end = ((latest + 59) ~/ 60 + 1).clamp(start + 1, 24);
    return (start: start, end: end);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final range = _hourRange;
    final hourCount = range.end - range.start;
    final totalHeight = hourHeight * hourCount;
    final placed = _layout(range.start);

    return SizedBox(
      height: totalHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _gutterWidth,
            height: totalHeight,
            child: Stack(
              children: [
                for (var hour = range.start; hour < range.end; hour++)
                  Positioned(
                    top: (hour - range.start) * hourHeight - 7,
                    left: 0,
                    right: 8,
                    child: Text(
                      _hourLabel(hour),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                for (var hour = range.start; hour <= range.end; hour++)
                  Positioned(
                    top: (hour - range.start) * hourHeight,
                    left: 0,
                    right: 0,
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: colorScheme.onSurface
                          .withValues(alpha: hour == range.start || hour == range.end ? 0.0 : 0.08),
                    ),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return Stack(
                      children: [
                        for (final entry in placed)
                          Positioned(
                            top: entry.top,
                            height: entry.height,
                            left: width * entry.columnIndex / entry.columnCount,
                            width: width / entry.columnCount - (entry.columnCount > 1 ? 4 : 0),
                            child: _TimelineEventBlock(
                              event: entry.event,
                              color: tintForEvent(entry.event),
                              icon: iconForEvent(entry.event),
                              compact: entry.height < 40,
                              onTap: () => onEventTap(entry.event),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _hourLabel(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    return hour < 12 ? '$hour AM' : '${hour - 12} PM';
  }

  /// Positions every event vertically by its time-of-day window on [day],
  /// then clusters transitively-overlapping events and assigns each a
  /// column via greedy interval coloring, so a cluster of 3 overlapping
  /// events becomes 3 equal side-by-side columns while a lone event still
  /// spans the full width.
  List<_PlacedEvent> _layout(int startHour) {
    final startOffsetMinutes = startHour * 60;
    const minDurationMinutes = 30;
    final minPxHeight = hourHeight * minDurationMinutes / 60;

    final windows = <({BarangayEvent event, int start, int end})>[];
    for (final event in events) {
      final window = event.minutesWindowForDay(day);
      final start = window.startMinutes.clamp(0, 24 * 60);
      var end = window.endMinutes.clamp(start, 24 * 60);
      if (end - start < minDurationMinutes) {
        end = (start + minDurationMinutes).clamp(start, 24 * 60);
      }
      windows.add((event: event, start: start, end: end));
    }
    windows.sort((a, b) => a.start.compareTo(b.start));

    final placed = <_PlacedEvent>[];
    var clusterStartIndex = 0;
    var clusterMaxEnd = -1;

    void flushCluster(int endIndexExclusive) {
      if (endIndexExclusive <= clusterStartIndex) return;
      final cluster = windows.sublist(clusterStartIndex, endIndexExclusive);
      final columnEnds = <int>[];
      final columnOf = <int>[];
      for (final item in cluster) {
        var assigned = -1;
        for (var col = 0; col < columnEnds.length; col++) {
          if (columnEnds[col] <= item.start) {
            assigned = col;
            break;
          }
        }
        if (assigned == -1) {
          assigned = columnEnds.length;
          columnEnds.add(item.end);
        } else {
          columnEnds[assigned] = item.end;
        }
        columnOf.add(assigned);
      }
      final columnCount = columnEnds.length;
      for (var i = 0; i < cluster.length; i++) {
        final item = cluster[i];
        placed.add(_PlacedEvent(
          event: item.event,
          top: hourHeight * (item.start - startOffsetMinutes) / 60,
          height: (hourHeight * (item.end - item.start) / 60).clamp(minPxHeight, double.infinity),
          columnIndex: columnOf[i],
          columnCount: columnCount,
        ));
      }
    }

    for (var i = 0; i < windows.length; i++) {
      final item = windows[i];
      if (clusterMaxEnd != -1 && item.start >= clusterMaxEnd) {
        flushCluster(i);
        clusterStartIndex = i;
        clusterMaxEnd = item.end;
      } else {
        clusterMaxEnd = clusterMaxEnd == -1 ? item.end : (item.end > clusterMaxEnd ? item.end : clusterMaxEnd);
      }
    }
    flushCluster(windows.length);

    return placed;
  }
}

class _PlacedEvent {
  const _PlacedEvent({
    required this.event,
    required this.top,
    required this.height,
    required this.columnIndex,
    required this.columnCount,
  });

  final BarangayEvent event;
  final double top;
  final double height;
  final int columnIndex;
  final int columnCount;
}

class _TimelineEventBlock extends StatelessWidget {
  const _TimelineEventBlock({
    required this.event,
    required this.color,
    required this.icon,
    required this.compact,
    required this.onTap,
  });

  final BarangayEvent event;
  final Color color;
  final FaIconData icon;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 2, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('day-timeline-event-${event.id}'),
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 2 : 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            alignment: Alignment.topLeft,
            child: compact
                ? Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          FaIcon(icon, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      if (event.location.isNotEmpty)
                        Text(
                          event.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

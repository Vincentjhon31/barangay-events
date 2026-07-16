import 'package:flutter/material.dart';

import 'event_store.dart';

int timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

/// Events in [events] occurring on [date] (any type — public/group/personal,
/// since all of them show up together in a given user's own view) whose
/// time-of-day range overlaps [start]–[end]. For a multi-day event,
/// "occurring on [date]" uses [BarangayEvent.occursOnDay] and its
/// time-of-day is taken from its start/end *clock* time, applied on every
/// day it spans — e.g. a 3-day event timed 7–8 AM only blocks 7–8 AM on
/// each of those days, not the whole day.
List<BarangayEvent> findOverlappingEvents(
  List<BarangayEvent> events,
  DateTime date,
  TimeOfDay start,
  TimeOfDay end,
) {
  final startMinutes = timeToMinutes(start);
  final endMinutes = timeToMinutes(end);

  final overlapping = events.where((event) {
    if (!event.occursOnDay(date)) return false;
    final eventStart = timeToMinutes(TimeOfDay.fromDateTime(event.startTime));
    final eventEnd = timeToMinutes(TimeOfDay.fromDateTime(event.endTime));
    // Half-open interval overlap — back-to-back events (one ending right as
    // another starts) don't count as a conflict.
    return startMinutes < eventEnd && eventStart < endMinutes;
  }).toList();

  overlapping.sort((a, b) => a.startTime.compareTo(b.startTime));
  return overlapping;
}

/// The free time slot on [date], of the same length as [desiredStart]–
/// [desiredEnd], that starts closest to what was originally requested.
/// Null if the day has no gap long enough left, computed against [events].
({TimeOfDay start, TimeOfDay end})? suggestFreeSlot(
  List<BarangayEvent> events,
  DateTime date,
  TimeOfDay desiredStart,
  TimeOfDay desiredEnd,
) {
  final duration = timeToMinutes(desiredEnd) - timeToMinutes(desiredStart);
  if (duration <= 0) return null;

  final busy = events
      .where((event) => event.occursOnDay(date))
      .map((event) => (
            start: timeToMinutes(TimeOfDay.fromDateTime(event.startTime)),
            end: timeToMinutes(TimeOfDay.fromDateTime(event.endTime)),
          ))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  // Merge overlapping/touching busy intervals.
  final merged = <({int start, int end})>[];
  for (final interval in busy) {
    if (merged.isNotEmpty && interval.start <= merged.last.end) {
      final last = merged.removeLast();
      merged.add((
        start: last.start,
        end: interval.end > last.end ? interval.end : last.end,
      ));
    } else {
      merged.add(interval);
    }
  }

  // Free gaps across the whole day.
  final gaps = <({int start, int end})>[];
  var cursor = 0;
  for (final interval in merged) {
    if (interval.start > cursor) {
      gaps.add((start: cursor, end: interval.start));
    }
    cursor = interval.end > cursor ? interval.end : cursor;
  }
  if (cursor < 1440) {
    gaps.add((start: cursor, end: 1440));
  }

  final desiredStartMinutes = timeToMinutes(desiredStart);
  ({int start, int end})? bestGap;
  var bestDistance = 1 << 30;
  for (final gap in gaps) {
    if (gap.end - gap.start < duration) continue;
    final latestFit = gap.end - duration;
    final clampedStart = desiredStartMinutes < gap.start
        ? gap.start
        : (desiredStartMinutes > latestFit ? latestFit : desiredStartMinutes);
    final distance = (clampedStart - desiredStartMinutes).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      bestGap = (start: clampedStart, end: clampedStart + duration);
    }
  }

  if (bestGap == null) return null;
  return (
    start: TimeOfDay(hour: bestGap.start ~/ 60, minute: bestGap.start % 60),
    end: TimeOfDay(hour: bestGap.end ~/ 60, minute: bestGap.end % 60),
  );
}

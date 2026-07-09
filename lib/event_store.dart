import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Visibility levels for an event.
abstract final class EventType {
  static const String public = 'public';
  static const String shared = 'shared';
  static const String personal = 'personal';
}

class BarangayEvent {
  const BarangayEvent({
    required this.id,
    required this.title,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.description,
    required this.hasAttachment,
    required this.createdAt,
    this.attachmentType,
    this.attendanceStatus,
    this.createdByName,
    this.createdByDepartment,
    this.createdById,
    this.eventType = EventType.public,
  });

  final String id;
  final String title;
  final String location;
  final DateTime startTime;
  final DateTime endTime;
  final String description;
  final bool hasAttachment;
  final String? attachmentType;
  final String? attendanceStatus;
  final DateTime createdAt;
  final String? createdByName;
  final String? createdByDepartment;
  final String? createdById;
  final String eventType;

  /// "Name • Department", or whichever half is available; null when neither is.
  String? get creatorLabel {
    final name = createdByName?.trim();
    final department = createdByDepartment?.trim();
    final hasName = name != null && name.isNotEmpty;
    final hasDepartment = department != null && department.isNotEmpty;
    if (hasName && hasDepartment) return '$name • $department';
    if (hasName) return name;
    if (hasDepartment) return department;
    return null;
  }

  DateTime get dayKey => DateTime.utc(startTime.year, startTime.month, startTime.day);

  BarangayEvent copyWith({
    String? attendanceStatus,
  }) {
    return BarangayEvent(
      id: id,
      title: title,
      location: location,
      startTime: startTime,
      endTime: endTime,
      description: description,
      hasAttachment: hasAttachment,
      attachmentType: attachmentType,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      createdAt: createdAt,
      createdByName: createdByName,
      createdByDepartment: createdByDepartment,
      createdById: createdById,
      eventType: eventType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'description': description,
      'hasAttachment': hasAttachment,
      'attachmentType': attachmentType,
      'attendanceStatus': attendanceStatus,
      'createdAt': createdAt.toIso8601String(),
      'createdByName': createdByName,
      'createdByDepartment': createdByDepartment,
      'createdById': createdById,
      'eventType': eventType,
    };
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'day_key': dayKey.toIso8601String(),
      'description': description,
      'has_attachment': hasAttachment,
      'attachment_type': attachmentType,
      'attendance_status': attendanceStatus,
      'created_at': createdAt.toIso8601String(),
      'created_by_name': createdByName,
      'created_by_department': createdByDepartment,
      'created_by_id': createdById,
      'event_type': eventType,
    };
  }

  factory BarangayEvent.fromJson(Map<String, dynamic> json) {
    return BarangayEvent(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Untitled event',
      location: json['location'] as String? ?? 'Unknown location',
      startTime: DateTime.tryParse(json['startTime'] as String? ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse(json['endTime'] as String? ?? '') ?? DateTime.now(),
      description: json['description'] as String? ?? '',
      hasAttachment: json['hasAttachment'] as bool? ?? false,
      attachmentType: json['attachmentType'] as String?,
      attendanceStatus: json['attendanceStatus'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      createdByName: json['createdByName'] as String?,
      createdByDepartment: json['createdByDepartment'] as String?,
      createdById: json['createdById'] as String?,
      eventType: json['eventType'] as String? ?? EventType.public,
    );
  }

  factory BarangayEvent.fromSupabase(Map<String, dynamic> row) {
    return BarangayEvent(
      id: row['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: row['title'] as String? ?? 'Untitled event',
      location: row['location'] as String? ?? 'Unknown location',
      startTime: _readDateTime(row['start_time']) ?? DateTime.now(),
      endTime: _readDateTime(row['end_time']) ?? DateTime.now(),
      description: row['description'] as String? ?? '',
      hasAttachment: row['has_attachment'] as bool? ?? false,
      attachmentType: row['attachment_type'] as String?,
      attendanceStatus: row['attendance_status'] as String?,
      createdAt: _readDateTime(row['created_at']) ?? DateTime.now(),
      createdByName: row['created_by_name'] as String?,
      createdByDepartment: row['created_by_department'] as String?,
      createdById: row['created_by_id'] as String?,
      eventType: row['event_type'] as String? ?? EventType.public,
    );
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

abstract class EventRepository {
  Stream<List<BarangayEvent>> watchAllEvents();
  Future<void> addEvent(BarangayEvent event);
  Future<void> deleteEvent(String eventId);
  Future<void> updateAttendanceStatus(String eventId, String? status);
  Future<void> dispose();
}

class MemoryEventRepository implements EventRepository {
  MemoryEventRepository._(this._events);

  factory MemoryEventRepository.seeded() {
    return MemoryEventRepository._(_seedEvents());
  }

  final StreamController<List<BarangayEvent>> _updates =
      StreamController<List<BarangayEvent>>.broadcast();
  List<BarangayEvent> _events;

  Future<void> initialize() async {}

  @override
  Stream<List<BarangayEvent>> watchAllEvents() async* {
    yield _sortedEvents;
    yield* _updates.stream;
  }

  @override
  Future<void> addEvent(BarangayEvent event) async {
    _events = [..._events, event];
    _updates.add(_sortedEvents);
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    _events = _events.where((event) => event.id != eventId).toList();
    _updates.add(_sortedEvents);
  }

  @override
  Future<void> updateAttendanceStatus(String eventId, String? status) async {
    _events = _events
        .map((event) => event.id == eventId ? event.copyWith(attendanceStatus: status) : event)
        .toList();
    _updates.add(_sortedEvents);
  }

  @override
  Future<void> dispose() async {
    await _updates.close();
  }

  List<BarangayEvent> get _sortedEvents {
    final events = List<BarangayEvent>.from(_events);
    events.sort((a, b) {
      final compare = a.startTime.compareTo(b.startTime);
      if (compare != 0) {
        return compare;
      }
      return a.title.compareTo(b.title);
    });
    return events;
  }
}

class SupabaseEventRepository implements EventRepository {
  SupabaseEventRepository(this._client);

  static const String tableName = 'barangay_events';

  final SupabaseClient _client;

  @override
  Stream<List<BarangayEvent>> watchAllEvents() {
    return _client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .order('start_time')
        .map((rows) => rows.map(BarangayEvent.fromSupabase).toList());
  }

  @override
  Future<void> addEvent(BarangayEvent event) async {
    await _client.from(tableName).insert(event.toSupabaseJson());
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await _client.from(tableName).delete().eq('id', eventId);
  }

  @override
  Future<void> updateAttendanceStatus(String eventId, String? status) async {
    await _client.from(tableName).update({
      'attendance_status': status,
    }).eq('id', eventId);
  }

  @override
  Future<void> dispose() async {
  }
}

Future<EventRepository> createEventRepository() async {
  final repository = SupabaseEventRepository(Supabase.instance.client);
  return repository;
}

List<BarangayEvent> _seedEvents() {
  return [
    BarangayEvent(
      id: 'seed-assembly',
      title: 'Barangay Assembly',
      location: 'Barangay Hall',
      startTime: DateTime(2026, 6, 29, 15, 0),
      endTime: DateTime(2026, 6, 29, 17, 0),
      description: 'Monthly barangay assembly to discuss fiesta preparations',
      hasAttachment: true,
      attachmentType: 'application/pdf',
      createdAt: DateTime(2026, 6, 1),
      createdByName: 'Juan Dela Cruz',
      createdByDepartment: "Mayor's Office",
      createdById: 'mock-user-id',
      eventType: EventType.shared,
    ),
    BarangayEvent(
      id: 'seed-basketball',
      title: 'Basketball Tournament',
      location: 'Covered Court',
      startTime: DateTime(2026, 6, 29, 8, 0),
      endTime: DateTime(2026, 6, 29, 12, 0),
      description: 'Inter-purok basketball tournament - bring your own ball',
      hasAttachment: true,
      attachmentType: 'image/jpeg',
      createdAt: DateTime(2026, 6, 1),
    ),
    BarangayEvent(
      id: 'seed-health',
      title: 'Health Check-up',
      location: 'Barangay Health Center',
      startTime: DateTime(2026, 6, 30, 9, 0),
      endTime: DateTime(2026, 6, 30, 12, 0),
      description: 'Free blood pressure and glucose monitoring',
      hasAttachment: false,
      createdAt: DateTime(2026, 6, 1),
      createdByName: 'Maria Santos',
      createdByDepartment: 'HRMO',
      createdById: 'mock-user-id',
      eventType: EventType.personal,
    ),
    BarangayEvent(
      id: 'seed-fiesta',
      title: 'Fiesta Parade Rehearsal',
      location: 'Main Street',
      startTime: DateTime(2026, 7, 5, 16, 0),
      endTime: DateTime(2026, 7, 5, 18, 0),
      description: 'Practice for upcoming barangay fiesta parade',
      hasAttachment: true,
      attachmentType: 'video/mp4',
      createdAt: DateTime(2026, 6, 1),
    ),
  ];
}

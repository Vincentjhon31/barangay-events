import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Visibility levels for an event.
abstract final class EventType {
  static const String public = 'public';
  static const String shared = 'shared';
  static const String personal = 'personal';
}

/// A per-day time-of-day override for one specific day of a multi-day
/// event — e.g. day 1 all day (0-1440), day 2 just 1-5 PM. Days not
/// listed in [BarangayEvent.dailyOverrides] fall back to the event's own
/// [BarangayEvent.startTime]/[endTime] clock-time applied uniformly (the
/// original, pre-override behavior — see [[project-event-sharing-model]]).
/// Minutes-since-midnight (not `TimeOfDay`) so this data-layer file
/// doesn't need to depend on Flutter's material library — UI code
/// converts at the boundary (`add_event_page.dart`).
class DailyOverride {
  const DailyOverride({
    required this.day,
    required this.startMinutes,
    required this.endMinutes,
  });

  /// Normalized via DateTime.utc(y,m,d) — matches [BarangayEvent.dayKey].
  final DateTime day;
  final int startMinutes;
  final int endMinutes;

  Map<String, dynamic> toJson() => {
        'day': day.toIso8601String(),
        'start_minutes': startMinutes,
        'end_minutes': endMinutes,
      };

  factory DailyOverride.fromJson(Map<String, dynamic> json) {
    final day = DateTime.parse(json['day'] as String);
    return DailyOverride(
      day: DateTime.utc(day.year, day.month, day.day),
      startMinutes: json['start_minutes'] as int,
      endMinutes: json['end_minutes'] as int,
    );
  }
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
    this.groupId,
    this.groupName,
    this.dailyOverrides = const [],
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

  /// For group ("shared") events: which group the event was posted to.
  /// [groupName] is denormalized for display, like [createdByName].
  final String? groupId;
  final String? groupName;

  /// Per-day time-of-day overrides for a multi-day event — see
  /// [DailyOverride]. Empty for the common case (every spanned day uses
  /// this event's own [startTime]/[endTime] clock-time uniformly).
  final List<DailyOverride> dailyOverrides;

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

  /// The calendar day [endTime] falls on, normalized the same way as [dayKey].
  DateTime get endDayKey => DateTime.utc(endTime.year, endTime.month, endTime.day);

  /// True when the event spans more than one calendar day.
  bool get isMultiDay => endDayKey.isAfter(dayKey);

  /// Whether this event is happening on [day] — i.e. [day] falls anywhere
  /// within [dayKey]..[endDayKey] inclusive, not just on the start day.
  bool occursOnDay(DateTime day) {
    final normalized = DateTime.utc(day.year, day.month, day.day);
    return !normalized.isBefore(dayKey) && !normalized.isAfter(endDayKey);
  }

  /// The (startMinutes, endMinutes) time-of-day window that applies on
  /// [day] — the matching [dailyOverrides] entry if [day] has one,
  /// otherwise this event's own start/end clock-time (the original
  /// uniform-every-day behavior, unchanged for any event that has never
  /// had a per-day override set).
  ({int startMinutes, int endMinutes}) minutesWindowForDay(DateTime day) {
    final normalized = DateTime.utc(day.year, day.month, day.day);
    for (final override in dailyOverrides) {
      if (override.day == normalized) {
        return (startMinutes: override.startMinutes, endMinutes: override.endMinutes);
      }
    }
    return (
      startMinutes: startTime.hour * 60 + startTime.minute,
      endMinutes: endTime.hour * 60 + endTime.minute,
    );
  }

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
      groupId: groupId,
      groupName: groupName,
      dailyOverrides: dailyOverrides,
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
      'groupId': groupId,
      'groupName': groupName,
      'dailyOverrides': dailyOverrides.map((o) => o.toJson()).toList(),
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
      'group_id': groupId,
      'group_name': groupName,
      'daily_overrides': dailyOverrides.map((o) => o.toJson()).toList(),
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
      groupId: json['groupId'] as String?,
      groupName: json['groupName'] as String?,
      dailyOverrides: (json['dailyOverrides'] as List<dynamic>?)
              ?.map((e) => DailyOverride.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
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
      groupId: row['group_id'] as String?,
      groupName: row['group_name'] as String?,
      dailyOverrides: (row['daily_overrides'] as List<dynamic>?)
              ?.map((e) => DailyOverride.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
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

/// A group (group-chat style): one code, many members; group events are
/// visible to every member.
class BarangayGroup {
  const BarangayGroup({
    required this.id,
    required this.name,
    required this.code,
    this.memberCount = 0,
    this.createdBy,
    this.isPrivate = false,
    this.myRole,
  });

  final String id;
  final String name;
  final String code;
  final int memberCount;
  final String? createdBy;

  /// Hidden from search; joining requires a request the creator accepts.
  final bool isPrivate;

  /// The caller's role in this group ('admin' | 'member'), or null if the
  /// caller isn't a member (e.g. a search result they haven't joined).
  final String? myRole;

  bool get isAdmin => myRole == 'admin';

  BarangayGroup copyWith({
    int? memberCount,
    String? myRole,
  }) {
    return BarangayGroup(
      id: id,
      name: name,
      code: code,
      memberCount: memberCount ?? this.memberCount,
      createdBy: createdBy,
      isPrivate: isPrivate,
      myRole: myRole ?? this.myRole,
    );
  }
}

/// One member of a [BarangayGroup]'s roster — name/avatar are a
/// denormalized snapshot taken when they joined (mirrors how
/// BarangayEvent.createdByName works), not a live profile lookup.
class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
    this.accountRole = 'citizen',
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;

  /// 'admin' | 'member' — this person's standing within THIS group. Not
  /// to be confused with [accountRole].
  final String role;
  final DateTime joinedAt;

  /// 'citizen' | 'lgu_member' | 'superadmin' — this person's app-wide
  /// account role (see [[project-event-sharing-model]]/AppUserProfile.role),
  /// shown via RoleAvatarFrame next to their group-admin star, not to be
  /// confused with [role] (their admin/member standing in THIS group).
  final String accountRole;

  bool get isAdmin => role == 'admin';

  GroupMember copyWith({String? role}) {
    return GroupMember(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      role: role ?? this.role,
      joinedAt: joinedAt,
      accountRole: accountRole,
    );
  }
}

/// A pending request to join one of the current user's private groups,
/// awaiting their Accept/Decline.
class GroupJoinRequest {
  const GroupJoinRequest({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.requesterId,
    this.requesterName,
    this.requesterDepartment,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String groupName;
  final String requesterId;
  final String? requesterName;
  final String? requesterDepartment;
  final DateTime createdAt;

  String get requesterLabel {
    final name = requesterName?.trim();
    final department = requesterDepartment?.trim();
    final hasName = name != null && name.isNotEmpty;
    final hasDepartment = department != null && department.isNotEmpty;
    if (hasName && hasDepartment) return '$name • $department';
    if (hasName) return name;
    if (hasDepartment) return department;
    return 'Someone';
  }
}

/// Outcome of [EventRepository.requestOrJoinGroupByCode].
enum GroupJoinStatus { joined, pending, alreadyMember }

class GroupJoinResult {
  const GroupJoinResult({required this.group, required this.status});

  final BarangayGroup group;
  final GroupJoinStatus status;
}

abstract class EventRepository {
  Stream<List<BarangayEvent>> watchAllEvents();
  Future<void> addEvent(BarangayEvent event);

  /// Full edit of an existing event (title, location, description,
  /// date/time, type, group, per-day overrides — everything except its
  /// [BarangayEvent.id]/[BarangayEvent.createdAt]/creator fields, which
  /// never change). Restricted server-side to the event's creator or an
  /// admin of the group it's posted to (see [[project-event-sharing-model]]).
  Future<void> updateEvent(BarangayEvent event);

  Future<void> deleteEvent(String eventId);
  Future<void> updateAttendanceStatus(String eventId, String? status);

  /// Groups the current user belongs to.
  Future<List<BarangayGroup>> listMyGroups();

  /// Searches all groups by name.
  Future<List<BarangayGroup>> searchGroups(String query);

  /// Creates a group (the creator automatically becomes a member).
  Future<BarangayGroup> createGroup(String name, {bool isPrivate = false});

  /// Looks up the group behind [code]. Public groups join instantly; private
  /// ones file a request the creator must accept — check the result's
  /// [GroupJoinResult.status] to know which happened.
  Future<GroupJoinResult> requestOrJoinGroupByCode(String code);

  /// Joins [groupId] directly (from search results — only ever a public
  /// group, since private ones never appear in search results).
  Future<void> joinGroup(String groupId);

  /// Leaves [groupId].
  Future<void> leaveGroup(String groupId);

  /// How many members [groupId] has right now.
  Future<int> fetchGroupMemberCount(String groupId);

  /// Pending join requests for groups the current user created.
  Future<List<GroupJoinRequest>> listPendingJoinRequests();

  /// Accepts or declines a pending request (creator-only).
  Future<void> respondToJoinRequest(String requestId, {required bool accept});

  /// Full member roster for [groupId] — callable only by one of that
  /// group's own members.
  Future<List<GroupMember>> listGroupMembers(String groupId);

  /// Promotes [userId] to admin within [groupId] (any admin may do this).
  Future<void> promoteMember(String groupId, String userId);

  /// Removes [userId] from [groupId]. Any admin may remove a regular
  /// member; only the group's creator may remove a fellow admin.
  Future<void> removeMember(String groupId, String userId);

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
  Future<void> updateEvent(BarangayEvent event) async {
    _events = _events.map((e) => e.id == event.id ? event : e).toList();
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

  // Group state for the in-memory repo; the "current user" matches
  // MemoryAuthService's mock account.
  static const String _mockUserId = 'mock-user-id';
  final List<BarangayGroup> _allGroups = [
    const BarangayGroup(
      id: 'grp-mayor',
      name: "Mayor's Office Updates",
      code: 'MAYOR1',
      memberCount: 24,
      createdBy: 'mayor-1',
    ),
    const BarangayGroup(
      id: 'grp-basketball',
      name: 'Basketball League',
      code: 'B4LL22',
      memberCount: 12,
      createdBy: 'hrmo-1',
    ),
    // Private, owned by someone else — exercises the "request, don't join"
    // path when the mock user enters its code.
    const BarangayGroup(
      id: 'grp-council',
      name: 'Barangay Council',
      code: 'COUNCIL',
      memberCount: 5,
      createdBy: 'hrmo-1',
      isPrivate: true,
    ),
    // Private, owned by the mock user, with a seeded pending request below
    // — exercises the approval UI without any setup.
    const BarangayGroup(
      id: 'grp-private-mock',
      name: 'Trusted Circle',
      code: 'CIRCLE',
      memberCount: 1,
      createdBy: _mockUserId,
      isPrivate: true,
    ),
  ];
  // Note: intentionally starts empty, even though 'grp-private-mock' above
  // is "created by" the mock user — tests rely on a fresh account having
  // zero groups. Membership isn't needed for listPendingJoinRequests()
  // (that's scoped by createdBy, not _myGroupIds), so the seeded pending
  // request below still shows up in the approval inbox regardless.
  final Set<String> _myGroupIds = {};
  // The mock user's role in each group they belong to.
  final Map<String, String> _myRoleByGroupId = {};
  final Map<String, List<GroupMember>> _members = {
    'grp-mayor': [
      GroupMember(
        userId: 'mayor-1',
        displayName: "Mayor's Office",
        role: 'admin',
        joinedAt: DateTime.now().subtract(const Duration(days: 200)),
        accountRole: 'lgu_member',
      ),
      GroupMember(
        userId: 'staff-1',
        displayName: 'Liza Santos',
        role: 'member',
        joinedAt: DateTime.now().subtract(const Duration(days: 150)),
        accountRole: 'citizen',
      ),
    ],
    'grp-basketball': [
      GroupMember(
        userId: 'hrmo-1',
        displayName: 'Mark Villanueva',
        role: 'admin',
        joinedAt: DateTime.now().subtract(const Duration(days: 90)),
        accountRole: 'lgu_member',
      ),
    ],
  };
  final List<GroupJoinRequest> _pendingRequests = [
    GroupJoinRequest(
      id: 'req-seed-1',
      groupId: 'grp-private-mock',
      groupName: 'Trusted Circle',
      requesterId: 'health-1',
      requesterName: 'Pedro Reyes',
      requesterDepartment: 'Health Office',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];
  int _groupCounter = 0;
  int _requestCounter = 0;

  @override
  Future<List<BarangayGroup>> listMyGroups() async {
    return _allGroups
        .where((group) => _myGroupIds.contains(group.id))
        .map((group) => group.copyWith(myRole: _myRoleByGroupId[group.id]))
        .toList();
  }

  @override
  Future<List<BarangayGroup>> searchGroups(String query) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return _allGroups
        .where((group) =>
            group.name.toLowerCase().contains(needle) &&
            (!group.isPrivate || _myGroupIds.contains(group.id)))
        .toList();
  }

  @override
  Future<BarangayGroup> createGroup(String name, {bool isPrivate = false}) async {
    _groupCounter++;
    final group = BarangayGroup(
      id: 'grp-local-$_groupCounter',
      name: name,
      code: 'NEW${_groupCounter.toString().padLeft(3, '0')}',
      memberCount: 1,
      createdBy: _mockUserId,
      isPrivate: isPrivate,
    );
    _allGroups.add(group);
    _myGroupIds.add(group.id);
    _myRoleByGroupId[group.id] = 'admin';
    _members.putIfAbsent(group.id, () => []).add(
          GroupMember(
            userId: _mockUserId,
            displayName: 'You',
            role: 'admin',
            joinedAt: DateTime.now(),
          ),
        );
    return group;
  }

  @override
  Future<GroupJoinResult> requestOrJoinGroupByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    final group = _allGroups
        .where((group) => group.code.toUpperCase() == normalized)
        .firstOrNull;
    if (group == null) {
      throw Exception('Invalid group code');
    }

    if (_myGroupIds.contains(group.id)) {
      return GroupJoinResult(group: group, status: GroupJoinStatus.alreadyMember);
    }

    if (!group.isPrivate) {
      _joinAsMockMember(group.id);
      return GroupJoinResult(group: group, status: GroupJoinStatus.joined);
    }

    _requestCounter++;
    _pendingRequests.add(GroupJoinRequest(
      id: 'req-local-$_requestCounter',
      groupId: group.id,
      groupName: group.name,
      requesterId: _mockUserId,
      requesterName: 'You',
      createdAt: DateTime.now(),
    ));
    return GroupJoinResult(group: group, status: GroupJoinStatus.pending);
  }

  void _joinAsMockMember(String groupId) {
    _myGroupIds.add(groupId);
    _myRoleByGroupId[groupId] = 'member';
    _members.putIfAbsent(groupId, () => []).add(
          GroupMember(
            userId: _mockUserId,
            displayName: 'You',
            role: 'member',
            joinedAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<void> joinGroup(String groupId) async {
    if (!_allGroups.any((group) => group.id == groupId)) {
      throw Exception('Group not found');
    }
    _joinAsMockMember(groupId);
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    _myGroupIds.remove(groupId);
    _myRoleByGroupId.remove(groupId);
    _members[groupId]?.removeWhere((member) => member.userId == _mockUserId);
  }

  @override
  Future<int> fetchGroupMemberCount(String groupId) async {
    return _allGroups
            .where((group) => group.id == groupId)
            .firstOrNull
            ?.memberCount ??
        0;
  }

  @override
  Future<List<GroupJoinRequest>> listPendingJoinRequests() async {
    // Only requests for groups the mock user themself created — matches the
    // real RLS/RPC scoping ("your own approval inbox").
    final myGroupIds = _allGroups
        .where((group) => group.createdBy == _mockUserId)
        .map((group) => group.id)
        .toSet();
    return _pendingRequests.where((r) => myGroupIds.contains(r.groupId)).toList();
  }

  @override
  Future<void> respondToJoinRequest(String requestId, {required bool accept}) async {
    final request = _pendingRequests.where((r) => r.id == requestId).firstOrNull;
    if (request == null) return;

    _pendingRequests.removeWhere((r) => r.id == requestId);

    if (accept) {
      final index = _allGroups.indexWhere((group) => group.id == request.groupId);
      if (index != -1) {
        final group = _allGroups[index];
        _allGroups[index] = group.copyWith(memberCount: group.memberCount + 1);
        _members.putIfAbsent(group.id, () => []).add(
              GroupMember(
                userId: request.requesterId,
                displayName: request.requesterName ?? 'Someone',
                role: 'member',
                joinedAt: DateTime.now(),
              ),
            );
      }
    }
  }

  @override
  Future<List<GroupMember>> listGroupMembers(String groupId) async {
    return List.unmodifiable(_members[groupId] ?? const []);
  }

  @override
  Future<void> promoteMember(String groupId, String userId) async {
    final members = _members[groupId];
    if (members == null) return;
    final index = members.indexWhere((member) => member.userId == userId);
    if (index == -1) return;
    members[index] = members[index].copyWith(role: 'admin');
    if (userId == _mockUserId) _myRoleByGroupId[groupId] = 'admin';
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    _members[groupId]?.removeWhere((member) => member.userId == userId);
    final index = _allGroups.indexWhere((group) => group.id == groupId);
    if (index != -1) {
      final group = _allGroups[index];
      _allGroups[index] =
          group.copyWith(memberCount: group.memberCount > 0 ? group.memberCount - 1 : 0);
    }
    if (userId == _mockUserId) {
      _myGroupIds.remove(groupId);
      _myRoleByGroupId.remove(groupId);
    }
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
  Future<void> updateEvent(BarangayEvent event) async {
    await _client.from(tableName).update(event.toSupabaseJson()).eq('id', event.id);
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

  BarangayGroup _groupFromRow(Map<String, dynamic> row) {
    final members = row['group_members'];
    var memberCount = 0;
    if (members is List && members.isNotEmpty) {
      final first = members.first;
      if (first is Map<String, dynamic>) {
        memberCount = first['count'] as int? ?? 0;
      }
    }
    return BarangayGroup(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Unnamed group',
      code: row['code'] as String? ?? '',
      memberCount: memberCount,
      createdBy: row['created_by'] as String?,
      isPrivate: row['is_private'] as bool? ?? false,
    );
  }

  @override
  Future<List<BarangayGroup>> listMyGroups() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final memberships = await _client
        .from('group_members')
        .select('group_id, role')
        .eq('user_id', userId);
    final roleByGroupId = {
      for (final row in memberships)
        row['group_id'] as String: row['role'] as String? ?? 'member',
    };
    if (roleByGroupId.isEmpty) return const [];

    final rows = await _client
        .from('groups')
        .select('id, name, code, created_by, is_private, group_members(count)')
        .inFilter('id', roleByGroupId.keys.toList())
        .order('name', ascending: true);
    return rows
        .map((row) => _groupFromRow(row).copyWith(myRole: roleByGroupId[row['id']]))
        .toList();
  }

  /// Snapshot of the caller's own display name/avatar, denormalized onto a
  /// group_members row at join time (mirrors barangay_events.created_by_name).
  Future<Map<String, String?>> _ownProfileSnapshot(String userId) async {
    final row = await _client
        .from('profiles')
        .select('display_name, email, avatar_url')
        .eq('id', userId)
        .maybeSingle();
    final rawName = row?['display_name'] as String?;
    final displayName = rawName?.trim().isNotEmpty == true ? rawName : row?['email'] as String?;
    return {'display_name': displayName, 'avatar_url': row?['avatar_url'] as String?};
  }

  @override
  Future<List<BarangayGroup>> searchGroups(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    // Private groups the caller isn't in simply don't come back here — the
    // "View public groups, or your own/joined private ones" RLS policy
    // enforces that server-side, so no client-side filtering is needed.
    final rows = await _client
        .from('groups')
        .select('id, name, code, created_by, is_private, group_members(count)')
        .ilike('name', '%$trimmed%')
        .order('name', ascending: true)
        .limit(20);
    return rows.map(_groupFromRow).toList();
  }

  @override
  Future<BarangayGroup> createGroup(String name, {bool isPrivate = false}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You must be signed in to create a group');
    }

    final row = await _client
        .from('groups')
        .insert({
          'name': name.trim(),
          'created_by': userId,
          'is_private': isPrivate,
        })
        .select('id, name, code, created_by')
        .single();
    final groupId = row['id'] as String;
    final snapshot = await _ownProfileSnapshot(userId);
    await _client.from('group_members').insert({
      'group_id': groupId,
      'user_id': userId,
      'role': 'admin',
      'display_name': snapshot['display_name'],
      'avatar_url': snapshot['avatar_url'],
    });

    return BarangayGroup(
      id: groupId,
      name: row['name'] as String? ?? name,
      code: row['code'] as String? ?? '',
      memberCount: 1,
      createdBy: userId,
      isPrivate: isPrivate,
      myRole: 'admin',
    );
  }

  @override
  Future<GroupJoinResult> requestOrJoinGroupByCode(String code) async {
    final rows = await _client.rpc(
      'request_or_join_group',
      params: {'p_code': code},
    ) as List<dynamic>;
    if (rows.isEmpty) {
      throw Exception('Invalid group code');
    }

    final row = rows.first as Map<String, dynamic>;
    final status = switch (row['out_status'] as String?) {
      'joined' => GroupJoinStatus.joined,
      'already_member' => GroupJoinStatus.alreadyMember,
      _ => GroupJoinStatus.pending,
    };
    final group = BarangayGroup(
      id: row['out_group_id'] as String,
      name: row['out_group_name'] as String? ?? 'Unnamed group',
      code: code.trim().toUpperCase(),
    );
    return GroupJoinResult(group: group, status: status);
  }

  @override
  Future<void> joinGroup(String groupId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final snapshot = await _ownProfileSnapshot(userId);
    await _client.from('group_members').upsert(
      {
        'group_id': groupId,
        'user_id': userId,
        'role': 'member',
        'display_name': snapshot['display_name'],
        'avatar_url': snapshot['avatar_url'],
      },
      onConflict: 'group_id,user_id',
      ignoreDuplicates: true,
    );
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  @override
  Future<int> fetchGroupMemberCount(String groupId) async {
    final rows = await _client
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId);
    return rows.length;
  }

  @override
  Future<List<GroupJoinRequest>> listPendingJoinRequests() async {
    final rows = await _client.rpc('list_pending_join_requests') as List<dynamic>;
    return rows.map((row) {
      final map = row as Map<String, dynamic>;
      return GroupJoinRequest(
        id: map['request_id'] as String,
        groupId: map['group_id'] as String,
        groupName: map['group_name'] as String? ?? 'Unnamed group',
        requesterId: map['requester_id'] as String,
        requesterName: map['requester_name'] as String?,
        requesterDepartment: map['requester_department'] as String?,
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<void> respondToJoinRequest(String requestId, {required bool accept}) async {
    await _client.rpc('respond_to_join_request', params: {
      'request_id': requestId,
      'accept': accept,
    });
  }

  @override
  Future<List<GroupMember>> listGroupMembers(String groupId) async {
    final rows = await _client.rpc(
      'list_group_members',
      params: {'p_group_id': groupId},
    ) as List<dynamic>;
    return rows.map((row) {
      final map = row as Map<String, dynamic>;
      final rawName = map['member_display_name'] as String?;
      return GroupMember(
        userId: map['member_user_id'] as String,
        displayName: rawName?.trim().isNotEmpty == true ? rawName! : 'Someone',
        avatarUrl: map['member_avatar_url'] as String?,
        role: map['member_role'] as String? ?? 'member',
        joinedAt: DateTime.tryParse(map['member_joined_at'] as String? ?? '') ?? DateTime.now(),
        accountRole: map['member_account_role'] as String? ?? 'citizen',
      );
    }).toList();
  }

  @override
  Future<void> promoteMember(String groupId, String userId) async {
    await _client
        .from('group_members')
        .update({'role': 'admin'})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
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
  // "Mayor Staff Meeting" below is relied on by tests as *today's* seeded
  // event (day-detail/list-view flows tap into "today" to exercise it) —
  // computed off DateTime.now() rather than a fixed date so the suite
  // doesn't silently break the next time it's run on a different day.
  final today = DateTime.now();
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
      id: 'seed-mayor-meeting',
      title: 'Mayor Staff Meeting',
      location: "Mayor's Office",
      // Deliberately a narrow, fixed 10-11 AM slot (not e.g. spanning the
      // whole day) — widening it to always stay "upcoming" regardless of
      // time-of-day previously made it overlap AddEventPage's fixed 9-10 AM
      // default for every newly-created test event, tripping conflict
      // detection across unrelated tests. Tests that specifically need an
      // always-upcoming event add their own (see the "Upcoming" mode tests
      // in test/widget_test.dart) rather than relying on this one's timing.
      startTime: DateTime(today.year, today.month, today.day, 10, 0),
      endTime: DateTime(today.year, today.month, today.day, 11, 0),
      description: 'Weekly coordination meeting with department heads',
      hasAttachment: false,
      createdAt: DateTime(2026, 7, 8),
      createdByName: 'Juan Dela Cruz',
      createdByDepartment: "Mayor's Office",
      createdById: 'mayor-1',
      eventType: EventType.shared,
      groupId: 'grp-mayor',
      groupName: "Mayor's Office Updates",
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

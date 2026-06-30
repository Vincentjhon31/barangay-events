import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(
    BarangayCalendarApp(
      updateService: GitHubReleaseUpdateService(
        repositoryOwner: 'Vincentjhon31',
        repositoryName: 'barangay-events',
      ),
    ),
  );
}

class BarangayCalendarApp extends StatelessWidget {
  const BarangayCalendarApp({super.key, this.updateService});

  final AppUpdateService? updateService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barangay Calendar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: CalendarScreen(updateService: updateService),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.updateService});

  final AppUpdateService? updateService;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  AppUpdateInfo? _availableUpdate;
  bool _checkingForUpdate = false;

  // Sample events for demonstration (replace with Firebase later)
  final Map<DateTime, List<Map<String, dynamic>>> _sampleEvents = {
    DateTime.utc(2026, 6, 29): [
      // Today
      {
        'title': 'Barangay Assembly',
        'location': 'Barangay Hall',
        'startTime': DateTime(2026, 6, 29, 15, 0),
        'endTime': DateTime(2026, 6, 29, 17, 0),
        'description':
            'Monthly barangay assembly to discuss fiesta preparations',
        'hasAttachment': true,
        'attachmentType': 'application/pdf'
      },
      {
        'title': 'Basketball Tournament',
        'location': 'Covered Court',
        'startTime': DateTime(2026, 6, 29, 8, 0),
        'endTime': DateTime(2026, 6, 29, 12, 0),
        'description':
            'Inter-purok basketball tournament - bring your own ball',
        'hasAttachment': true,
        'attachmentType': 'image/jpeg'
      }
    ],
    DateTime.utc(2026, 6, 30): [
      // Tomorrow
      {
        'title': 'Health Check-up',
        'location': 'Barangay Health Center',
        'startTime': DateTime(2026, 6, 30, 9, 0),
        'endTime': DateTime(2026, 6, 30, 12, 0),
        'description': 'Free blood pressure and glucose monitoring',
        'hasAttachment': false
      }
    ],
    DateTime.utc(2026, 7, 5): [
      // Next week
      {
        'title': 'Fiesta Parade Rehearsal',
        'location': 'Main Street',
        'startTime': DateTime(2026, 7, 5, 16, 0),
        'endTime': DateTime(2026, 7, 5, 18, 0),
        'description': 'Practice for upcoming barangay fiesta parade',
        'hasAttachment': true,
        'attachmentType': 'video/mp4'
      }
    ]
  };

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    // Normalize the day to ignore time component
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return _sampleEvents[normalizedDay] ?? [];
  }

  @override
  void initState() {
    super.initState();
    unawaited(_checkForUpdates(showDialogWhenAvailable: true));
  }

  Future<void> _checkForUpdates({bool showDialogWhenAvailable = false}) async {
    final updateService = widget.updateService;
    if (updateService == null || _checkingForUpdate) return;

    setState(() => _checkingForUpdate = true);

    try {
      final update = await updateService.checkForUpdate();
      if (!mounted) return;

      setState(() {
        _availableUpdate = update;
      });

      if (update != null && showDialogWhenAvailable) {
        _showUpdateDialog(update);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not check for app updates right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _checkingForUpdate = false);
      }
    }
  }

  void _showUpdateDialog(AppUpdateInfo update) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update available'),
        content: Text(
          'Version ${update.latestVersion} is ready. Install it over this app to keep your data and settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              unawaited(_openUpdate(update));
            },
            icon: const Icon(Icons.system_update_alt),
            label: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUpdate(AppUpdateInfo update) async {
    final uri = Uri.parse(update.downloadUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the update link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barangay Events Calendar'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_availableUpdate != null) _buildUpdateBanner(_availableUpdate!),

          // Calendar Section
          _buildCalendar(),

          // Divider
          const Divider(height: 1),

          // Events List
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildUpdateBanner(AppUpdateInfo update) {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.system_update,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Version ${update.latestVersion} is available',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => unawaited(_openUpdate(update)),
                child: const Text('Update'),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: () => setState(() => _availableUpdate = null),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
      calendarBuilders: CalendarBuilders(
        // Show event markers below dates
        markerBuilder: (context, date, events) {
          final dayEvents = _getEventsForDay(date);
          if (dayEvents.isEmpty) return null;

          return Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                shape: BoxShape.circle,
              ),
            ),
          );
        },

        // Highlight today
        todayBuilder: (context, day, focusedDay) {
          return Container(
            margin: const EdgeInsets.all(4.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              day.day.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },

        // Customize selected day
        selectedBuilder: (context, day, focusedDay) {
          return Container(
            margin: const EdgeInsets.all(4.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              day.day.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
      // Styling
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        formatButtonShowsNext: false,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        weekendStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay ?? _focusedDay);

    if (events.isEmpty) {
      return Center(
        child: Text(
          'No events for ${DateFormat('EEEE, MMM d, yyyy').format(_selectedDay ?? _focusedDay)}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final startTime = event['startTime'] as DateTime;
    final endTime = event['endTime'] as DateTime;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            _getEventIcon(event['title']),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          event['title'],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '📍 ${event['location']}',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '⏰ ${_formatTime(startTime)} - ${_formatTime(endTime)}',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            if (event['description'] != null && event['description'].isNotEmpty)
              Text(
                event['description'],
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (event['hasAttachment'] == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      _getFileIcon(event['attachmentType']),
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Attachment available',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleEventAction(value, event),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'going',
              child: Text('Going'),
            ),
            const PopupMenuItem(
              value: 'maybe',
              child: Text('Maybe'),
            ),
            const PopupMenuItem(
              value: 'not_going',
              child: Text('Not Going'),
            ),
          ],
          icon: const Icon(Icons.more_vert),
        ),
      ),
    );
  }

  IconData _getEventIcon(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('meeting') || lowerTitle.contains('assembly')) {
      return Icons.meeting_room;
    }
    if (lowerTitle.contains('basketball') ||
        lowerTitle.contains('sport') ||
        lowerTitle.contains('tournament')) {
      return Icons.sports_basketball;
    }
    if (lowerTitle.contains('health') ||
        lowerTitle.contains('checkup') ||
        lowerTitle.contains('medical')) {
      return Icons.local_hospital;
    }
    if (lowerTitle.contains('fiesta') ||
        lowerTitle.contains('parade') ||
        lowerTitle.contains('festival')) {
      return Icons.celebration;
    }
    if (lowerTitle.contains('health')) {
      return Icons.local_hospital;
    }
    return Icons.event;
  }

  IconData _getFileIcon(String mimeType) {
    if (mimeType.contains('image')) return Icons.image;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('video')) return Icons.videocam;
    if (mimeType.contains('audio')) return Icons.music_note;
    return Icons.insert_drive_file;
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _handleEventAction(String action, Map<String, dynamic> event) {
    // In a real app, this would update Firestore/Laravel backend
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'You selected: ${action.toUpperCase()} for "${event['title']}"'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showAddEventDialog(BuildContext context) {
    // Simple placeholder - we'll implement this fully later
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Event'),
        content: const Text(
            'Event creation screen coming soon!\n\nFor now, check the sample events on today\'s date.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

abstract class AppUpdateService {
  Future<AppUpdateInfo?> checkForUpdate();
}

class GitHubReleaseUpdateService implements AppUpdateService {
  GitHubReleaseUpdateService({
    required this.repositoryOwner,
    required this.repositoryName,
  });

  final String repositoryOwner;
  final String repositoryName;

  @override
  Future<AppUpdateInfo?> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final currentBuildNumber = packageInfo.buildNumber;
    final latestRelease = await _fetchLatestRelease();
    final latestVersion = _normalizeVersion(latestRelease.tagName);

    if (!_isNewerVersion(
      latestVersion,
      '$currentVersion+$currentBuildNumber',
    )) {
      return null;
    }

    return AppUpdateInfo(
      latestVersion: latestVersion,
      releaseUrl: latestRelease.releaseUrl,
      downloadUrl: latestRelease.apkDownloadUrl ?? latestRelease.releaseUrl,
    );
  }

  Future<_GitHubRelease> _fetchLatestRelease() async {
    final client = HttpClient();
    try {
      final uri = Uri.https(
        'api.github.com',
        '/repos/$repositoryOwner/$repositoryName/releases/latest',
      );
      final request = await client.getUrl(uri);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'barangay-events-app');

      final response = await request.close();
      final body = await utf8.decodeStream(response);

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'GitHub release check failed with status ${response.statusCode}',
          uri: uri,
        );
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final assets = (json['assets'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>();
      String? apkDownloadUrl;

      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        final url = asset['browser_download_url'] as String?;
        if (name.toLowerCase().endsWith('.apk') && url != null) {
          apkDownloadUrl = url;
          break;
        }
      }

      return _GitHubRelease(
        tagName: json['tag_name'] as String? ?? '',
        releaseUrl: json['html_url'] as String? ?? '',
        apkDownloadUrl: apkDownloadUrl,
      );
    } finally {
      client.close();
    }
  }
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.releaseUrl,
    required this.downloadUrl,
  });

  final String latestVersion;
  final String releaseUrl;
  final String downloadUrl;
}

class _GitHubRelease {
  const _GitHubRelease({
    required this.tagName,
    required this.releaseUrl,
    required this.apkDownloadUrl,
  });

  final String tagName;
  final String releaseUrl;
  final String? apkDownloadUrl;
}

String _normalizeVersion(String version) {
  return version.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
}

bool _isNewerVersion(String latestVersion, String currentVersion) {
  final latest = _Version.parse(latestVersion);
  final current = _Version.parse(currentVersion);
  return latest.compareTo(current) > 0;
}

class _Version implements Comparable<_Version> {
  const _Version(this.major, this.minor, this.patch, this.build);

  factory _Version.parse(String input) {
    final normalized = _normalizeVersion(input);
    final parts = normalized.split('+');
    final versionParts = parts.first.split('.');

    int valueAt(int index) {
      if (index >= versionParts.length) return 0;
      return int.tryParse(
              versionParts[index].replaceAll(RegExp(r'\D.*$'), '')) ??
          0;
    }

    return _Version(
      valueAt(0),
      valueAt(1),
      valueAt(2),
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  final int major;
  final int minor;
  final int patch;
  final int build;

  @override
  int compareTo(_Version other) {
    final comparisons = [
      major.compareTo(other.major),
      minor.compareTo(other.minor),
      patch.compareTo(other.patch),
      build.compareTo(other.build),
    ];

    return comparisons.firstWhere((value) => value != 0, orElse: () => 0);
  }
}

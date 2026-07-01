import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_service.dart';
import 'event_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://xuxnoydakqembrytdbyz.supabase.co',
    anonKey: 'sb_publishable_XnqlZ-m2efmbasNuZ7fyVg_74qTnghA',
  );

  runApp(
    BarangayCalendarApp(
      updateService: GitHubReleaseUpdateService(
        repositoryOwner: 'Vincentjhon31',
        repositoryName: 'barangay-events',
      ),
    ),
  );
}

class BarangayCalendarApp extends StatefulWidget {
  const BarangayCalendarApp({
    super.key,
    this.updateService,
    this.authServiceFactory,
    this.eventRepositoryFactory,
  });

  final AppUpdateService? updateService;
  final Future<AppAuthService> Function()? authServiceFactory;
  final Future<EventRepository> Function()? eventRepositoryFactory;

  @override
  State<BarangayCalendarApp> createState() => _BarangayCalendarAppState();
}

class _BarangayCalendarAppState extends State<BarangayCalendarApp> {
  late final Future<AppAuthService> _authServiceFuture;
  AppAuthService? _resolvedAuthService;

  @override
  void initState() {
    super.initState();
    _authServiceFuture =
        widget.authServiceFactory?.call() ?? Future.value(SupabaseAuthService(Supabase.instance.client));
    unawaited(_authServiceFuture.then((authService) {
      if (mounted) {
        _resolvedAuthService = authService;
      }
    }));
  }

  @override
  void dispose() {
    unawaited(_resolvedAuthService?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barangay Calendar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: FutureBuilder<AppAuthService>(
        future: _authServiceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final authService = snapshot.data;
          if (authService == null) {
            return const Scaffold(
              body: Center(child: Text('Could not load authentication.')),
            );
          }

          return StreamBuilder<bool>(
            stream: authService.authStateChanges(),
            initialData: authService.isSignedIn,
            builder: (context, authSnapshot) {
              final signedIn = authSnapshot.data ?? false;

              if (!signedIn) {
                return SignInScreen(authService: authService);
              }

              return AuthenticatedShell(
                updateService: widget.updateService,
                authService: authService,
                eventRepositoryFactory:
                    widget.eventRepositoryFactory ?? createEventRepository,
              );
            },
          );
        },
      ),
    );
  }
}

class AuthenticatedShell extends StatefulWidget {
  const AuthenticatedShell({
    super.key,
    required this.updateService,
    required this.authService,
    required this.eventRepositoryFactory,
  });

  final AppUpdateService? updateService;
  final AppAuthService authService;
  final Future<EventRepository> Function() eventRepositoryFactory;

  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  late final Future<EventRepository> _eventRepositoryFuture;
  EventRepository? _resolvedRepository;

  @override
  void initState() {
    super.initState();
    _eventRepositoryFuture = widget.eventRepositoryFactory();
    unawaited(_eventRepositoryFuture.then((repository) {
      if (mounted) {
        _resolvedRepository = repository;
      }
    }));
  }

  @override
  void dispose() {
    unawaited(_resolvedRepository?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EventRepository>(
      future: _eventRepositoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final repository = snapshot.data;
        if (repository == null) {
          return const Scaffold(
            body: Center(child: Text('Could not load event storage.')),
          );
        }

        return CalendarScreen(
          updateService: widget.updateService,
          authService: widget.authService,
          eventRepository: repository,
        );
      },
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.authService});

  final AppAuthService authService;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isSignUpMode = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final displayName = _displayNameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password are required.')),
      );
      return;
    }

    if (_isSignUpMode && password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isSignUpMode) {
        await widget.authService.signUp(
          email: email,
          password: password,
          displayName: displayName.isEmpty ? null : displayName,
        );

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created. You may need to confirm your email before signing in.'),
          ),
        );
      } else {
        await widget.authService.signIn(email: email, password: password);
      }
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication failed.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isSignUpMode ? 'Create an account' : 'Login',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use your Supabase account to access and publish barangay events.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_isSignUpMode) ...[
                        TextField(
                          controller: _displayNameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            prefixIcon: FaIcon(FontAwesomeIcons.user),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: FaIcon(FontAwesomeIcons.envelope),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: FaIcon(FontAwesomeIcons.lock),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: Text(
                          _isSubmitting
                              ? 'Please wait...'
                              : (_isSignUpMode ? 'Create account' : 'Login'),
                        ),
                      ),
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _isSignUpMode = !_isSignUpMode;
                                });
                              },
                        child: Text(
                          _isSignUpMode
                              ? 'Already have an account? Login'
                              : 'Need an account? Create one',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.updateService,
    this.authService,
    required this.eventRepository,
  });

  final AppUpdateService? updateService;
  final AppAuthService? authService;
  final EventRepository eventRepository;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  AppUpdateInfo? _availableUpdate;
  bool _checkingForUpdate = false;

  List<BarangayEvent> _events = const [];
  late final StreamSubscription<List<BarangayEvent>> _eventSubscription;

  List<BarangayEvent> _getEventsForDay(DateTime day) {
    // Normalize the day to ignore time component
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    final events = _events
        .where((event) => isSameDay(event.dayKey, normalizedDay))
        .toList();
    events.sort((a, b) {
      final aStart = a.startTime;
      final bStart = b.startTime;
      return aStart.compareTo(bStart);
    });
    return events;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_checkForUpdates(showDialogWhenAvailable: true));
    _eventSubscription = widget.eventRepository.watchAllEvents().listen((events) {
      if (!mounted) return;
      setState(() => _events = events);
    });
  }

  @override
  void dispose() {
    unawaited(_eventSubscription.cancel());
    super.dispose();
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
        actions: [
          if (widget.authService != null)
            IconButton(
              tooltip: 'Profile',
              onPressed: _showProfileSheet,
              icon: const FaIcon(FontAwesomeIcons.circleUser),
            ),
          if (widget.authService != null)
            IconButton(
              tooltip: 'Sign out',
              onPressed: () => unawaited(widget.authService!.signOut()),
              icon: const FaIcon(FontAwesomeIcons.arrowRightFromBracket),
            ),
        ],
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
        child: const FaIcon(FontAwesomeIcons.plus),
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
              FaIcon(
                FontAwesomeIcons.circleInfo,
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
                icon: const FaIcon(FontAwesomeIcons.xmark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<CalendarFormat>(
            segments: const [
              ButtonSegment<CalendarFormat>(
                value: CalendarFormat.month,
                icon: FaIcon(FontAwesomeIcons.calendarDays),
                label: Text('Monthly'),
              ),
              ButtonSegment<CalendarFormat>(
                value: CalendarFormat.week,
                icon: FaIcon(FontAwesomeIcons.calendarWeek),
                label: Text('Weekly'),
              ),
            ],
            selected: {_calendarFormat},
            onSelectionChanged: (selection) {
              setState(() {
                _calendarFormat = selection.first;
              });
            },
          ),
        ),
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          availableCalendarFormats: const {
            CalendarFormat.month: 'Monthly',
            CalendarFormat.week: 'Weekly',
          },
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
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
        ),
      ],
    );
  }

  Future<void> _showProfileSheet() async {
    final authService = widget.authService;
    if (authService == null) {
      return;
    }

    final profile = authService.currentUser;
    final displayNameController = TextEditingController(
      text: profile?.displayName ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentProfile = authService.currentUser;
            final displayName = currentProfile?.displayName?.trim().isNotEmpty == true
                ? currentProfile!.displayName!
                : 'Barangay Member';
            final email = currentProfile?.email ?? 'No email available';

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  top: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: currentProfile?.avatarUrl != null
                            ? null
                            : Text(
                                currentProfile?.initials ?? 'B',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        prefixIcon: FaIcon(FontAwesomeIcons.userPen),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () async {
                        final nextName = displayNameController.text.trim();
                        if (nextName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Display name cannot be empty.')),
                          );
                          return;
                        }

                        await authService.updateDisplayName(nextName);
                        if (!mounted) {
                          return;
                        }

                        setState(() {});
                        Navigator.pop(context);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('Profile updated.')),
                        );
                      },
                      icon: const FaIcon(FontAwesomeIcons.floppyDisk),
                      label: const Text('Save profile'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await authService.signOut();
                      },
                      icon: const FaIcon(FontAwesomeIcons.arrowRightFromBracket),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    displayNameController.dispose();
  }

  Future<void> _showEventDetails(BarangayEvent event) async {
    final startTime = event.startTime;
    final endTime = event.endTime;
    final formattedDate = _formatDate(startTime);
    final startTimeStr = _formatTime(startTime);
    final endTimeStr = _formatTime(endTime);

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // Header with close button
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: Theme.of(context).colorScheme.surface,
                title: Text(
                  'Event Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                centerTitle: true,
                leading: IconButton(
                  icon: const FaIcon(FontAwesomeIcons.xmark),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              // Event details content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event title with icon
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                            child: FaIcon(
                              _getEventIcon(event.title),
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formattedDate,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Time section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.clock,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Time',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$startTimeStr - $endTimeStr',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Location section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .secondaryContainer
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.locationDot,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Location',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    event.location,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description section (if not empty)
                      if (event.description.isNotEmpty) ...[
                        Text(
                          'Description',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                            ),
                          ),
                          child: Text(
                            event.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Attachment section (if available)
                      if (event.hasAttachment) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .tertiaryContainer
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .tertiary
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              FaIcon(
                                _getFileIcon(
                                    event.attachmentType ??
                                        'application/octet-stream'),
                                color: Theme.of(context).colorScheme.tertiary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Attachment',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getFileTypeName(
                                          event.attachmentType ??
                                              'application/octet-stream'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: () {
                                  // TODO: Implement attachment download
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Download attachment coming soon')),
                                  );
                                },
                                icon: const FaIcon(
                                  FontAwesomeIcons.download,
                                  size: 16,
                                ),
                                label: const Text('View'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Attendance status section
                      Text(
                        'Your Status',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await _handleEventAction('going', event);
                                if (context.mounted) Navigator.pop(context);
                              },
                              icon: const FaIcon(
                                FontAwesomeIcons.check,
                                size: 16,
                              ),
                              label: const Text('Going'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    event.attendanceStatus == 'going'
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                        : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await _handleEventAction('maybe', event);
                                if (context.mounted) Navigator.pop(context);
                              },
                              icon: const FaIcon(
                                FontAwesomeIcons.question,
                                size: 16,
                              ),
                              label: const Text('Maybe'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    event.attendanceStatus == 'maybe'
                                        ? Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer
                                        : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await _handleEventAction('not_going', event);
                                if (context.mounted) Navigator.pop(context);
                              },
                              icon: const FaIcon(
                                FontAwesomeIcons.xmark,
                                size: 16,
                              ),
                              label: const Text('Not Going'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    event.attendanceStatus == 'not_going'
                                        ? Theme.of(context)
                                            .colorScheme
                                            .errorContainer
                                        : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFileTypeName(String mimeType) {
    if (mimeType.contains('pdf')) return 'PDF Document';
    if (mimeType.contains('image')) return 'Image';
    if (mimeType.contains('video')) return 'Video';
    if (mimeType.contains('word') || mimeType.contains('document')) {
      return 'Word Document';
    }
    if (mimeType.contains('sheet') || mimeType.contains('spreadsheet')) {
      return 'Spreadsheet';
    }
    return 'Attachment';
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

  Widget _buildEventCard(BarangayEvent event) {
    final startTime = event.startTime;
    final endTime = event.endTime;

    return GestureDetector(
      onTap: () => _showEventDetails(event),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            child: FaIcon(
              _getEventIcon(event.title),
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(
            event.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FaIcon(
                    FontAwesomeIcons.locationDot,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FaIcon(
                    FontAwesomeIcons.clock,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${_formatTime(startTime)} - ${_formatTime(endTime)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (event.description.isNotEmpty)
                Text(
                  event.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (event.hasAttachment)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      FaIcon(
                        _getFileIcon(event.attachmentType ?? 'application/octet-stream'),
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
            onSelected: (value) => unawaited(_handleEventAction(value, event)),
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
          icon: const FaIcon(FontAwesomeIcons.ellipsisVertical),
        ),
      ),
    ),
    );
  }

  FaIconData _getEventIcon(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('meeting') || lowerTitle.contains('assembly')) {
      return FontAwesomeIcons.users;
    }
    if (lowerTitle.contains('basketball') ||
        lowerTitle.contains('sport') ||
        lowerTitle.contains('tournament')) {
      return FontAwesomeIcons.basketball;
    }
    if (lowerTitle.contains('health') ||
        lowerTitle.contains('checkup') ||
        lowerTitle.contains('medical')) {
      return FontAwesomeIcons.heartPulse;
    }
    if (lowerTitle.contains('fiesta') ||
        lowerTitle.contains('parade') ||
        lowerTitle.contains('festival')) {
      return FontAwesomeIcons.flag;
    }
    if (lowerTitle.contains('health')) {
      return FontAwesomeIcons.heartPulse;
    }
    return FontAwesomeIcons.calendarDays;
  }

  FaIconData _getFileIcon(String mimeType) {
    if (mimeType.contains('image')) return FontAwesomeIcons.image;
    if (mimeType.contains('pdf')) return FontAwesomeIcons.filePdf;
    if (mimeType.contains('video')) return FontAwesomeIcons.video;
    if (mimeType.contains('audio')) return FontAwesomeIcons.fileAudio;
    return FontAwesomeIcons.fileLines;
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEEE, MMM d, yyyy').format(date);
  }

  Future<void> _handleEventAction(String action, BarangayEvent event) async {
    await widget.eventRepository.updateAttendanceStatus(event.id, action);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('You selected: ${action.toUpperCase()} for "${event.title}"'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showAddEventDialog(BuildContext context) {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = _selectedDay ?? _focusedDay;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);

    Future<void> pickDate(StateSetter setDialogState) async {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime.utc(2020, 1, 1),
        lastDate: DateTime.utc(2030, 12, 31),
      );

      if (pickedDate != null) {
        setDialogState(() {
          selectedDate = pickedDate;
        });
      }
    }

    Future<void> pickStartTime(StateSetter setDialogState) async {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: startTime,
      );

      if (pickedTime != null) {
        setDialogState(() {
          startTime = pickedTime;
          if (_timeToMinutes(endTime) <= _timeToMinutes(startTime)) {
            endTime = TimeOfDay(
              hour: (startTime.hour + 1) % 24,
              minute: startTime.minute,
            );
          }
        });
      }
    }

    Future<void> pickEndTime(StateSetter setDialogState) async {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: endTime,
      );

      if (pickedTime != null) {
        setDialogState(() {
          endTime = pickedTime;
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add New Event'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Event title',
                        hintText: 'e.g. Barangay Assembly',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        hintText: 'e.g. Barangay Hall',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Add a short note for residents',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const FaIcon(FontAwesomeIcons.calendarDays),
                      title: const Text('Date'),
                      subtitle: Text(
                        DateFormat('EEEE, MMM d, yyyy').format(selectedDate),
                      ),
                      trailing: TextButton(
                        onPressed: () => pickDate(setDialogState),
                        child: const Text('Change'),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const FaIcon(FontAwesomeIcons.clock),
                      title: const Text('Start time'),
                      subtitle: Text(startTime.format(context)),
                      trailing: TextButton(
                        onPressed: () => pickStartTime(setDialogState),
                        child: const Text('Change'),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const FaIcon(FontAwesomeIcons.hourglassStart),
                      title: const Text('End time'),
                      subtitle: Text(endTime.format(context)),
                      trailing: TextButton(
                        onPressed: () => pickEndTime(setDialogState),
                        child: const Text('Change'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final title = titleController.text.trim();
                  final location = locationController.text.trim();
                  final description = descriptionController.text.trim();

                  if (title.isEmpty || location.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Title and location are required.'),
                      ),
                    );
                    return;
                  }

                  if (_timeToMinutes(endTime) <= _timeToMinutes(startTime)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('End time must be after start time.'),
                      ),
                    );
                    return;
                  }

                  final normalizedDate = DateTime.utc(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                  );
                  final startDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    startTime.hour,
                    startTime.minute,
                  );
                  final endDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    endTime.hour,
                    endTime.minute,
                  );

                  unawaited(() async {
                    await widget.eventRepository.addEvent(
                      BarangayEvent(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        title: title,
                        location: location,
                        startTime: startDateTime,
                        endTime: endDateTime,
                        description: description,
                        hasAttachment: false,
                        createdAt: DateTime.now(),
                      ),
                    );

                    if (!mounted) {
                      return;
                    }

                    setState(() {
                      _selectedDay = normalizedDate;
                      _focusedDay = normalizedDate;
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added "$title" to the calendar.'),
                      ),
                    );
                  }());
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;
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

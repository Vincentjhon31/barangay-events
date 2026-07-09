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
import 'liquid_glass_components.dart';
import 'profile_pages.dart';
import 'theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://xuxnoydakqembrytdbyz.supabase.co',
    anonKey: 'sb_publishable_XnqlZ-m2efmbasNuZ7fyVg_74qTnghA',
  );
  final themeController = await ThemeController.load();

  runApp(
    BarangayCalendarApp(
      themeController: themeController,
      updateService: GitHubReleaseUpdateService(
        repositoryOwner: 'Vincentjhon31',
        repositoryName: 'barangay-events',
      ),
    ),
  );
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2B7FFF),
      brightness: brightness,
    ),
    scaffoldBackgroundColor: isDark ? const Color(0xFF05070C) : const Color(0xFFF8FCFF),
    useMaterial3: true,
  );
}

class BarangayCalendarApp extends StatefulWidget {
  BarangayCalendarApp({
    super.key,
    this.updateService,
    this.authServiceFactory,
    this.eventRepositoryFactory,
    ThemeController? themeController,
  }) : themeController = themeController ?? ThemeController();

  final AppUpdateService? updateService;
  final Future<AppAuthService> Function()? authServiceFactory;
  final Future<EventRepository> Function()? eventRepositoryFactory;
  final ThemeController themeController;

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
    return ListenableBuilder(
      listenable: widget.themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Barangay Calendar',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: widget.themeController.themeMode,
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
                    themeController: widget.themeController,
                    eventRepositoryFactory:
                        widget.eventRepositoryFactory ?? createEventRepository,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class AuthenticatedShell extends StatefulWidget {
  const AuthenticatedShell({
    super.key,
    required this.updateService,
    required this.authService,
    required this.themeController,
    required this.eventRepositoryFactory,
  });

  final AppUpdateService? updateService;
  final AppAuthService authService;
  final ThemeController themeController;
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
          themeController: widget.themeController,
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
  final _departmentController = TextEditingController();
  bool _isSignUpMode = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final displayName = _displayNameController.text.trim();
    final department = _departmentController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password are required.')),
      );
      return;
    }

    if (_isSignUpMode && (displayName.isEmpty || department.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and department are required.')),
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
          department: department.isEmpty ? null : department,
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

  Widget _buildGlassField({
    required TextEditingController controller,
    required String label,
    required FaIconData icon,
    String? hint,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.onSurface.withValues(alpha: 0.14);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: FaIcon(icon, size: 16),
        filled: true,
        fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const Positioned.fill(child: LiquidGlassBackdrop()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: IconBadge(
                          icon: FontAwesomeIcons.landmark,
                          tint: colorScheme.primary,
                          size: 72,
                          iconSize: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Barangay Calendar',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Community events, at a glance.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 28),
                      GlassPanel(
                        borderRadius: 30,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isSignUpMode ? 'Create an account' : 'Login',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Use your account to access and publish barangay events.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 22),
                            if (_isSignUpMode) ...[
                              _buildGlassField(
                                controller: _displayNameController,
                                label: 'Name',
                                icon: FontAwesomeIcons.user,
                              ),
                              const SizedBox(height: 14),
                              _buildGlassField(
                                controller: _departmentController,
                                label: 'Department / Office',
                                hint: "e.g. Mayor's Office, HRMO",
                                icon: FontAwesomeIcons.buildingUser,
                              ),
                              const SizedBox(height: 14),
                            ],
                            _buildGlassField(
                              controller: _emailController,
                              label: 'Email',
                              icon: FontAwesomeIcons.envelope,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 14),
                            _buildGlassField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: FontAwesomeIcons.lock,
                              obscureText: true,
                            ),
                            const SizedBox(height: 22),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              onPressed: _isSubmitting ? null : _submit,
                              child: Text(
                                _isSubmitting
                                    ? 'Please wait...'
                                    : (_isSignUpMode ? 'Create account' : 'Login'),
                                style: const TextStyle(fontWeight: FontWeight.w700),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How the Calendar tab presents events: a month grid, a week strip, or a
/// month-by-month agenda list.
enum _CalendarViewMode { month, week, list }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.updateService,
    this.authService,
    required this.themeController,
    required this.eventRepository,
  });

  final AppUpdateService? updateService;
  final AppAuthService? authService;
  final ThemeController themeController;
  final EventRepository eventRepository;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  _CalendarViewMode _viewMode = _CalendarViewMode.month;
  DateTime _listMonth = DateTime(DateTime.now().year, DateTime.now().month);
  AppUpdateInfo? _availableUpdate;
  bool _checkingForUpdate = false;
  int _selectedTab = 0;
  AppUserProfile? _userProfile;
  final Set<String> _typeFilters = {}; // empty = show all event types

  List<BarangayEvent> _events = const [];
  late StreamSubscription<List<BarangayEvent>> _eventSubscription;

  CalendarFormat get _calendarFormat =>
      _viewMode == _CalendarViewMode.week ? CalendarFormat.week : CalendarFormat.month;

  bool _passesTypeFilter(BarangayEvent event) =>
      _typeFilters.isEmpty || _typeFilters.contains(event.eventType);

  List<BarangayEvent> _getEventsForDay(DateTime day) {
    // Normalize the day to ignore time component
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    final events = _events
        .where((event) => isSameDay(event.dayKey, normalizedDay))
        .where(_passesTypeFilter)
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
    unawaited(_loadUserProfile());
    _eventSubscription = _listenToEvents();
  }

  StreamSubscription<List<BarangayEvent>> _listenToEvents() {
    return widget.eventRepository.watchAllEvents().listen((events) {
      if (!mounted) return;
      setState(() => _events = events);
    });
  }

  /// Re-opens the event stream, e.g. after joining a shared calendar makes
  /// more events visible to this user.
  void _resubscribeEvents() {
    unawaited(_eventSubscription.cancel());
    _eventSubscription = _listenToEvents();
  }

  Future<void> _loadUserProfile() async {
    final authService = widget.authService;
    if (authService == null) return;

    AppUserProfile? profile;
    if (authService is SupabaseAuthService) {
      profile = await authService.fetchUserProfile();
    } else {
      profile = authService.currentUser;
    }

    if (!mounted) return;
    setState(() => _userProfile = profile);
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

  BarangayEvent? get _nextUpcomingEvent {
    final now = DateTime.now();
    final upcoming = _events.where((event) => event.endTime.isAfter(now)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  void _handleTabSelected(int index) {
    if (index == _selectedTab) return;
    setState(() => _selectedTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const Positioned.fill(child: LiquidGlassBackdrop()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (_availableUpdate != null) _buildUpdateBanner(_availableUpdate!),
                Expanded(
                  child: IndexedStack(
                    index: _selectedTab,
                    children: [
                      _buildCalendarTab(),
                      _buildAnnouncementsTab(),
                      if (widget.authService != null)
                        ProfileTab(
                          authService: widget.authService!,
                          themeController: widget.themeController,
                          onProfileSaved: () => unawaited(_loadUserProfile()),
                          onCalendarJoined: _resubscribeEvents,
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: LiquidTabBar(
                items: const [
                  (icon: FontAwesomeIcons.calendarDays, label: 'Calendar'),
                  (icon: FontAwesomeIcons.bullhorn, label: 'Announce'),
                  (icon: FontAwesomeIcons.user, label: 'Profile'),
                ],
                selectedIndex: _selectedTab,
                onSelect: _handleTabSelected,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 96),
              child: FloatingActionButton(
                onPressed: () => _showAddEventDialog(context),
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const FaIcon(FontAwesomeIcons.plus),
              ),
            )
          : null,
    );
  }

  Widget _buildCalendarTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
      children: [
        _buildHeader(),
        const SizedBox(height: 18),
        _buildAnnouncementBanner(),
        const SizedBox(height: 18),
        Center(child: _buildViewToggle()),
        const SizedBox(height: 14),
        _buildTypeFilterChips(),
        const SizedBox(height: 14),
        if (_viewMode == _CalendarViewMode.list) ...[
          _buildMonthNav(),
          const SizedBox(height: 14),
          ..._buildMonthListSections(),
        ] else ...[
          _buildCalendar(),
          const SizedBox(height: 22),
          _buildUpcomingHeader(),
          const SizedBox(height: 12),
          ..._buildUpcomingEventCards(),
        ],
      ],
    );
  }

  Widget _buildViewToggle() {
    final colorScheme = Theme.of(context).colorScheme;
    return SegmentedButton<_CalendarViewMode>(
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        backgroundColor: colorScheme.onSurface.withValues(alpha: 0.06),
        foregroundColor: colorScheme.onSurfaceVariant,
        selectedForegroundColor: colorScheme.onPrimary,
        selectedBackgroundColor: colorScheme.primary.withValues(alpha: 0.4),
        side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.12)),
      ),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment<_CalendarViewMode>(
          value: _CalendarViewMode.month,
          label: Text('Month'),
        ),
        ButtonSegment<_CalendarViewMode>(
          value: _CalendarViewMode.week,
          label: Text('Week'),
        ),
        ButtonSegment<_CalendarViewMode>(
          value: _CalendarViewMode.list,
          label: Text('List'),
        ),
      ],
      selected: {_viewMode},
      onSelectionChanged: (selection) {
        setState(() {
          _viewMode = selection.first;
        });
      },
    );
  }

  Widget _buildMonthNav() {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassPanel(
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('list-prev-month'),
            tooltip: 'Previous month',
            onPressed: () => setState(() {
              _listMonth = DateTime(_listMonth.year, _listMonth.month - 1);
            }),
            icon: FaIcon(
              FontAwesomeIcons.chevronLeft,
              size: 15,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(_listMonth),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          IconButton(
            key: const Key('list-next-month'),
            tooltip: 'Next month',
            onPressed: () => setState(() {
              _listMonth = DateTime(_listMonth.year, _listMonth.month + 1);
            }),
            icon: FaIcon(
              FontAwesomeIcons.chevronRight,
              size: 15,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMonthListSections() {
    final monthEvents = _events
        .where((event) =>
            event.startTime.year == _listMonth.year &&
            event.startTime.month == _listMonth.month)
        .where(_passesTypeFilter)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (monthEvents.isEmpty) {
      return [
        GlassPanel(
          child: Text(
            'No events in ${DateFormat('MMMM yyyy').format(_listMonth)}.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    DateTime? currentDay;
    for (final event in monthEvents) {
      final day = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );
      if (currentDay == null || !day.isAtSameMomentAs(currentDay)) {
        currentDay = day;
        widgets.add(Padding(
          padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 10, bottom: 8),
          child: Text(
            DateFormat('EEEE, MMM d').format(day),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ));
      }
      widgets.add(_buildEventCard(event));
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  Widget _buildTypeFilterChips() {
    final options = <({String? value, String label, FaIconData icon})>[
      (value: null, label: 'All', icon: FontAwesomeIcons.layerGroup),
      (value: EventType.public, label: 'Public', icon: FontAwesomeIcons.globe),
      (value: EventType.shared, label: 'Shared', icon: FontAwesomeIcons.userGroup),
      (value: EventType.personal, label: 'Personal', icon: FontAwesomeIcons.lock),
    ];
    final colorScheme = Theme.of(context).colorScheme;

    // "All" is active when no specific type is checked; the type chips are
    // checkable so several can be enabled at once.
    bool isActive(String? value) =>
        value == null ? _typeFilters.isEmpty : _typeFilters.contains(value);

    void toggle(String? value) {
      setState(() {
        if (value == null) {
          _typeFilters.clear();
        } else if (_typeFilters.contains(value)) {
          _typeFilters.remove(value);
        } else {
          _typeFilters.add(value);
        }
      });
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options) ...[
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => toggle(option.value),
              child: GlassPanel(
                borderRadius: 999,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                tint: isActive(option.value) ? colorScheme.primary : null,
                tintAlpha: isActive(option.value) ? 0.22 : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      option.icon,
                      size: 12,
                      color: isActive(option.value)
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      option.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isActive(option.value)
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (option.value != null && isActive(option.value)) ...[
                      const SizedBox(width: 6),
                      FaIcon(
                        FontAwesomeIcons.circleCheck,
                        size: 12,
                        color: colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildPageHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final profile = _userProfile ?? widget.authService?.currentUser;
    final barangayName = profile?.barangay?.trim().isNotEmpty == true
        ? profile!.barangay!.toUpperCase()
        : 'BARANGAY';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                barangayName,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'Community Calendar',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
        if (widget.authService != null)
          InkWell(
            onTap: () => _handleTabSelected(2),
            borderRadius: BorderRadius.circular(24),
            child: IconBadge(
              icon: FontAwesomeIcons.circleUser,
              tint: Theme.of(context).colorScheme.primary,
              size: 48,
              iconSize: 20,
            ),
          ),
      ],
    );
  }

  Widget _buildAnnouncementBanner() {
    final event = _nextUpcomingEvent;
    if (event == null) {
      return GlassPanel(
        child: Row(
          children: [
            IconBadge(icon: FontAwesomeIcons.calendarCheck, tint: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'No upcoming events right now. Check back soon!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () => _showEventDetails(event),
      child: GlassPanel(
        tint: _getEventTint(event.title),
        tintAlpha: 0.16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: _getEventIcon(event.title), tint: _getEventTint(event.title)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next up',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${event.location} • ${_formatDate(event.startTime)}, ${_formatTime(event.startTime)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            FaIcon(
              FontAwesomeIcons.chevronRight,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingHeader() {
    final selected = _selectedDay;
    final isToday = selected == null || isSameDay(selected, DateTime.now());
    return Row(
      children: [
        Text(
          isToday ? 'Upcoming' : 'Events for ${_formatDate(selected)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  List<Widget> _buildUpcomingEventCards() {
    final events = _getEventsForDay(_selectedDay ?? _focusedDay);

    if (events.isEmpty) {
      return [
        GlassPanel(
          child: Text(
            'No events for ${_formatDate(_selectedDay ?? _focusedDay)}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ];
    }

    return [
      for (final event in events) ...[
        _buildEventCard(event),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _buildAnnouncementsTab() {
    final upcoming = _events.where((event) => event.endTime.isAfter(DateTime.now())).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
      children: [
        _buildPageHeader('Announcements', 'Upcoming events and community notices.'),
        const SizedBox(height: 18),
        if (upcoming.isEmpty)
          GlassPanel(
            child: Text(
              'No upcoming announcements.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final event in upcoming) ...[
            _buildEventCard(event),
            const SizedBox(height: 12),
          ],
      ],
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
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Column(
        children: [
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
                _viewMode = format == CalendarFormat.week
                    ? _CalendarViewMode.week
                    : _CalendarViewMode.month;
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
                  bottom: 3,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
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
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    day.day.toString(),
                    style: TextStyle(
                      color: colorScheme.onPrimary,
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
                    color: colorScheme.primary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.primary, width: 1.6),
                  ),
                  child: Text(
                    day.day.toString(),
                    style: TextStyle(
                      color: colorScheme.onSurface,
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
              leftChevronIcon: FaIcon(FontAwesomeIcons.chevronLeft, size: 15, color: colorScheme.onSurfaceVariant),
              rightChevronIcon: FaIcon(FontAwesomeIcons.chevronRight, size: 15, color: colorScheme.onSurfaceVariant),
              titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: colorScheme.onSurface),
              decoration: const BoxDecoration(),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              weekendStyle: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: TextStyle(color: colorScheme.onSurface),
              weekendTextStyle: TextStyle(color: colorScheme.onSurface),
              todayDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
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

                      // Posted by section (if creator info is available)
                      if (event.creatorLabel != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .tertiaryContainer
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              FaIcon(
                                FontAwesomeIcons.userPen,
                                color: Theme.of(context).colorScheme.tertiary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Posted by',
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
                                      event.creatorLabel!,
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
                      ],

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

                      // Delete (only for the event's creator)
                      if (_canDeleteEvent(event)) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .error
                                    .withValues(alpha: 0.6),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              unawaited(_confirmDeleteEvent(event));
                            },
                            icon: const FaIcon(FontAwesomeIcons.trashCan, size: 16),
                            label: const Text('Delete event'),
                          ),
                        ),
                      ],
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

  Widget _buildEventCard(BarangayEvent event) {
    final startTime = event.startTime;
    final endTime = event.endTime;
    final tint = _getEventTint(event.title);

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () => _showEventDetails(event),
      child: GlassPanel(
        borderRadius: 26,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: _getEventIcon(event.title), tint: tint),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildEventTypePill(event.eventType),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.locationDot,
                        size: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          event.location,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.clock,
                        size: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${_formatDate(startTime)} • ${_formatTime(startTime)} - ${_formatTime(endTime)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                  if (event.creatorLabel != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.userPen,
                          size: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'By ${event.creatorLabel}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.description,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (event.hasAttachment) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        FaIcon(
                          _getFileIcon(event.attachmentType ?? 'application/octet-stream'),
                          size: 14,
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
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  unawaited(_confirmDeleteEvent(event));
                } else {
                  unawaited(_handleEventAction(value, event));
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'going', child: Text('Going')),
                const PopupMenuItem(value: 'maybe', child: Text('Maybe')),
                const PopupMenuItem(value: 'not_going', child: Text('Not Going')),
                if (_canDeleteEvent(event))
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete event',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
              icon: FaIcon(
                FontAwesomeIcons.ellipsisVertical,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  FaIconData _eventTypeIcon(String type) {
    switch (type) {
      case EventType.shared:
        return FontAwesomeIcons.userGroup;
      case EventType.personal:
        return FontAwesomeIcons.lock;
      default:
        return FontAwesomeIcons.globe;
    }
  }

  String _eventTypeLabel(String type) {
    switch (type) {
      case EventType.shared:
        return 'Shared';
      case EventType.personal:
        return 'Personal';
      default:
        return 'Public';
    }
  }

  Color _eventTypeTint(String type) {
    switch (type) {
      case EventType.shared:
        return const Color(0xFF1F9D65);
      case EventType.personal:
        return Theme.of(context).colorScheme.onSurfaceVariant;
      default:
        return const Color(0xFF2B7FFF);
    }
  }

  Widget _buildEventTypePill(String type) {
    final tint = _eventTypeTint(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(_eventTypeIcon(type), size: 9, color: tint),
          const SizedBox(width: 4),
          Text(
            _eventTypeLabel(type),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }

  String? get _currentUserId => (_userProfile ?? widget.authService?.currentUser)?.id;

  bool _canDeleteEvent(BarangayEvent event) {
    final userId = _currentUserId;
    return userId != null && event.createdById == userId;
  }

  Future<void> _confirmDeleteEvent(BarangayEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event'),
        content: Text('Delete "${event.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await widget.eventRepository.deleteEvent(event.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted "${event.title}".')),
    );
  }

  FaIconData _getEventIcon(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('meeting') || lowerTitle.contains('assembly')) {
      return FontAwesomeIcons.peopleGroup;
    }
    if (lowerTitle.contains('basketball') ||
        lowerTitle.contains('sport') ||
        lowerTitle.contains('tournament')) {
      return FontAwesomeIcons.basketball;
    }
    if (lowerTitle.contains('vaccin') ||
        lowerTitle.contains('health') ||
        lowerTitle.contains('checkup') ||
        lowerTitle.contains('medical')) {
      return FontAwesomeIcons.syringe;
    }
    if (lowerTitle.contains('garbage') ||
        lowerTitle.contains('waste') ||
        lowerTitle.contains('collection') ||
        lowerTitle.contains('cleanup') ||
        lowerTitle.contains('clean-up')) {
      return FontAwesomeIcons.truckFast;
    }
    if (lowerTitle.contains('fiesta') ||
        lowerTitle.contains('parade') ||
        lowerTitle.contains('festival')) {
      return FontAwesomeIcons.fireFlameCurved;
    }
    return FontAwesomeIcons.calendarDays;
  }

  Color _getEventTint(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('meeting') || lowerTitle.contains('assembly')) {
      return const Color(0xFF7C4DFF);
    }
    if (lowerTitle.contains('basketball') ||
        lowerTitle.contains('sport') ||
        lowerTitle.contains('tournament')) {
      return const Color(0xFFFF7043);
    }
    if (lowerTitle.contains('vaccin') ||
        lowerTitle.contains('health') ||
        lowerTitle.contains('checkup') ||
        lowerTitle.contains('medical')) {
      return const Color(0xFF2B7FFF);
    }
    if (lowerTitle.contains('garbage') ||
        lowerTitle.contains('waste') ||
        lowerTitle.contains('collection') ||
        lowerTitle.contains('cleanup') ||
        lowerTitle.contains('clean-up')) {
      return const Color(0xFF1F9D65);
    }
    if (lowerTitle.contains('fiesta') ||
        lowerTitle.contains('parade') ||
        lowerTitle.contains('festival')) {
      return const Color(0xFFFFA726);
    }
    return const Color(0xFF2B7FFF);
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
    if (!mounted) return;
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
    String eventType = EventType.public;

    String typeHelperText() {
      switch (eventType) {
        case EventType.shared:
          return 'Only people who joined your calendar can see this.';
        case EventType.personal:
          return 'Only you can see this.';
        default:
          return 'Everyone in the app can see this.';
      }
    }

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
                    SegmentedButton<String>(
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment<String>(
                          value: EventType.public,
                          label: Text('Public'),
                          icon: FaIcon(FontAwesomeIcons.globe, size: 12),
                        ),
                        ButtonSegment<String>(
                          value: EventType.shared,
                          label: Text('Shared'),
                          icon: FaIcon(FontAwesomeIcons.userGroup, size: 12),
                        ),
                        ButtonSegment<String>(
                          value: EventType.personal,
                          label: Text('Personal'),
                          icon: FaIcon(FontAwesomeIcons.lock, size: 12),
                        ),
                      ],
                      selected: {eventType},
                      onSelectionChanged: (selection) {
                        setDialogState(() {
                          eventType = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      typeHelperText(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
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

                  final creator = _userProfile ?? widget.authService?.currentUser;

                  unawaited(() async {
                    try {
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
                          createdByName: creator?.displayName,
                          createdByDepartment: creator?.department,
                          createdById: creator?.id,
                          eventType: eventType,
                        ),
                      );
                    } catch (error) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('Could not save the event: $error'),
                          duration: const Duration(seconds: 6),
                        ),
                      );
                      return;
                    }

                    if (!mounted) {
                      return;
                    }

                    setState(() {
                      _selectedDay = normalizedDate;
                      _focusedDay = normalizedDate;
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
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

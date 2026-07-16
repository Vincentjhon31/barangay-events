import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_event_page.dart';
import 'app_update_service.dart';
import 'auth_service.dart';
import 'day_detail_page.dart';
import 'event_conflicts.dart';
import 'event_store.dart';
import 'liquid_glass_components.dart';
import 'profile_pages.dart';
import 'push_notifications.dart';
import 'theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://xuxnoydakqembrytdbyz.supabase.co',
    anonKey: 'sb_publishable_XnqlZ-m2efmbasNuZ7fyVg_74qTnghA',
  );

  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (_) {
    // No Firebase config for this platform (only Android has a
    // google-services.json — see README's Push Notifications setup) — the
    // app still works, it just won't be able to send/show pushes. Only
    // Android is targeted for pushes right now: web/Windows/macOS/Linux
    // builds are dev-only conveniences, not something this app ships.
  }

  final themeController = await ThemeController.load();

  runApp(
    BarangayCalendarApp(
      themeController: themeController,
      updateService: GitHubReleaseUpdateService(
        repositoryOwner: 'Vincentjhon31',
        repositoryName: 'barangay-events',
      ),
      pushNotificationServiceFactory: firebaseReady
          ? () async => FirebasePushNotificationService()
          : () async => const NoopPushNotificationService(),
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
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF05070C) : const Color(0xFFF8FCFF),
    useMaterial3: true,
  );
}

class BarangayCalendarApp extends StatefulWidget {
  BarangayCalendarApp({
    super.key,
    this.updateService,
    this.authServiceFactory,
    this.eventRepositoryFactory,
    this.pushNotificationServiceFactory,
    ThemeController? themeController,
  }) : themeController = themeController ?? ThemeController();

  final AppUpdateService? updateService;
  final Future<AppAuthService> Function()? authServiceFactory;
  final Future<EventRepository> Function()? eventRepositoryFactory;

  /// Defaults to [NoopPushNotificationService] — unlike the other
  /// factories above, constructing the *real* Firebase service has side
  /// effects the instant it's used, and `Firebase.initializeApp()` is only
  /// ever called from `main()` (never by widget tests), so a real default
  /// here would crash every existing test. `main()` explicitly opts in.
  final Future<PushNotificationService> Function()?
      pushNotificationServiceFactory;
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
    _authServiceFuture = widget.authServiceFactory?.call() ??
        Future.value(SupabaseAuthService(Supabase.instance.client));
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
          title: 'eBongabong Calendar',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: widget.themeController.themeMode,
          builder: (context, child) => AppStyleScope(
            style: widget.themeController.uiStyle,
            child: child ?? const SizedBox.shrink(),
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
                    themeController: widget.themeController,
                    eventRepositoryFactory:
                        widget.eventRepositoryFactory ?? createEventRepository,
                    pushNotificationServiceFactory:
                        widget.pushNotificationServiceFactory ??
                            () async => const NoopPushNotificationService(),
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
    required this.pushNotificationServiceFactory,
  });

  final AppUpdateService? updateService;
  final AppAuthService authService;
  final ThemeController themeController;
  final Future<EventRepository> Function() eventRepositoryFactory;
  final Future<PushNotificationService> Function()
      pushNotificationServiceFactory;

  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  late final Future<EventRepository> _eventRepositoryFuture;
  late final Future<PushNotificationService> _pushServiceFuture;
  EventRepository? _resolvedRepository;

  @override
  void initState() {
    super.initState();
    _eventRepositoryFuture = widget.eventRepositoryFactory();
    _pushServiceFuture = widget.pushNotificationServiceFactory();
    unawaited(_eventRepositoryFuture.then((repository) {
      if (mounted) {
        _resolvedRepository = repository;
      }
    }));

    widget.themeController.attachAuthService(widget.authService);
    unawaited(widget.authService.fetchPreferences().then((prefs) {
      if (prefs == null || !mounted) return;
      unawaited(widget.themeController.applyRemote(
        themeMode: prefs.themeMode,
        uiStyle: prefs.uiStyle,
      ));
    }));
  }

  @override
  void dispose() {
    widget.themeController.detachAuthService();
    unawaited(_resolvedRepository?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EventRepository>(
      future: _eventRepositoryFuture,
      builder: (context, repositorySnapshot) {
        if (repositorySnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final repository = repositorySnapshot.data;
        if (repository == null) {
          return const Scaffold(
            body: Center(child: Text('Could not load event storage.')),
          );
        }

        return FutureBuilder<PushNotificationService>(
          future: _pushServiceFuture,
          builder: (context, pushSnapshot) {
            final pushService = pushSnapshot.data;
            if (pushSnapshot.connectionState != ConnectionState.done ||
                pushService == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return CalendarScreen(
              updateService: widget.updateService,
              authService: widget.authService,
              themeController: widget.themeController,
              eventRepository: repository,
              pushNotificationService: pushService,
            );
          },
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
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isSignUpMode = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final displayName = _displayNameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password are required.')),
      );
      return;
    }

    if (_isSignUpMode && displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required.')),
      );
      return;
    }

    if (_isSignUpMode && password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 6 characters.')),
      );
      return;
    }

    if (_isSignUpMode && password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
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
            content: Text(
                'Account created. You may need to confirm your email before signing in.'),
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
        prefixIcon: glassFieldIcon(icon),
        prefixIconConstraints: glassFieldIconConstraints,
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/icons/Launcher_app.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'eBongabong Calendar',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Use your account to access and publish barangay events.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
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
                            if (_isSignUpMode) ...[
                              const SizedBox(height: 14),
                              _buildGlassField(
                                controller: _confirmPasswordController,
                                label: 'Confirm password',
                                icon: FontAwesomeIcons.lock,
                                obscureText: true,
                              ),
                            ],
                            const SizedBox(height: 22),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18)),
                              ),
                              onPressed: _isSubmitting ? null : _submit,
                              child: Text(
                                _isSubmitting
                                    ? 'Please wait...'
                                    : (_isSignUpMode
                                        ? 'Create account'
                                        : 'Login'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
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

/// Within List view: browse one month at a time (the original behavior),
/// or a flat "Upcoming" feed sorted by distance from today regardless of
/// month, with an ascending/descending toggle.
enum _ListSubMode { byMonth, upcoming }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.updateService,
    this.authService,
    required this.themeController,
    required this.eventRepository,
    required this.pushNotificationService,
  });

  final AppUpdateService? updateService;
  final AppAuthService? authService;
  final ThemeController themeController;
  final EventRepository eventRepository;
  final PushNotificationService pushNotificationService;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  _CalendarViewMode _viewMode = _CalendarViewMode.month;
  DateTime _listMonth = DateTime(DateTime.now().year, DateTime.now().month);
  _ListSubMode _listSubMode = _ListSubMode.byMonth;
  bool _upcomingAscending = true; // true = soonest first
  AppUpdateInfo? _availableUpdate;
  bool _checkingForUpdate = false;
  int _selectedTab = 0;
  AppUserProfile? _userProfile;
  final Set<String> _typeFilters = {}; // empty = show all event types
  final _calendarSearchController = TextEditingController();
  String _calendarSearchQuery = '';

  // Refreshed alongside push-topic sync (both need listMyGroups()) — used
  // by _canEditEvent to let a promoted group admin edit that group's
  // events, not just the event's own creator.
  final Set<String> _adminGroupIds = {};

  static const String _feedLastSeenKey = 'feed_last_seen';
  int _feedLastSeenMillis = 0; // persisted; drives the tab dot
  int _feedNewThreshold = 0; // snapshot at feed-open; drives the NEW pills

  // Independent from the Calendar tab's own _typeFilters — filtering the
  // feed shouldn't silently change what the calendar grid/list show.
  final Set<String> _feedTypeFilters = {};
  final _feedSearchController = TextEditingController();
  String _feedSearchQuery = '';

  // A long feed is otherwise an endless scroll — paginated in fixed-size
  // chunks rather than infinite-scroll/load-more, so there's a clear
  // "how much is left" sense (Prev/Next, like the List view's month nav).
  static const int _feedPageSize = 15;
  int _feedPage = 0;

  List<BarangayEvent> _events = const [];
  bool _eventsLoaded = false;
  late StreamSubscription<List<BarangayEvent>> _eventSubscription;

  bool get _hasUnseenFeedItems => _events.any(
      (event) => event.createdAt.millisecondsSinceEpoch > _feedLastSeenMillis);

  CalendarFormat get _calendarFormat => _viewMode == _CalendarViewMode.week
      ? CalendarFormat.week
      : CalendarFormat.month;

  bool _passesTypeFilter(BarangayEvent event) =>
      _typeFilters.isEmpty || _typeFilters.contains(event.eventType);

  /// Independent from the Feed tab's own search — matches [_typeFilters]'
  /// existing "don't share filter state across tabs" convention.
  bool _passesCalendarSearch(BarangayEvent event) {
    final query = _calendarSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final haystack = [
      event.title,
      event.location,
      event.description,
      event.creatorLabel ?? '',
      event.groupName ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  List<BarangayEvent> _getEventsForDay(DateTime day) {
    final events = _events
        .where((event) => event.occursOnDay(day))
        .where(_passesTypeFilter)
        .where(_passesCalendarSearch)
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
    unawaited(_loadFeedLastSeen());
    unawaited(_initializePushNotifications());
    _eventSubscription = _listenToEvents();
  }

  Future<void> _initializePushNotifications() async {
    if (widget.authService == null) return;
    try {
      await widget.pushNotificationService.initialize(
        onAppUpdateAvailable: () => unawaited(_checkForUpdates()),
      );
    } catch (_) {
      // Firebase not configured yet, or the user denied the permission —
      // either way the app should keep working without push notifications.
    }
    await _syncPushTopics();
  }

  Future<void> _syncPushTopics() async {
    if (widget.authService == null) return;
    try {
      final groups = await widget.eventRepository.listMyGroups();
      if (mounted) {
        setState(() {
          _adminGroupIds
            ..clear()
            ..addAll(groups.where((group) => group.isAdmin).map((group) => group.id));
        });
      }
      await widget.pushNotificationService.syncTopics(
        groups.map((group) => group.id).toList(),
      );
    } catch (_) {
      // Non-critical — a failed topic sync shouldn't block the calendar.
    }
  }

  Future<void> _loadFeedLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _feedLastSeenMillis = prefs.getInt(_feedLastSeenKey) ?? 0;
      _feedNewThreshold = _feedLastSeenMillis;
    });
  }

  Future<void> _markFeedSeen() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() => _feedLastSeenMillis = now);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_feedLastSeenKey, now);
  }

  StreamSubscription<List<BarangayEvent>> _listenToEvents() {
    return widget.eventRepository.watchAllEvents().listen((events) {
      if (!mounted) return;
      setState(() {
        _events = events;
        _eventsLoaded = true;
      });
    });
  }

  Widget _buildLoadingPanel() {
    return const GlassPanel(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }

  /// Re-opens the event stream, e.g. after joining a shared calendar makes
  /// more events visible to this user.
  void _resubscribeEvents() {
    unawaited(_eventSubscription.cancel());
    _eventSubscription = _listenToEvents();
    unawaited(_syncPushTopics());
  }

  /// Pull-to-refresh for the Calendar and Feed tabs. Events already stream
  /// in live, so there's nothing stale to actually fetch — this
  /// re-subscribes (cheap insurance against a stalled stream) and holds
  /// the indicator up briefly so the gesture still feels like it did
  /// something, matching the Groups tab's own pull-to-refresh.
  Future<void> _refreshEvents() async {
    _resubscribeEvents();
    await Future.delayed(const Duration(milliseconds: 400));
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
    setState(() {
      _userProfile = profile;
      // The Groups tab can disappear out from under the currently-selected
      // index once the real role loads (it defaults to showing Groups
      // until proven otherwise — see _showGroupsTab) — land on Profile
      // instead of silently showing the wrong tab or, worse, an
      // out-of-range IndexedStack index.
      if (!_showGroupsTab && _selectedTab >= 2) {
        _selectedTab = _profileTabIndex;
      }
    });
  }

  @override
  void dispose() {
    unawaited(_eventSubscription.cancel());
    _feedSearchController.dispose();
    _calendarSearchController.dispose();
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

  void _handleTabSelected(int index) {
    if (index == _selectedTab) return;
    setState(() => _selectedTab = index);
    if (index == 1) {
      // Entering the feed: keep NEW pills relative to the previous visit,
      // then persist "seen now" so the tab dot clears.
      _feedNewThreshold = _feedLastSeenMillis;
      unawaited(_markFeedSeen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Offset above the floating LiquidTabBar (bottom:20 + its own
      // height) — Scaffold's normal FAB placement doesn't know about that
      // bar since it's a manually-positioned Stack child, not a real
      // bottomNavigationBar.
      floatingActionButton: _selectedTab == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 90),
              child: FloatingActionButton.extended(
                key: const Key('calendar-add-event-fab'),
                onPressed: () => unawaited(_openAddEvent()),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                icon: FaIcon(FontAwesomeIcons.plus, size: 16, color: colorScheme.onPrimary),
                label: Text('Add event', style: TextStyle(color: colorScheme.onPrimary)),
              ),
            )
          : null,
      body: Stack(
        children: [
          const Positioned.fill(child: LiquidGlassBackdrop()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (_availableUpdate != null)
                  _buildUpdateBanner(_availableUpdate!),
                Expanded(
                  child: IndexedStack(
                    index: _selectedTab,
                    children: [
                      _buildCalendarTab(),
                      _buildFeedTab(),
                      if (_showGroupsTab)
                        GroupsTab(
                          eventRepository: widget.eventRepository,
                          currentUserId: _currentUserId,
                          canCreateGroups: _canCreateGroups,
                          onGroupsChanged: _resubscribeEvents,
                        ),
                      if (widget.authService != null)
                        ProfileTab(
                          authService: widget.authService!,
                          themeController: widget.themeController,
                          onProfileSaved: () => unawaited(_loadUserProfile()),
                          updateService: widget.updateService,
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
                items: [
                  (icon: FontAwesomeIcons.calendarDays, label: 'Calendar'),
                  (icon: FontAwesomeIcons.newspaper, label: 'Feed'),
                  if (_showGroupsTab)
                    (icon: FontAwesomeIcons.peopleGroup, label: 'Groups'),
                  (icon: FontAwesomeIcons.user, label: 'Profile'),
                ],
                selectedIndex: _selectedTab,
                onSelect: _handleTabSelected,
                dotIndices: {
                  if (_hasUnseenFeedItems) 1,
                  if (_availableUpdate != null) _profileTabIndex,
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the full-day view for [date] — its own event list, with its own
  /// Add button too. Also updates [_selectedDay]/[_focusedDay] so the
  /// calendar grid/inline day preview reflect the tapped day when the user
  /// returns.
  Future<void> _openDayDetail(DateTime date) async {
    setState(() {
      _selectedDay = date;
      _focusedDay = date;
    });
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DayDetailPage(
          date: date,
          eventRepository: widget.eventRepository,
          creatorProfile: _userProfile ?? widget.authService?.currentUser,
          buildEventCard: _buildEventCard,
        ),
      ),
    );
  }

  /// Add Event button on the main Calendar page itself — clamps forward to
  /// today if the user had navigated to a past month before tapping it, so
  /// the picker never opens with a past date pre-selected.
  Future<void> _openAddEvent() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var initialDate = _selectedDay ?? _focusedDay;
    if (initialDate.isBefore(today)) {
      initialDate = today;
    }
    setState(() {
      _selectedDay = initialDate;
      _focusedDay = initialDate;
    });

    List<BarangayGroup> myGroups = const [];
    try {
      myGroups = await widget.eventRepository.listMyGroups();
    } catch (_) {
      // Groups unavailable (e.g. migration not run) — Add Event still works
      // for public/personal events.
    }
    if (!mounted) return;

    final result = await Navigator.of(context).push<AddEventResult>(
      MaterialPageRoute(
        builder: (_) => AddEventPage(
          eventRepository: widget.eventRepository,
          myGroups: myGroups,
          initialDate: initialDate,
          creatorProfile: _userProfile ?? widget.authService?.currentUser,
          findOverlappingEvents: (date, start, end) =>
              findOverlappingEvents(_events, date, start, end),
          suggestFreeSlot: (date, start, end) =>
              suggestFreeSlot(_events, date, start, end),
        ),
      ),
    );
    // No manual merge needed for the list itself — the live watchAllEvents()
    // subscription already picks up the newly saved event.
    if (result != null && mounted) {
      setState(() {
        _selectedDay = result.date;
        _focusedDay = result.date;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.groupName != null
                ? 'Added "${result.title}" to ${result.groupName}.'
                : 'Added "${result.title}" to the calendar.',
          ),
        ),
      );
    }
  }

  /// Edit an existing event — creator, or (for a Group event) an admin of
  /// the group it's posted to. Reuses AddEventPage in edit mode, pre-filled.
  Future<void> _openEditEvent(BarangayEvent event) async {
    List<BarangayGroup> myGroups = const [];
    try {
      myGroups = await widget.eventRepository.listMyGroups();
    } catch (_) {
      // Groups unavailable (e.g. migration not run) — editing a
      // Public/Personal event still works.
    }
    if (!mounted) return;

    final result = await Navigator.of(context).push<AddEventResult>(
      MaterialPageRoute(
        builder: (_) => AddEventPage(
          eventRepository: widget.eventRepository,
          myGroups: myGroups,
          initialDate: event.startTime,
          existingEvent: event,
          creatorProfile: _userProfile ?? widget.authService?.currentUser,
          findOverlappingEvents: (date, start, end) =>
              findOverlappingEvents(_events, date, start, end),
          suggestFreeSlot: (date, start, end) =>
              suggestFreeSlot(_events, date, start, end),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedDay = result.date;
        _focusedDay = result.date;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated "${result.title}".')),
      );
    }
  }

  Widget _buildCalendarSearchField() {
    return TextField(
      key: const Key('calendar-search-field'),
      controller: _calendarSearchController,
      onChanged: (value) => setState(() => _calendarSearchQuery = value),
      decoration: InputDecoration(
        labelText: 'Search events',
        hintText: 'Title, location, or who posted it',
        prefixIcon: glassFieldIcon(FontAwesomeIcons.magnifyingGlass, size: 14),
        prefixIconConstraints: glassFieldIconConstraints,
        suffixIcon: _calendarSearchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const FaIcon(FontAwesomeIcons.xmark, size: 14),
                onPressed: () {
                  _calendarSearchController.clear();
                  setState(() => _calendarSearchQuery = '');
                },
              ),
      ),
    );
  }

  Widget _buildCalendarTab() {
    return RefreshIndicator(
      onRefresh: _refreshEvents,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildCalendarSearchField(),
          const SizedBox(height: 14),
          Center(child: _buildViewToggle()),
          const SizedBox(height: 14),
          _buildTypeFilterChips(_typeFilters, keyPrefix: 'calendar'),
          const SizedBox(height: 14),
          if (_viewMode == _CalendarViewMode.list) ...[
            Center(child: _buildListSubModeToggle()),
            const SizedBox(height: 14),
            if (_listSubMode == _ListSubMode.byMonth) ...[
              _buildMonthNav(),
              const SizedBox(height: 14),
              ..._buildMonthListSections(),
            ] else ...[
              _buildUpcomingSortBar(),
              const SizedBox(height: 10),
              ..._buildUpcomingListSections(),
            ],
          ] else ...[
            _buildCalendar(),
            const SizedBox(height: 22),
            _buildUpcomingHeader(),
            const SizedBox(height: 12),
            ..._buildUpcomingEventCards(),
          ],
        ],
      ),
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
    if (!_eventsLoaded) return [_buildLoadingPanel()];

    // Walk every day in the visible month (not just each event's start
    // day) so a multi-day event shows under every day header it spans.
    final daysInMonth =
        DateUtils.getDaysInMonth(_listMonth.year, _listMonth.month);
    final widgets = <Widget>[];

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime.utc(_listMonth.year, _listMonth.month, day);
      final dayEvents = _events
          .where((event) => event.occursOnDay(date))
          .where(_passesTypeFilter)
          .where(_passesCalendarSearch)
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      if (dayEvents.isEmpty) continue;

      // Tappable day header — opens that day's own full-page view (with its
      // Add button), the same destination as tapping a day on the Month/Week
      // grid. The agenda entries below stay inline exactly as before.
      widgets.add(InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => unawaited(_openDayDetail(date)),
        child: Padding(
          padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 10, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, MMM d').format(date),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              FaIcon(
                FontAwesomeIcons.chevronRight,
                size: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ));
      for (final event in dayEvents) {
        widgets.add(_buildEventCard(event));
        widgets.add(const SizedBox(height: 12));
      }
    }

    if (widgets.isEmpty) {
      return [
        GlassPanel(
          child: Text(
            _calendarSearchQuery.trim().isEmpty
                ? 'No events in ${DateFormat('MMMM yyyy').format(_listMonth)}.'
                : 'No events in ${DateFormat('MMMM yyyy').format(_listMonth)} match your search.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ];
    }
    return widgets;
  }

  Widget _buildListSubModeToggle() {
    final colorScheme = Theme.of(context).colorScheme;
    return SegmentedButton<_ListSubMode>(
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
        ButtonSegment<_ListSubMode>(
          value: _ListSubMode.byMonth,
          label: Text('By Month'),
        ),
        ButtonSegment<_ListSubMode>(
          value: _ListSubMode.upcoming,
          label: Text('Upcoming'),
        ),
      ],
      selected: {_listSubMode},
      onSelectionChanged: (selection) => setState(() => _listSubMode = selection.first),
    );
  }

  Widget _buildUpcomingSortBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            _upcomingAscending ? 'Soonest first' : 'Furthest first',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        IconButton(
          key: const Key('upcoming-sort-toggle'),
          tooltip: _upcomingAscending
              ? 'Sorted soonest first — tap for furthest first'
              : 'Sorted furthest first — tap for soonest first',
          onPressed: () => setState(() => _upcomingAscending = !_upcomingAscending),
          icon: FaIcon(
            _upcomingAscending
                ? FontAwesomeIcons.arrowDownWideShort
                : FontAwesomeIcons.arrowUpWideShort,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Flat feed of not-yet-ended events sorted by distance from now (not
  /// grouped by a browsed month like [_buildMonthListSections]) — still
  /// broken into day-header groups since events span many different days,
  /// just following whichever sort order [_upcomingAscending] picks rather
  /// than always chronological-ascending.
  List<Widget> _buildUpcomingListSections() {
    if (!_eventsLoaded) return [_buildLoadingPanel()];

    final now = DateTime.now();
    final events = _events
        .where((event) => event.endTime.isAfter(now))
        .where(_passesTypeFilter)
        .where(_passesCalendarSearch)
        .toList()
      ..sort((a, b) => _upcomingAscending
          ? a.startTime.compareTo(b.startTime)
          : b.startTime.compareTo(a.startTime));

    if (events.isEmpty) {
      return [
        GlassPanel(
          child: Text(
            _calendarSearchQuery.trim().isEmpty
                ? 'No upcoming events right now.'
                : 'No upcoming events match your search.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    String? currentLabel;
    for (final event in events) {
      final label = DateFormat('EEEE, MMM d').format(event.startTime);
      if (label != currentLabel) {
        currentLabel = label;
        widgets.add(Padding(
          padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 10, bottom: 8),
          child: Text(
            label,
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

  void _toggleTypeFilter(Set<String> filters, String? value) {
    setState(() {
      if (value == null) {
        filters.clear();
      } else if (filters.contains(value)) {
        filters.remove(value);
      } else {
        filters.add(value);
      }
      // Changing which posts match should always land back on page 1,
      // rather than possibly stranding the user on a now out-of-range page.
      if (identical(filters, _feedTypeFilters)) _feedPage = 0;
    });
  }

  /// Shared by the Calendar tab's own [_typeFilters] and the Feed tab's
  /// independent [_feedTypeFilters] — filtering one shouldn't silently
  /// affect what the other shows. [keyPrefix] keeps the two sets of chips
  /// distinguishable in tests: both tabs stay mounted at once (they're
  /// siblings in an `IndexedStack`, not swapped out), so identical labels
  /// like "Personal" exist in both trees simultaneously.
  Widget _buildTypeFilterChips(Set<String> filters,
      {required String keyPrefix}) {
    final options = <({String? value, String label, FaIconData icon})>[
      (value: null, label: 'All', icon: FontAwesomeIcons.layerGroup),
      (value: EventType.public, label: 'Public', icon: FontAwesomeIcons.globe),
      (
        value: EventType.shared,
        label: 'Group',
        icon: FontAwesomeIcons.userGroup
      ),
      (
        value: EventType.personal,
        label: 'Personal',
        icon: FontAwesomeIcons.lock
      ),
    ];
    final colorScheme = Theme.of(context).colorScheme;

    // "All" is active when no specific type is checked; the type chips are
    // checkable so several can be enabled at once.
    bool isActive(String? value) =>
        value == null ? filters.isEmpty : filters.contains(value);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options) ...[
            InkWell(
              key: Key('$keyPrefix-filter-${option.value ?? 'all'}'),
              borderRadius: BorderRadius.circular(999),
              onTap: () => _toggleTypeFilter(filters, option.value),
              child: GlassPanel(
                borderRadius: 999,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/icons/Municipal_LOGO.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MUNICIPALITY OF BONGABONG',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'eBongabong Calendar',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
        if (widget.authService != null)
          InkWell(
            onTap: () => _handleTabSelected(_profileTabIndex),
            borderRadius: BorderRadius.circular(28),
            child: RoleAvatarFrame(
              role: profile?.role ?? 'citizen',
              size: 48,
              child: profile?.avatarUrl != null
                  ? Image.asset(profile!.avatarUrl!, fit: BoxFit.cover)
                  : IconBadge(
                      icon: FontAwesomeIcons.circleUser,
                      tint: Theme.of(context).colorScheme.primary,
                      size: 48,
                      iconSize: 20,
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildUpcomingHeader() {
    final selected = _selectedDay;
    final isToday = selected == null || isSameDay(selected, DateTime.now());
    return Row(
      children: [
        Text(
          isToday ? 'Upcoming' : 'Events for ${_formatDate(selected)}',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  List<Widget> _buildUpcomingEventCards() {
    if (!_eventsLoaded) return [_buildLoadingPanel()];

    final events = _getEventsForDay(_selectedDay ?? _focusedDay);

    if (events.isEmpty) {
      return [
        GlassPanel(
          child: Text(
            'No events for ${_formatDate(_selectedDay ?? _focusedDay)}',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
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

  List<BarangayEvent> _filteredFeedEvents() {
    final query = _feedSearchQuery.trim().toLowerCase();
    final events = _events.where((event) {
      if (_feedTypeFilters.isNotEmpty &&
          !_feedTypeFilters.contains(event.eventType)) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = [
        event.title,
        event.location,
        event.description,
        event.creatorLabel ?? '',
        event.groupName ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return events;
  }

  /// Day-group header for the feed's timeline, based on when the event was
  /// *posted* (`createdAt`) — the feed stays sorted newest-posted-first,
  /// like a social feed, just with clearer day breaks.
  String _feedDayLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(time);
  }

  Widget _buildFeedTab() {
    final feedEvents = _filteredFeedEvents();
    final hasActiveFilter =
        _feedTypeFilters.isNotEmpty || _feedSearchQuery.trim().isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    final totalPages =
        feedEvents.isEmpty ? 1 : (feedEvents.length / _feedPageSize).ceil();
    final safePage = _feedPage.clamp(0, totalPages - 1);
    final pageStart = safePage * _feedPageSize;
    final pageEnd = (pageStart + _feedPageSize) > feedEvents.length
        ? feedEvents.length
        : pageStart + _feedPageSize;
    final pageEvents = feedEvents.sublist(pageStart, pageEnd);

    return RefreshIndicator(
      onRefresh: _refreshEvents,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
        children: [
          _buildPageHeader(
              'Feed', 'New events from people you follow and the community.'),
          const SizedBox(height: 16),
          TextField(
            controller: _feedSearchController,
            onChanged: (value) => setState(() {
              _feedSearchQuery = value;
              _feedPage = 0;
            }),
            decoration: InputDecoration(
              labelText: 'Search the feed',
              hintText: 'Title, location, or who posted it',
              prefixIcon:
                  glassFieldIcon(FontAwesomeIcons.magnifyingGlass, size: 14),
              prefixIconConstraints: glassFieldIconConstraints,
              suffixIcon: _feedSearchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const FaIcon(FontAwesomeIcons.xmark, size: 14),
                      onPressed: () {
                        _feedSearchController.clear();
                        setState(() {
                          _feedSearchQuery = '';
                          _feedPage = 0;
                        });
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _buildTypeFilterChips(_feedTypeFilters, keyPrefix: 'feed'),
          const SizedBox(height: 18),
          if (!_eventsLoaded)
            _buildLoadingPanel()
          else if (feedEvents.isEmpty)
            GlassPanel(
              child: Text(
                hasActiveFilter
                    ? 'No posts match your search or filter.'
                    : 'Nothing here yet. Join groups from the Groups tab to see their '
                        'events, or check back for public announcements.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            )
          else ...[
            ..._buildFeedTimeline(pageEvents),
            if (totalPages > 1) ...[
              const SizedBox(height: 8),
              _buildFeedPaginationBar(safePage, totalPages),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFeedPaginationBar(int currentPage, int totalPages) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassPanel(
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('feed-prev-page'),
            tooltip: 'Previous page',
            onPressed: currentPage > 0
                ? () => setState(() => _feedPage = currentPage - 1)
                : null,
            icon: FaIcon(
              FontAwesomeIcons.chevronLeft,
              size: 15,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              'Page ${currentPage + 1} of $totalPages',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          IconButton(
            key: const Key('feed-next-page'),
            tooltip: 'Next page',
            onPressed: currentPage < totalPages - 1
                ? () => setState(() => _feedPage = currentPage + 1)
                : null,
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

  /// Builds the feed's day-grouped timeline: a header per day break, and a
  /// vertical rail + dot down the left of each entry connecting it to its
  /// neighbors within the same day group (gapped at the very top/bottom of
  /// each group, like a typical social-feed/agenda timeline).
  List<Widget> _buildFeedTimeline(List<BarangayEvent> events) {
    final widgets = <Widget>[];
    String? currentLabel;

    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      final label = _feedDayLabel(event.createdAt);
      if (label != currentLabel) {
        currentLabel = label;
        widgets.add(Padding(
          padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 20, bottom: 10),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ));
      }
      final isFirstInGroup =
          i == 0 || _feedDayLabel(events[i - 1].createdAt) != label;
      final isLastInGroup = i == events.length - 1 ||
          _feedDayLabel(events[i + 1].createdAt) != label;
      widgets.add(_buildTimelineEntry(event,
          isFirst: isFirstInGroup, isLast: isLastInGroup));
    }
    return widgets;
  }

  Widget _buildTimelineEntry(BarangayEvent event,
      {required bool isFirst, required bool isLast}) {
    final tint = _getEventTint(event.title);
    final railColor = tint.withValues(alpha: 0.3);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  _formatTime(event.startTime),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 2,
                  height: 6,
                  color: isFirst ? Colors.transparent : railColor,
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: tint),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : railColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildFeedCard(event),
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(time);
  }

  Widget _buildFeedCard(BarangayEvent event) {
    final colorScheme = Theme.of(context).colorScheme;
    final isNew = event.createdAt.millisecondsSinceEpoch > _feedNewThreshold;
    final postedBy = event.creatorLabel ?? 'eBongabong Calendar';

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () => _showEventDetails(event),
      child: GlassPanel(
        borderRadius: 26,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(
                icon: _getEventIcon(event.title),
                tint: _getEventTint(event.title)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          event.title,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      if (isNew) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFE53935).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFE53935)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE53935),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      _buildEventTypePill(event.eventType),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FaIcon(
                        event.isMultiDay
                            ? FontAwesomeIcons.calendarWeek
                            : FontAwesomeIcons.clock,
                        size: 12,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${_dateRangeLabel(event)} • ${_formatTime(event.startTime)} - ${_formatTime(event.endTime)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
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
                        FontAwesomeIcons.locationDot,
                        size: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          event.location,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Posted by $postedBy • ${_relativeTime(event.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            FaIcon(
              FontAwesomeIcons.chevronRight,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
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
            // Horizontal swipe still pages between months/weeks; the
            // vertical swipe that silently flips Month<->Week format is
            // disabled — that's the Month/Week/List buttons' job now, not
            // a gesture the user might trigger by accident.
            availableGestures: AvailableGestures.horizontalSwipe,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Monthly',
              CalendarFormat.week: 'Weekly',
            },
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              unawaited(_openDayDetail(selectedDay));
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

                // Multi-day events (e.g. a 3-day fiesta) get an extra
                // accent bar on every day they span, distinct from the
                // regular single-day dot, so a long event is easy to spot
                // at a glance in the grid.
                final hasMultiDay = dayEvents.any((event) => event.isMultiDay);

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      bottom: hasMultiDay ? 7 : 3,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    if (hasMultiDay)
                      const Positioned(
                        bottom: 1,
                        child: SizedBox(
                          width: 18,
                          height: 3,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFFFFA726),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(2)),
                            ),
                          ),
                        ),
                      ),
                  ],
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
              leftChevronIcon: FaIcon(FontAwesomeIcons.chevronLeft,
                  size: 15, color: colorScheme.onSurfaceVariant),
              rightChevronIcon: FaIcon(FontAwesomeIcons.chevronRight,
                  size: 15, color: colorScheme.onSurfaceVariant),
              titleTextStyle: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface),
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
    final formattedDate = _dateRangeLabel(event);
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
                                          ?.copyWith(
                                              fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Group info (group events): which group + member count.
                      if (event.eventType == EventType.shared) ...[
                        _GroupInfoSection(
                          event: event,
                          repository: widget.eventRepository,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Description section (if not empty)
                      if (event.description.isNotEmpty) ...[
                        Text(
                          'Description',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
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
                                _getFileIcon(event.attachmentType ??
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
                                      _getFileTypeName(event.attachmentType ??
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

                      // Edit (creator, or an admin of the event's group)
                      // and Delete (creator only)
                      if (_canEditEvent(event) || _canDeleteEvent(event)) ...[
                        Row(
                          children: [
                            if (_canEditEvent(event))
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    unawaited(_openEditEvent(event));
                                  },
                                  icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 16),
                                  label: const Text('Edit'),
                                ),
                              ),
                            if (_canEditEvent(event) && _canDeleteEvent(event))
                              const SizedBox(width: 10),
                            if (_canDeleteEvent(event))
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).colorScheme.error,
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
                                  icon: const FaIcon(FontAwesomeIcons.trashCan,
                                      size: 16),
                                  label: const Text('Delete event'),
                                ),
                              ),
                          ],
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
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
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
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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
                        event.isMultiDay
                            ? FontAwesomeIcons.calendarWeek
                            : FontAwesomeIcons.clock,
                        size: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${_dateRangeLabel(event)} • ${_formatTime(startTime)} - ${_formatTime(endTime)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
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
                          _getFileIcon(event.attachmentType ??
                              'application/octet-stream'),
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
            if (_canEditEvent(event) || _canDeleteEvent(event))
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    unawaited(_openEditEvent(event));
                  } else if (value == 'delete') {
                    unawaited(_confirmDeleteEvent(event));
                  }
                },
                itemBuilder: (context) => [
                  if (_canEditEvent(event))
                    const PopupMenuItem(value: 'edit', child: Text('Edit event')),
                  if (_canDeleteEvent(event))
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete event',
                        style:
                            TextStyle(color: Theme.of(context).colorScheme.error),
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
        return 'Group';
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

  String? get _currentUserId =>
      (_userProfile ?? widget.authService?.currentUser)?.id;

  bool get _canCreateGroups =>
      (_userProfile ?? widget.authService?.currentUser)?.canCreateGroups ??
      false;

  /// Citizens don't get a Groups tab at all — group creation/events are an
  /// LGU-level feature (see [[project-event-sharing-model]]), so there's
  /// nothing for them to do there besides being confused by an empty tab.
  bool get _showGroupsTab =>
      (_userProfile ?? widget.authService?.currentUser)?.role != 'citizen';

  /// Profile's index in the bottom tab bar shifts left by one when the
  /// Groups tab is hidden — Calendar (0) and Feed (1) never move.
  int get _profileTabIndex => _showGroupsTab ? 3 : 2;

  bool _canDeleteEvent(BarangayEvent event) {
    final userId = _currentUserId;
    return userId != null && event.createdById == userId;
  }

  /// Creator can always edit; for a Group event, an admin of that specific
  /// group can too (promoted via the Group Members page) — "in case of
  /// emergency" per the original ask, reusing the existing admin
  /// permission rather than a separate edit-only role.
  bool _canEditEvent(BarangayEvent event) {
    final userId = _currentUserId;
    if (userId == null) return false;
    if (event.createdById == userId) return true;
    return event.eventType == EventType.shared &&
        event.groupId != null &&
        _adminGroupIds.contains(event.groupId);
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

  String _formatTime(DateTime time) => formatDateTime12Hour(time);

  String _formatDate(DateTime date) {
    return DateFormat('EEEE, MMM d, yyyy').format(date);
  }

  /// [_formatDate] for a single-day event, or a compact "MMM d – MMM d,
  /// yyyy" span for a multi-day one.
  String _dateRangeLabel(BarangayEvent event) {
    if (!event.isMultiDay) return _formatDate(event.startTime);
    final sameYear = event.startTime.year == event.endTime.year;
    final start =
        DateFormat(sameYear ? 'MMM d' : 'MMM d, yyyy').format(event.startTime);
    final end = DateFormat('MMM d, yyyy').format(event.endTime);
    return '$start – $end';
  }

}

/// The "Group" block inside the event details sheet for group events:
/// shows which group the event belongs to and how many members it has.
class _GroupInfoSection extends StatefulWidget {
  const _GroupInfoSection({
    required this.event,
    required this.repository,
  });

  final BarangayEvent event;
  final EventRepository repository;

  @override
  State<_GroupInfoSection> createState() => _GroupInfoSectionState();
}

class _GroupInfoSectionState extends State<_GroupInfoSection> {
  int? _memberCount;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCount());
  }

  Future<void> _loadCount() async {
    final groupId = widget.event.groupId;
    if (groupId == null) return;
    try {
      final count = await widget.repository.fetchGroupMemberCount(groupId);
      if (!mounted) return;
      setState(() => _memberCount = count);
    } catch (_) {
      // Count stays hidden; the group name is still shown.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final groupName = widget.event.groupName?.trim().isNotEmpty == true
        ? widget.event.groupName!
        : 'Group event';
    final count = _memberCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.userGroup,
            color: colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Group',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == null
                      ? groupName
                      : '$groupName • $count member${count == 1 ? '' : 's'}',
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
    );
  }
}

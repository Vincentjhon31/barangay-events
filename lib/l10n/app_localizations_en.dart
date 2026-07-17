// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Community events, at a glance.';

  @override
  String get loginTitle => 'Login';

  @override
  String get signUpTitle => 'Create an account';

  @override
  String get authSubtitle =>
      'Use your account to access and publish barangay events.';

  @override
  String get nameLabel => 'Name';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get pleaseWait => 'Please wait...';

  @override
  String get createAccountButton => 'Create account';

  @override
  String get loginButton => 'Login';

  @override
  String get haveAccountPrompt => 'Already have an account? Login';

  @override
  String get needAccountPrompt => 'Need an account? Create one';

  @override
  String get authEmailPasswordRequired => 'Email and password are required.';

  @override
  String get authNameRequired => 'Name is required.';

  @override
  String get authPasswordTooShort => 'Password must be at least 6 characters.';

  @override
  String get authPasswordsDontMatch => 'Passwords do not match.';

  @override
  String get authAccountCreated =>
      'Account created. You may need to confirm your email before signing in.';

  @override
  String get authFailedGeneric => 'Authentication failed.';

  @override
  String get tabCalendar => 'Calendar';

  @override
  String get tabFeed => 'Feed';

  @override
  String get tabGroups => 'Groups';

  @override
  String get tabProfile => 'Profile';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get edit => 'Edit';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle => 'Personalize how the app looks.';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsSystemDefault => 'System default';

  @override
  String get settingsLight => 'Light';

  @override
  String get settingsDark => 'Dark';

  @override
  String get settingsAppStyle => 'App style';

  @override
  String get settingsLiquidGlass => 'Liquid Glass';

  @override
  String get settingsLiquidGlassSubtitle =>
      'Translucent panels and glowing colors';

  @override
  String get settingsSolid => 'Solid';

  @override
  String get settingsSolidSubtitle => 'Plain colors — faster on most phones';

  @override
  String get settingsDisplaySize => 'Display size';

  @override
  String get settingsDisplaySizeHint =>
      'Auto fits the screen automatically — pick a fixed size instead if this device (e.g. a kiosk display) needs it locked.';

  @override
  String get settingsDisplayAuto => 'Fits the screen automatically';

  @override
  String get settingsDisplayMobile => 'Compact, no scaling';

  @override
  String get settingsDisplayTablet => 'Medium — about 1.5x';

  @override
  String get settingsDisplayWindows => 'Large — about 2x, for kiosk displays';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageHint =>
      'Switch the app\'s language. Takes effect immediately.';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFilipino => 'Filipino';

  @override
  String get calendarViewMonth => 'Month';

  @override
  String get calendarViewWeek => 'Week';

  @override
  String get calendarViewList => 'List';

  @override
  String get addEventButton => 'Add event';

  @override
  String get upcomingHeader => 'Upcoming';

  @override
  String eventsForDate(String date) {
    return 'Events for $date';
  }

  @override
  String noEventsForDate(String date) {
    return 'No events for $date';
  }

  @override
  String get nothingTodayFallback =>
      'Nothing today — here\'s what\'s coming up:';

  @override
  String get calendarSearchLabel => 'Search events';

  @override
  String get calendarSearchHint => 'Title, location, or who posted it';

  @override
  String get deleteEventTitle => 'Delete event';

  @override
  String deleteEventConfirm(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get feedTitle => 'Feed';

  @override
  String get feedSubtitle =>
      'New events from people you follow and the community.';

  @override
  String get feedSearchLabel => 'Search the feed';

  @override
  String get feedSearchHint => 'Title, location, or who posted it';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get feedEmptyFiltered => 'No posts match your search or filter.';

  @override
  String get feedEmpty =>
      'Nothing here yet. Join groups from the Groups tab to see their events, or check back for public announcements.';

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String pageOfTotal(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get groupsTitle => 'Groups';

  @override
  String get groupsSubtitle =>
      'Like group chats, but for events everyone should see.';

  @override
  String get searchGroups => 'Search groups';

  @override
  String get closeSearch => 'Close search';

  @override
  String get groupsCreateTile => 'Create';

  @override
  String get groupsCreateCaption => 'Start a new group';

  @override
  String get groupsCreateLguOnly => 'LGU members only';

  @override
  String get groupsJoinTile => 'Join a code';

  @override
  String get groupsJoinCaption => 'Use an invite code';

  @override
  String myGroupsHeader(int count) {
    return 'My Groups ($count)';
  }

  @override
  String get myGroupsEmpty =>
      'You are not in any group yet. Use \"Add a group\" below to create one, search, or enter a code.';

  @override
  String joinRequestsHeader(int count) {
    return 'Join requests ($count)';
  }

  @override
  String get accountSectionHeader => 'Account';

  @override
  String get profileInformationTile => 'Profile Information';

  @override
  String get profileInformationCaption =>
      'Name, department, contact and address';

  @override
  String get settingsTile => 'Settings';

  @override
  String get settingsTileCaption => 'Appearance and app preferences';

  @override
  String get aboutTile => 'About';

  @override
  String get aboutTileCaption => 'Version, updates, and what\'s new';

  @override
  String get signOut => 'Sign out';

  @override
  String get defaultMemberName => 'Barangay Member';

  @override
  String get noEmailAvailable => 'No email available';

  @override
  String get searchByName => 'Search by name';

  @override
  String get searchHintExample => 'e.g. Mayor';

  @override
  String get searchButton => 'Search';

  @override
  String get noGroupsFound =>
      'No groups found. Try another name, or ask for the code.';

  @override
  String get privateGroupsHint =>
      'Private groups won\'t show up here — you\'ll need their code.';

  @override
  String get declineButton => 'Decline';

  @override
  String get acceptButton => 'Accept';

  @override
  String wantsToJoinGroup(String groupName) {
    return 'wants to join \"$groupName\"';
  }

  @override
  String get copyGroupCode => 'Copy group code';

  @override
  String get leaveButton => 'Leave';

  @override
  String memberCountWithCode(int count, String code) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# members',
      one: '# member',
    );
    return '$_temp0 • code $code';
  }

  @override
  String memberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# members',
      one: '# member',
    );
    return '$_temp0';
  }

  @override
  String get joinedButton => 'Joined';

  @override
  String get joinButton => 'Join';
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fil.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fil')
  ];

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Community events, at a glance.'**
  String get appTagline;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get signUpTitle;

  /// No description provided for @authSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your account to access and publish barangay events.'**
  String get authSubtitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait...'**
  String get pleaseWait;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountButton;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @haveAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Login'**
  String get haveAccountPrompt;

  /// No description provided for @needAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Need an account? Create one'**
  String get needAccountPrompt;

  /// No description provided for @authEmailPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Email and password are required.'**
  String get authEmailPasswordRequired;

  /// No description provided for @authNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get authNameRequired;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get authPasswordTooShort;

  /// No description provided for @authPasswordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authPasswordsDontMatch;

  /// No description provided for @authAccountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created. You may need to confirm your email before signing in.'**
  String get authAccountCreated;

  /// No description provided for @authFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed.'**
  String get authFailedGeneric;

  /// No description provided for @tabCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get tabCalendar;

  /// No description provided for @tabFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get tabFeed;

  /// No description provided for @tabGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get tabGroups;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personalize how the app looks.'**
  String get settingsSubtitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsSystemDefault;

  /// No description provided for @settingsLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsLight;

  /// No description provided for @settingsDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsDark;

  /// No description provided for @settingsAppStyle.
  ///
  /// In en, this message translates to:
  /// **'App style'**
  String get settingsAppStyle;

  /// No description provided for @settingsLiquidGlass.
  ///
  /// In en, this message translates to:
  /// **'Liquid Glass'**
  String get settingsLiquidGlass;

  /// No description provided for @settingsLiquidGlassSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Translucent panels and glowing colors'**
  String get settingsLiquidGlassSubtitle;

  /// No description provided for @settingsSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get settingsSolid;

  /// No description provided for @settingsSolidSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plain colors — faster on most phones'**
  String get settingsSolidSubtitle;

  /// No description provided for @settingsDisplaySize.
  ///
  /// In en, this message translates to:
  /// **'Display size'**
  String get settingsDisplaySize;

  /// No description provided for @settingsDisplaySizeHint.
  ///
  /// In en, this message translates to:
  /// **'Auto fits the screen automatically — pick a fixed size instead if this device (e.g. a kiosk display) needs it locked.'**
  String get settingsDisplaySizeHint;

  /// No description provided for @settingsDisplayAuto.
  ///
  /// In en, this message translates to:
  /// **'Fits the screen automatically'**
  String get settingsDisplayAuto;

  /// No description provided for @settingsDisplayMobile.
  ///
  /// In en, this message translates to:
  /// **'Compact, no scaling'**
  String get settingsDisplayMobile;

  /// No description provided for @settingsDisplayTablet.
  ///
  /// In en, this message translates to:
  /// **'Medium — about 1.5x'**
  String get settingsDisplayTablet;

  /// No description provided for @settingsDisplayWindows.
  ///
  /// In en, this message translates to:
  /// **'Large — about 2x, for kiosk displays'**
  String get settingsDisplayWindows;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Switch the app\'s language. Takes effect immediately.'**
  String get settingsLanguageHint;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageFilipino.
  ///
  /// In en, this message translates to:
  /// **'Filipino'**
  String get settingsLanguageFilipino;

  /// No description provided for @calendarViewMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calendarViewMonth;

  /// No description provided for @calendarViewWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get calendarViewWeek;

  /// No description provided for @calendarViewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get calendarViewList;

  /// No description provided for @addEventButton.
  ///
  /// In en, this message translates to:
  /// **'Add event'**
  String get addEventButton;

  /// No description provided for @upcomingHeader.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcomingHeader;

  /// No description provided for @eventsForDate.
  ///
  /// In en, this message translates to:
  /// **'Events for {date}'**
  String eventsForDate(String date);

  /// No description provided for @noEventsForDate.
  ///
  /// In en, this message translates to:
  /// **'No events for {date}'**
  String noEventsForDate(String date);

  /// No description provided for @nothingTodayFallback.
  ///
  /// In en, this message translates to:
  /// **'Nothing today — here\'s what\'s coming up:'**
  String get nothingTodayFallback;

  /// No description provided for @calendarSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search events'**
  String get calendarSearchLabel;

  /// No description provided for @calendarSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Title, location, or who posted it'**
  String get calendarSearchHint;

  /// No description provided for @deleteEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete event'**
  String get deleteEventTitle;

  /// No description provided for @deleteEventConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? This cannot be undone.'**
  String deleteEventConfirm(String title);

  /// No description provided for @feedTitle.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feedTitle;

  /// No description provided for @feedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New events from people you follow and the community.'**
  String get feedSubtitle;

  /// No description provided for @feedSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search the feed'**
  String get feedSearchLabel;

  /// No description provided for @feedSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Title, location, or who posted it'**
  String get feedSearchHint;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @feedEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No posts match your search or filter.'**
  String get feedEmptyFiltered;

  /// No description provided for @feedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Join groups from the Groups tab to see their events, or check back for public announcements.'**
  String get feedEmpty;

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @pageOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pageOfTotal(int current, int total);

  /// No description provided for @groupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groupsTitle;

  /// No description provided for @groupsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Like group chats, but for events everyone should see.'**
  String get groupsSubtitle;

  /// No description provided for @searchGroups.
  ///
  /// In en, this message translates to:
  /// **'Search groups'**
  String get searchGroups;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// No description provided for @groupsCreateTile.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get groupsCreateTile;

  /// No description provided for @groupsCreateCaption.
  ///
  /// In en, this message translates to:
  /// **'Start a new group'**
  String get groupsCreateCaption;

  /// No description provided for @groupsCreateLguOnly.
  ///
  /// In en, this message translates to:
  /// **'LGU members only'**
  String get groupsCreateLguOnly;

  /// No description provided for @groupsJoinTile.
  ///
  /// In en, this message translates to:
  /// **'Join a code'**
  String get groupsJoinTile;

  /// No description provided for @groupsJoinCaption.
  ///
  /// In en, this message translates to:
  /// **'Use an invite code'**
  String get groupsJoinCaption;

  /// No description provided for @myGroupsHeader.
  ///
  /// In en, this message translates to:
  /// **'My Groups ({count})'**
  String myGroupsHeader(int count);

  /// No description provided for @myGroupsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You are not in any group yet. Use \"Add a group\" below to create one, search, or enter a code.'**
  String get myGroupsEmpty;

  /// No description provided for @joinRequestsHeader.
  ///
  /// In en, this message translates to:
  /// **'Join requests ({count})'**
  String joinRequestsHeader(int count);

  /// No description provided for @accountSectionHeader.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSectionHeader;

  /// No description provided for @profileInformationTile.
  ///
  /// In en, this message translates to:
  /// **'Profile Information'**
  String get profileInformationTile;

  /// No description provided for @profileInformationCaption.
  ///
  /// In en, this message translates to:
  /// **'Name, department, contact and address'**
  String get profileInformationCaption;

  /// No description provided for @settingsTile.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTile;

  /// No description provided for @settingsTileCaption.
  ///
  /// In en, this message translates to:
  /// **'Appearance and app preferences'**
  String get settingsTileCaption;

  /// No description provided for @aboutTile.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTile;

  /// No description provided for @aboutTileCaption.
  ///
  /// In en, this message translates to:
  /// **'Version, updates, and what\'s new'**
  String get aboutTileCaption;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @defaultMemberName.
  ///
  /// In en, this message translates to:
  /// **'Barangay Member'**
  String get defaultMemberName;

  /// No description provided for @noEmailAvailable.
  ///
  /// In en, this message translates to:
  /// **'No email available'**
  String get noEmailAvailable;

  /// No description provided for @searchByName.
  ///
  /// In en, this message translates to:
  /// **'Search by name'**
  String get searchByName;

  /// No description provided for @searchHintExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. Mayor'**
  String get searchHintExample;

  /// No description provided for @searchButton.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchButton;

  /// No description provided for @noGroupsFound.
  ///
  /// In en, this message translates to:
  /// **'No groups found. Try another name, or ask for the code.'**
  String get noGroupsFound;

  /// No description provided for @privateGroupsHint.
  ///
  /// In en, this message translates to:
  /// **'Private groups won\'t show up here — you\'ll need their code.'**
  String get privateGroupsHint;

  /// No description provided for @declineButton.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineButton;

  /// No description provided for @acceptButton.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptButton;

  /// No description provided for @wantsToJoinGroup.
  ///
  /// In en, this message translates to:
  /// **'wants to join \"{groupName}\"'**
  String wantsToJoinGroup(String groupName);

  /// No description provided for @copyGroupCode.
  ///
  /// In en, this message translates to:
  /// **'Copy group code'**
  String get copyGroupCode;

  /// No description provided for @leaveButton.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveButton;

  /// No description provided for @memberCountWithCode.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{# member} other{# members}} • code {code}'**
  String memberCountWithCode(int count, String code);

  /// No description provided for @memberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{# member} other{# members}}'**
  String memberCount(int count);

  /// No description provided for @joinedButton.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joinedButton;

  /// No description provided for @joinButton.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fil'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fil':
      return AppLocalizationsFil();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

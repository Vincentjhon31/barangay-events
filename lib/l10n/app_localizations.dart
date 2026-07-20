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
  /// **'{count, plural, one{{count} member} other{{count} members}} • code {code}'**
  String memberCountWithCode(int count, String code);

  /// No description provided for @memberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} member} other{{count} members}}'**
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

  /// No description provided for @eventTypeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get eventTypeAll;

  /// No description provided for @eventTypePublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get eventTypePublic;

  /// No description provided for @eventTypeGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get eventTypeGroup;

  /// No description provided for @eventTypePersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get eventTypePersonal;

  /// No description provided for @eventDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Event Details'**
  String get eventDetailsTitle;

  /// No description provided for @shareEvent.
  ///
  /// In en, this message translates to:
  /// **'Share event'**
  String get shareEvent;

  /// No description provided for @detailTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get detailTime;

  /// No description provided for @detailLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get detailLocation;

  /// No description provided for @detailPostedBy.
  ///
  /// In en, this message translates to:
  /// **'Posted by'**
  String get detailPostedBy;

  /// No description provided for @postedByPrefix.
  ///
  /// In en, this message translates to:
  /// **'By {name}'**
  String postedByPrefix(String name);

  /// No description provided for @detailDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get detailDescription;

  /// No description provided for @detailAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get detailAttachment;

  /// No description provided for @attachmentAvailable.
  ///
  /// In en, this message translates to:
  /// **'Attachment available'**
  String get attachmentAvailable;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @editEventMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get editEventMenuItem;

  /// No description provided for @deleteEventMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Delete event'**
  String get deleteEventMenuItem;

  /// No description provided for @groupEventFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Group event'**
  String get groupEventFallbackName;

  /// No description provided for @loadingMembers.
  ///
  /// In en, this message translates to:
  /// **'Loading members…'**
  String get loadingMembers;

  /// No description provided for @fileTypePdf.
  ///
  /// In en, this message translates to:
  /// **'PDF Document'**
  String get fileTypePdf;

  /// No description provided for @fileTypeImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get fileTypeImage;

  /// No description provided for @fileTypeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get fileTypeVideo;

  /// No description provided for @fileTypeWord.
  ///
  /// In en, this message translates to:
  /// **'Word Document'**
  String get fileTypeWord;

  /// No description provided for @fileTypeSpreadsheet.
  ///
  /// In en, this message translates to:
  /// **'Spreadsheet'**
  String get fileTypeSpreadsheet;

  /// No description provided for @addedEventToGroup.
  ///
  /// In en, this message translates to:
  /// **'Added \"{title}\" to {groupName}.'**
  String addedEventToGroup(String title, String groupName);

  /// No description provided for @addedEventToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Added \"{title}\" to the calendar.'**
  String addedEventToCalendar(String title);

  /// No description provided for @editEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get editEventTitle;

  /// No description provided for @addEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Event'**
  String get addEventTitle;

  /// No description provided for @editEventSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update the details for this event.'**
  String get editEventSubtitle;

  /// No description provided for @addEventSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share something happening in the barangay.'**
  String get addEventSubtitle;

  /// No description provided for @typeHelperGroup.
  ///
  /// In en, this message translates to:
  /// **'Only members of the group you pick can see this.'**
  String get typeHelperGroup;

  /// No description provided for @typeHelperPersonal.
  ///
  /// In en, this message translates to:
  /// **'Only you can see this.'**
  String get typeHelperPersonal;

  /// No description provided for @typeHelperPublic.
  ///
  /// In en, this message translates to:
  /// **'Everyone in the app can see this.'**
  String get typeHelperPublic;

  /// No description provided for @typeHelperRestrictedSuffix.
  ///
  /// In en, this message translates to:
  /// **'Only verified LGU members can post Group events, and only the admin can post Public events.'**
  String get typeHelperRestrictedSuffix;

  /// No description provided for @personalEventLabel.
  ///
  /// In en, this message translates to:
  /// **'Personal event'**
  String get personalEventLabel;

  /// No description provided for @noGroupsYetError.
  ///
  /// In en, this message translates to:
  /// **'You have no groups yet — create one in the Groups tab first.'**
  String get noGroupsYetError;

  /// No description provided for @postToGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Post to group'**
  String get postToGroupLabel;

  /// No description provided for @eventTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Event title'**
  String get eventTitleLabel;

  /// No description provided for @eventTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Barangay Assembly'**
  String get eventTitleHint;

  /// No description provided for @locationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Barangay Hall'**
  String get locationHint;

  /// No description provided for @additionalDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Additional Details (optional)'**
  String get additionalDetailsLabel;

  /// No description provided for @additionalDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Add a short note for residents'**
  String get additionalDetailsHint;

  /// No description provided for @multiDayEventLabel.
  ///
  /// In en, this message translates to:
  /// **'Multi-day event'**
  String get multiDayEventLabel;

  /// No description provided for @multiDayEventHint.
  ///
  /// In en, this message translates to:
  /// **'Spans more than one day, e.g. a 3-day fiesta.'**
  String get multiDayEventHint;

  /// No description provided for @startDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDateLabel;

  /// No description provided for @endDateLabel.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDateLabel;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @defaultStartTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Default start time'**
  String get defaultStartTimeLabel;

  /// No description provided for @startTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTimeLabel;

  /// No description provided for @defaultEndTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Default end time'**
  String get defaultEndTimeLabel;

  /// No description provided for @endTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get endTimeLabel;

  /// No description provided for @changeButton.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeButton;

  /// No description provided for @overlapsWithOne.
  ///
  /// In en, this message translates to:
  /// **'Overlaps with an existing event:'**
  String get overlapsWithOne;

  /// No description provided for @overlapsWithMany.
  ///
  /// In en, this message translates to:
  /// **'Overlaps with {count} existing events:'**
  String overlapsWithMany(int count);

  /// No description provided for @adjustOverlapHint.
  ///
  /// In en, this message translates to:
  /// **'Adjust the time or date range to clear the overlap.'**
  String get adjustOverlapHint;

  /// No description provided for @noFreeSlotHint.
  ///
  /// In en, this message translates to:
  /// **'No free slot left that day — try another date.'**
  String get noFreeSlotHint;

  /// No description provided for @freeSlotSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Free slot: {start} – {end} · Tap to use'**
  String freeSlotSuggestion(String start, String end);

  /// No description provided for @overlapDialogTitleOne.
  ///
  /// In en, this message translates to:
  /// **'This overlaps with an existing event'**
  String get overlapDialogTitleOne;

  /// No description provided for @overlapDialogTitleMany.
  ///
  /// In en, this message translates to:
  /// **'This overlaps with {count} existing events'**
  String overlapDialogTitleMany(int count);

  /// No description provided for @overlapDialogBody.
  ///
  /// In en, this message translates to:
  /// **'You can still save it, but people may see two events scheduled at the same time:'**
  String get overlapDialogBody;

  /// No description provided for @proceedAnyway.
  ///
  /// In en, this message translates to:
  /// **'Proceed anyway'**
  String get proceedAnyway;

  /// No description provided for @savingButton.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get savingButton;

  /// No description provided for @saveChangesButton.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChangesButton;

  /// No description provided for @saveEventButton.
  ///
  /// In en, this message translates to:
  /// **'Save event'**
  String get saveEventButton;

  /// No description provided for @titleLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'Title and location are required.'**
  String get titleLocationRequired;

  /// No description provided for @pastDateError.
  ///
  /// In en, this message translates to:
  /// **'Events can\'t be added on a past date.'**
  String get pastDateError;

  /// No description provided for @endAfterStartMultiDay.
  ///
  /// In en, this message translates to:
  /// **'End must be after start.'**
  String get endAfterStartMultiDay;

  /// No description provided for @endAfterStartSingleDay.
  ///
  /// In en, this message translates to:
  /// **'End time must be after start time.'**
  String get endAfterStartSingleDay;

  /// No description provided for @pickGroupError.
  ///
  /// In en, this message translates to:
  /// **'Pick a group for this event — create or join one in the Groups tab.'**
  String get pickGroupError;

  /// No description provided for @saveEventError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the event: {error}'**
  String saveEventError(String error);

  /// No description provided for @perDayScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Per-day schedule'**
  String get perDayScheduleTitle;

  /// No description provided for @perDayScheduleHint.
  ///
  /// In en, this message translates to:
  /// **'Every day uses the default time above unless you customize it — e.g. a full day on day 1, just a few hours on day 2.'**
  String get perDayScheduleHint;

  /// No description provided for @defaultTimeRangeSuffix.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end} (default)'**
  String defaultTimeRangeSuffix(String start, String end);

  /// No description provided for @timeRange.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String timeRange(String start, String end);

  /// No description provided for @resetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetButton;

  /// No description provided for @allDayButton.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get allDayButton;

  /// No description provided for @customizeButton.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get customizeButton;

  /// No description provided for @securityTile.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securityTile;

  /// No description provided for @securityTileCaption.
  ///
  /// In en, this message translates to:
  /// **'Change your email and password'**
  String get securityTileCaption;

  /// No description provided for @securityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securityTitle;

  /// No description provided for @securitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your sign-in email and password.'**
  String get securitySubtitle;

  /// No description provided for @securityEmailSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get securityEmailSectionTitle;

  /// No description provided for @securityCurrentEmail.
  ///
  /// In en, this message translates to:
  /// **'Current: {email}'**
  String securityCurrentEmail(String email);

  /// No description provided for @newEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'New email'**
  String get newEmailLabel;

  /// No description provided for @updateEmailButton.
  ///
  /// In en, this message translates to:
  /// **'Update email'**
  String get updateEmailButton;

  /// No description provided for @updatingButton.
  ///
  /// In en, this message translates to:
  /// **'Updating...'**
  String get updatingButton;

  /// No description provided for @invalidEmailError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get invalidEmailError;

  /// No description provided for @sameEmailError.
  ///
  /// In en, this message translates to:
  /// **'That\'s already your current email.'**
  String get sameEmailError;

  /// No description provided for @emailUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Check your new email address for a confirmation link — the change takes effect once you click it.'**
  String get emailUpdateSuccess;

  /// No description provided for @updateEmailError.
  ///
  /// In en, this message translates to:
  /// **'Could not update email: {error}'**
  String updateEmailError(String error);

  /// No description provided for @securityPasswordSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get securityPasswordSectionTitle;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @confirmNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPasswordLabel;

  /// No description provided for @showPasswordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPasswordTooltip;

  /// No description provided for @hidePasswordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePasswordTooltip;

  /// No description provided for @updatePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get updatePasswordButton;

  /// No description provided for @passwordTooShortError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get passwordTooShortError;

  /// No description provided for @passwordMismatchError.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordMismatchError;

  /// No description provided for @passwordUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password updated.'**
  String get passwordUpdateSuccess;

  /// No description provided for @updatePasswordError.
  ///
  /// In en, this message translates to:
  /// **'Could not update password: {error}'**
  String updatePasswordError(String error);

  /// No description provided for @createGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a group'**
  String get createGroupTitle;

  /// No description provided for @createGroupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up a space to share events with a specific circle of people.'**
  String get createGroupSubtitle;

  /// No description provided for @howGroupsWorkTitle.
  ///
  /// In en, this message translates to:
  /// **'How groups work'**
  String get howGroupsWorkTitle;

  /// No description provided for @howGroupsWorkBody.
  ///
  /// In en, this message translates to:
  /// **'A group is like a group chat for a specific circle — your purok, an office, a league. Everyone who joins sees every \"Group\" event posted here, and only members see them. Once you create it, you get a 6-character code to share so others can join — and you can manage who\'s in it from the group\'s member list afterward.'**
  String get howGroupsWorkBody;

  /// No description provided for @groupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupNameLabel;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Purok 3 Updates'**
  String get groupNameHint;

  /// No description provided for @privateGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Private group'**
  String get privateGroupLabel;

  /// No description provided for @privateGroupHint.
  ///
  /// In en, this message translates to:
  /// **'Hidden from search — people need your code, and you approve who joins. Good for smaller or more sensitive groups.'**
  String get privateGroupHint;

  /// No description provided for @creatingButton.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get creatingButton;

  /// No description provided for @createGroupButton.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get createGroupButton;

  /// No description provided for @enterGroupNameError.
  ///
  /// In en, this message translates to:
  /// **'Enter a group name first.'**
  String get enterGroupNameError;

  /// No description provided for @createGroupError.
  ///
  /// In en, this message translates to:
  /// **'Could not create the group. Please try again.'**
  String get createGroupError;

  /// No description provided for @joinWithCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get joinWithCodeTitle;

  /// No description provided for @joinWithCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Have an invite code? Use it to join that group.'**
  String get joinWithCodeSubtitle;

  /// No description provided for @howJoiningWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'How joining works'**
  String get howJoiningWorksTitle;

  /// No description provided for @howJoiningWorksBody.
  ///
  /// In en, this message translates to:
  /// **'Ask whoever created the group for their 6-character code — it\'s shown right on the group\'s member page. Entering it here works for private groups too: instead of joining instantly, it sends a request the group\'s admin approves.'**
  String get howJoiningWorksBody;

  /// No description provided for @groupCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Group code'**
  String get groupCodeLabel;

  /// No description provided for @groupCodeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. QXK2P9'**
  String get groupCodeHint;

  /// No description provided for @joiningButton.
  ///
  /// In en, this message translates to:
  /// **'Joining...'**
  String get joiningButton;

  /// No description provided for @joinGroupButton.
  ///
  /// In en, this message translates to:
  /// **'Join group'**
  String get joinGroupButton;

  /// No description provided for @enterCodeError.
  ///
  /// In en, this message translates to:
  /// **'Enter a group code first.'**
  String get enterCodeError;

  /// No description provided for @joinGroupError.
  ///
  /// In en, this message translates to:
  /// **'Could not join. Check the code and try again.'**
  String get joinGroupError;

  /// No description provided for @couldNotLoadMembersError.
  ///
  /// In en, this message translates to:
  /// **'Could not load members. Please try again.'**
  String get couldNotLoadMembersError;

  /// No description provided for @promotedToAdminMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} is now an admin.'**
  String promotedToAdminMessage(String name);

  /// No description provided for @couldNotPromoteError.
  ///
  /// In en, this message translates to:
  /// **'Could not promote this member. Please try again.'**
  String get couldNotPromoteError;

  /// No description provided for @removeMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeMemberTitle(String name);

  /// No description provided for @removeMemberBody.
  ///
  /// In en, this message translates to:
  /// **'They will lose access to this group\'s events until they rejoin with the code.'**
  String get removeMemberBody;

  /// No description provided for @removeButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeButton;

  /// No description provided for @removedMemberMessage.
  ///
  /// In en, this message translates to:
  /// **'Removed {name}.'**
  String removedMemberMessage(String name);

  /// No description provided for @couldNotRemoveError.
  ///
  /// In en, this message translates to:
  /// **'Could not remove this member. Please try again.'**
  String get couldNotRemoveError;

  /// No description provided for @verifiedGroupMarked.
  ///
  /// In en, this message translates to:
  /// **'Marked as an official group.'**
  String get verifiedGroupMarked;

  /// No description provided for @verifiedGroupUnmarked.
  ///
  /// In en, this message translates to:
  /// **'Removed the official mark.'**
  String get verifiedGroupUnmarked;

  /// No description provided for @couldNotUpdateGroupError.
  ///
  /// In en, this message translates to:
  /// **'Could not update this group. Please try again.'**
  String get couldNotUpdateGroupError;

  /// No description provided for @noOtherMembersError.
  ///
  /// In en, this message translates to:
  /// **'No other members to transfer ownership to.'**
  String get noOtherMembersError;

  /// No description provided for @transferOwnershipToTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership to...'**
  String get transferOwnershipToTitle;

  /// No description provided for @makeOwnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Make {name} the owner?'**
  String makeOwnerTitle(String name);

  /// No description provided for @makeOwnerBody.
  ///
  /// In en, this message translates to:
  /// **'They will be able to delete this group and remove fellow admins — privileges only the owner has. This cannot be undone by you afterward.'**
  String get makeOwnerBody;

  /// No description provided for @transferButton.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferButton;

  /// No description provided for @ownershipTransferredMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} is now the owner.'**
  String ownershipTransferredMessage(String name);

  /// No description provided for @couldNotTransferError.
  ///
  /// In en, this message translates to:
  /// **'Could not transfer ownership. Please try again.'**
  String get couldNotTransferError;

  /// No description provided for @copyCodeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCodeTooltip;

  /// No description provided for @codeCopiedMessage.
  ///
  /// In en, this message translates to:
  /// **'Code {code} copied.'**
  String codeCopiedMessage(String code);

  /// No description provided for @verifiedOfficialGroup.
  ///
  /// In en, this message translates to:
  /// **'Verified official group'**
  String get verifiedOfficialGroup;

  /// No description provided for @notVerified.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get notVerified;

  /// No description provided for @removeMarkButton.
  ///
  /// In en, this message translates to:
  /// **'Remove mark'**
  String get removeMarkButton;

  /// No description provided for @markAsOfficialButton.
  ///
  /// In en, this message translates to:
  /// **'Mark as official'**
  String get markAsOfficialButton;

  /// No description provided for @staffTurnoverHint.
  ///
  /// In en, this message translates to:
  /// **'Staff turnover? Hand this group\'s owner-only privileges to another member.'**
  String get staffTurnoverHint;

  /// No description provided for @transferOwnershipButton.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership'**
  String get transferOwnershipButton;

  /// No description provided for @invitePeopleTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite people'**
  String get invitePeopleTitle;

  /// No description provided for @invitePeopleBody.
  ///
  /// In en, this message translates to:
  /// **'There\'s no user directory to add people from directly — share this code instead. Anyone who enters it {action}.'**
  String invitePeopleBody(String action);

  /// No description provided for @joinsInstantlyAction.
  ///
  /// In en, this message translates to:
  /// **'joins instantly'**
  String get joinsInstantlyAction;

  /// No description provided for @sendsJoinRequestAction.
  ///
  /// In en, this message translates to:
  /// **'sends a request you approve'**
  String get sendsJoinRequestAction;

  /// No description provided for @searchMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'Search members'**
  String get searchMembersLabel;

  /// No description provided for @searchMembersHint.
  ///
  /// In en, this message translates to:
  /// **'Type a name'**
  String get searchMembersHint;

  /// No description provided for @membersHeader.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersHeader;

  /// No description provided for @noMembersYet.
  ///
  /// In en, this message translates to:
  /// **'No members yet.'**
  String get noMembersYet;

  /// No description provided for @noMembersMatch.
  ///
  /// In en, this message translates to:
  /// **'No members match \"{query}\".'**
  String noMembersMatch(String query);

  /// No description provided for @adminBadge.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminBadge;

  /// No description provided for @joinedDatePrefix.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String joinedDatePrefix(String date);

  /// No description provided for @promoteToAdminMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Promote to admin'**
  String get promoteToAdminMenuItem;

  /// No description provided for @removeFromGroupMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get removeFromGroupMenuItem;

  /// No description provided for @memberYouSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (You)'**
  String memberYouSuffix(String name);

  /// No description provided for @aboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version info and what\'s new.'**
  String get aboutSubtitle;

  /// No description provided for @shareAppSection.
  ///
  /// In en, this message translates to:
  /// **'Share app'**
  String get shareAppSection;

  /// No description provided for @shareAppHint.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code or share the link so others can install eBongabong Calendar.'**
  String get shareAppHint;

  /// No description provided for @shareDownloadLinkButton.
  ///
  /// In en, this message translates to:
  /// **'Share download link'**
  String get shareDownloadLinkButton;

  /// No description provided for @updatesSection.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updatesSection;

  /// No description provided for @updateCheckingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Update checking isn\'t available on this build.'**
  String get updateCheckingUnavailable;

  /// No description provided for @versionAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available.'**
  String versionAvailable(String version);

  /// No description provided for @updateNowButton.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNowButton;

  /// No description provided for @upToDateMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date.'**
  String get upToDateMessage;

  /// No description provided for @checkForUpdatesButton.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdatesButton;

  /// No description provided for @checkUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates right now.'**
  String get checkUpdateError;

  /// No description provided for @openUpdateLinkError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the update link.'**
  String get openUpdateLinkError;

  /// No description provided for @loadingVersion.
  ///
  /// In en, this message translates to:
  /// **'Loading version…'**
  String get loadingVersion;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @whatsNewInVersion.
  ///
  /// In en, this message translates to:
  /// **'What\'s new in {version}'**
  String whatsNewInVersion(String version);

  /// No description provided for @profilePictureTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile Picture'**
  String get profilePictureTitle;

  /// No description provided for @profilePictureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick one — it saves right away.'**
  String get profilePictureSubtitle;

  /// No description provided for @couldNotSaveAvatarError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your profile picture. Please try again.'**
  String get couldNotSaveAvatarError;

  /// No description provided for @avatarCategoryAnime.
  ///
  /// In en, this message translates to:
  /// **'Anime'**
  String get avatarCategoryAnime;

  /// No description provided for @avatarCategoryAnimal.
  ///
  /// In en, this message translates to:
  /// **'Animal'**
  String get avatarCategoryAnimal;

  /// No description provided for @avatarCategoryPerson.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get avatarCategoryPerson;
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

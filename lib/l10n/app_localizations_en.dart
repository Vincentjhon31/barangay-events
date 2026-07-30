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
  String get continueAsGuestButton => 'Continue as Guest';

  @override
  String get registerOrLoginButton => 'or Register / Login';

  @override
  String get guestRegisterLoginButton => 'Register / Login';

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
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsHint =>
      'Get a reminder before an event you can see is about to start.';

  @override
  String get settingsReminderOff => 'Off';

  @override
  String get settingsReminderOneHour => '1 hour before';

  @override
  String get settingsReminderOneDay => '1 day before';

  @override
  String get eventReminderNoticeLabel => 'Event reminder';

  @override
  String get eventReminderGenericTitle =>
      'An event you\'re following is coming up soon';

  @override
  String get calendarViewMonth => 'Month';

  @override
  String get calendarViewWeek => 'Week';

  @override
  String get calendarViewList => 'List';

  @override
  String get calendarViewFull => 'Day';

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
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0 • code $code';
  }

  @override
  String memberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String get joinedButton => 'Joined';

  @override
  String get joinButton => 'Join';

  @override
  String get eventTypeAll => 'All';

  @override
  String get eventTypePublic => 'Public';

  @override
  String get eventTypeGroup => 'Group';

  @override
  String get eventTypePersonal => 'Personal';

  @override
  String get eventColorLabel => 'Color label';

  @override
  String get groupFilterPickerTitle => 'Filter groups';

  @override
  String get groupFilterPickerSubtitle =>
      'Choose which of your groups\' events show up as Group events.';

  @override
  String get groupFilterPickerApply => 'Apply';

  @override
  String get eventDetailsTitle => 'Event Details';

  @override
  String get shareEvent => 'Share event';

  @override
  String get detailTime => 'Time';

  @override
  String get detailLocation => 'Location';

  @override
  String get detailPostedBy => 'Posted by';

  @override
  String postedByPrefix(String name) {
    return 'By $name';
  }

  @override
  String get detailDescription => 'Description';

  @override
  String get detailAttachment => 'Attachment';

  @override
  String get attachmentAvailable => 'Attachment available';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get editEventMenuItem => 'Edit event';

  @override
  String get deleteEventMenuItem => 'Delete event';

  @override
  String get groupEventFallbackName => 'Group event';

  @override
  String get loadingMembers => 'Loading members…';

  @override
  String get fileTypePdf => 'PDF Document';

  @override
  String get fileTypeImage => 'Image';

  @override
  String get fileTypeVideo => 'Video';

  @override
  String get fileTypeWord => 'Word Document';

  @override
  String get fileTypeSpreadsheet => 'Spreadsheet';

  @override
  String addedEventToGroup(String title, String groupName) {
    return 'Added \"$title\" to $groupName.';
  }

  @override
  String addedEventToCalendar(String title) {
    return 'Added \"$title\" to the calendar.';
  }

  @override
  String get editEventTitle => 'Edit Event';

  @override
  String get addEventTitle => 'Add Event';

  @override
  String get editEventSubtitle => 'Update the details for this event.';

  @override
  String get addEventSubtitle => 'Share something happening in the barangay.';

  @override
  String get typeHelperGroup =>
      'Only members of the group you pick can see this.';

  @override
  String get typeHelperPersonal => 'Only you can see this.';

  @override
  String get typeHelperPublic => 'Everyone in the app can see this.';

  @override
  String get typeHelperRestrictedSuffix =>
      'Only verified LGU members can post Group events, and only the admin can post Public events.';

  @override
  String get personalEventLabel => 'Personal event';

  @override
  String get noGroupsYetError =>
      'You have no groups yet — create one in the Groups tab first.';

  @override
  String get postToGroupLabel => 'Post to group';

  @override
  String get eventTitleLabel => 'Event title';

  @override
  String get eventTitleHint => 'e.g. Barangay Assembly';

  @override
  String get locationHint => 'e.g. Barangay Hall';

  @override
  String get additionalDetailsLabel => 'Additional Details (optional)';

  @override
  String get additionalDetailsHint => 'Add a short note for residents';

  @override
  String get multiDayEventLabel => 'Multi-day event';

  @override
  String get multiDayEventHint =>
      'Spans more than one day, e.g. a 3-day fiesta.';

  @override
  String get startDateLabel => 'Start date';

  @override
  String get endDateLabel => 'End date';

  @override
  String get dateLabel => 'Date';

  @override
  String get defaultStartTimeLabel => 'Default start time';

  @override
  String get startTimeLabel => 'Start time';

  @override
  String get defaultEndTimeLabel => 'Default end time';

  @override
  String get endTimeLabel => 'End time';

  @override
  String get changeButton => 'Change';

  @override
  String get overlapsWithOne => 'Overlaps with an existing event:';

  @override
  String overlapsWithMany(int count) {
    return 'Overlaps with $count existing events:';
  }

  @override
  String get adjustOverlapHint =>
      'Adjust the time or date range to clear the overlap.';

  @override
  String get noFreeSlotHint => 'No free slot left that day — try another date.';

  @override
  String freeSlotSuggestion(String start, String end) {
    return 'Free slot: $start – $end · Tap to use';
  }

  @override
  String get overlapDialogTitleOne => 'This overlaps with an existing event';

  @override
  String overlapDialogTitleMany(int count) {
    return 'This overlaps with $count existing events';
  }

  @override
  String get overlapDialogBody =>
      'You can still save it, but people may see two events scheduled at the same time:';

  @override
  String get proceedAnyway => 'Proceed anyway';

  @override
  String get savingButton => 'Saving...';

  @override
  String get saveChangesButton => 'Save changes';

  @override
  String get saveEventButton => 'Save event';

  @override
  String get titleLocationRequired => 'Title and location are required.';

  @override
  String get pastDateError => 'Events can\'t be added on a past date.';

  @override
  String get endAfterStartMultiDay => 'End must be after start.';

  @override
  String get endAfterStartSingleDay => 'End time must be after start time.';

  @override
  String get pickGroupError =>
      'Pick a group for this event — create or join one in the Groups tab.';

  @override
  String saveEventError(String error) {
    return 'Could not save the event: $error';
  }

  @override
  String get perDayScheduleTitle => 'Per-day schedule';

  @override
  String get perDayScheduleHint =>
      'Every day uses the default time above unless you customize it — e.g. a full day on day 1, just a few hours on day 2.';

  @override
  String defaultTimeRangeSuffix(String start, String end) {
    return '$start – $end (default)';
  }

  @override
  String timeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get resetButton => 'Reset';

  @override
  String get allDayButton => 'All day';

  @override
  String get customizeButton => 'Customize';

  @override
  String get securityTile => 'Security';

  @override
  String get securityTileCaption => 'Change your email and password';

  @override
  String get securityTitle => 'Security';

  @override
  String get securitySubtitle => 'Manage your sign-in email and password.';

  @override
  String get securityEmailSectionTitle => 'Email';

  @override
  String securityCurrentEmail(String email) {
    return 'Current: $email';
  }

  @override
  String get newEmailLabel => 'New email';

  @override
  String get updateEmailButton => 'Update email';

  @override
  String get updatingButton => 'Updating...';

  @override
  String get invalidEmailError => 'Enter a valid email address.';

  @override
  String get sameEmailError => 'That\'s already your current email.';

  @override
  String get emailUpdateSuccess =>
      'Check your new email address for a confirmation link — the change takes effect once you click it.';

  @override
  String updateEmailError(String error) {
    return 'Could not update email: $error';
  }

  @override
  String get securityPasswordSectionTitle => 'Password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmNewPasswordLabel => 'Confirm new password';

  @override
  String get showPasswordTooltip => 'Show password';

  @override
  String get hidePasswordTooltip => 'Hide password';

  @override
  String get updatePasswordButton => 'Update password';

  @override
  String get passwordTooShortError => 'Password must be at least 6 characters.';

  @override
  String get passwordMismatchError => 'Passwords do not match.';

  @override
  String get passwordUpdateSuccess => 'Password updated.';

  @override
  String updatePasswordError(String error) {
    return 'Could not update password: $error';
  }

  @override
  String get createGroupTitle => 'Create a group';

  @override
  String get createGroupSubtitle =>
      'Set up a space to share events with a specific circle of people.';

  @override
  String get howGroupsWorkTitle => 'How groups work';

  @override
  String get howGroupsWorkBody =>
      'A group is like a group chat for a specific circle — your purok, an office, a league. Everyone who joins sees every \"Group\" event posted here, and only members see them. Once you create it, you get a 6-character code to share so others can join — and you can manage who\'s in it from the group\'s member list afterward.';

  @override
  String get groupNameLabel => 'Group name';

  @override
  String get groupNameHint => 'e.g. Purok 3 Updates';

  @override
  String get privateGroupLabel => 'Private group';

  @override
  String get privateGroupHint =>
      'Hidden from search — people need your code, and you approve who joins. Good for smaller or more sensitive groups.';

  @override
  String get creatingButton => 'Creating...';

  @override
  String get createGroupButton => 'Create group';

  @override
  String get enterGroupNameError => 'Enter a group name first.';

  @override
  String get createGroupError =>
      'Could not create the group. Please try again.';

  @override
  String get joinWithCodeTitle => 'Join with a code';

  @override
  String get joinWithCodeSubtitle =>
      'Have an invite code? Use it to join that group.';

  @override
  String get howJoiningWorksTitle => 'How joining works';

  @override
  String get howJoiningWorksBody =>
      'Ask whoever created the group for their 6-character code — it\'s shown right on the group\'s member page. Entering it here works for private groups too: instead of joining instantly, it sends a request the group\'s admin approves.';

  @override
  String get groupCodeLabel => 'Group code';

  @override
  String get groupCodeHint => 'e.g. QXK2P9';

  @override
  String get joiningButton => 'Joining...';

  @override
  String get joinGroupButton => 'Join group';

  @override
  String get enterCodeError => 'Enter a group code first.';

  @override
  String get joinGroupError => 'Could not join. Check the code and try again.';

  @override
  String get couldNotLoadMembersError =>
      'Could not load members. Please try again.';

  @override
  String promotedToAdminMessage(String name) {
    return '$name is now an admin.';
  }

  @override
  String get couldNotPromoteError =>
      'Could not promote this member. Please try again.';

  @override
  String removeMemberTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get removeMemberBody =>
      'They will lose access to this group\'s events until they rejoin with the code.';

  @override
  String get removeButton => 'Remove';

  @override
  String removedMemberMessage(String name) {
    return 'Removed $name.';
  }

  @override
  String get couldNotRemoveError =>
      'Could not remove this member. Please try again.';

  @override
  String get verifiedGroupMarked => 'Marked as an official group.';

  @override
  String get verifiedGroupUnmarked => 'Removed the official mark.';

  @override
  String get couldNotUpdateGroupError =>
      'Could not update this group. Please try again.';

  @override
  String get noOtherMembersError =>
      'No other members to transfer ownership to.';

  @override
  String get transferOwnershipToTitle => 'Transfer ownership to...';

  @override
  String makeOwnerTitle(String name) {
    return 'Make $name the owner?';
  }

  @override
  String get makeOwnerBody =>
      'They will be able to delete this group and remove fellow admins — privileges only the owner has. This cannot be undone by you afterward.';

  @override
  String get transferButton => 'Transfer';

  @override
  String ownershipTransferredMessage(String name) {
    return '$name is now the owner.';
  }

  @override
  String get couldNotTransferError =>
      'Could not transfer ownership. Please try again.';

  @override
  String get copyCodeTooltip => 'Copy code';

  @override
  String codeCopiedMessage(String code) {
    return 'Code $code copied.';
  }

  @override
  String get verifiedOfficialGroup => 'Verified official group';

  @override
  String get notVerified => 'Not verified';

  @override
  String get removeMarkButton => 'Remove mark';

  @override
  String get markAsOfficialButton => 'Mark as official';

  @override
  String get staffTurnoverHint =>
      'Staff turnover? Hand this group\'s owner-only privileges to another member.';

  @override
  String get transferOwnershipButton => 'Transfer ownership';

  @override
  String get invitePeopleTitle => 'Invite people';

  @override
  String invitePeopleBody(String action) {
    return 'There\'s no user directory to add people from directly — share this code instead. Anyone who enters it $action.';
  }

  @override
  String get joinsInstantlyAction => 'joins instantly';

  @override
  String get sendsJoinRequestAction => 'sends a request you approve';

  @override
  String get searchMembersLabel => 'Search members';

  @override
  String get searchMembersHint => 'Type a name';

  @override
  String get membersHeader => 'Members';

  @override
  String get noMembersYet => 'No members yet.';

  @override
  String noMembersMatch(String query) {
    return 'No members match \"$query\".';
  }

  @override
  String get adminBadge => 'Admin';

  @override
  String joinedDatePrefix(String date) {
    return 'Joined $date';
  }

  @override
  String get promoteToAdminMenuItem => 'Promote to admin';

  @override
  String get removeFromGroupMenuItem => 'Remove from group';

  @override
  String memberYouSuffix(String name) {
    return '$name (You)';
  }

  @override
  String get aboutSubtitle => 'Version info and what\'s new.';

  @override
  String get shareAppSection => 'Share app';

  @override
  String get shareAppHint =>
      'Scan the QR code or share the link so others can install eBongabong Calendar.';

  @override
  String get shareDownloadLinkButton => 'Share download link';

  @override
  String get updatesSection => 'Updates';

  @override
  String get updateCheckingUnavailable =>
      'Update checking isn\'t available on this build.';

  @override
  String versionAvailable(String version) {
    return 'Version $version is available.';
  }

  @override
  String get updateNowButton => 'Update now';

  @override
  String get upToDateMessage => 'You\'re up to date.';

  @override
  String get checkForUpdatesButton => 'Check for updates';

  @override
  String get checkUpdateError => 'Could not check for updates right now.';

  @override
  String get openUpdateLinkError => 'Could not open the update link.';

  @override
  String get loadingVersion => 'Loading version…';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String whatsNewInVersion(String version) {
    return 'What\'s new in $version';
  }

  @override
  String get profilePictureTitle => 'Profile Picture';

  @override
  String get profilePictureSubtitle => 'Pick one — it saves right away.';

  @override
  String get couldNotSaveAvatarError =>
      'Could not save your profile picture. Please try again.';

  @override
  String get avatarCategoryAnime => 'Anime';

  @override
  String get avatarCategoryAnimal => 'Animal';

  @override
  String get avatarCategoryPerson => 'Person';

  @override
  String get requiresApprovalLabel => 'Require approval to join';

  @override
  String get requiresApprovalHint =>
      'New members must be accepted by an admin before they can see this group\'s events.';

  @override
  String get joinPolicyOpen => 'Anyone with access can join instantly';

  @override
  String get joinPolicyApprovalRequired => 'New members need approval';

  @override
  String get requireApprovalButton => 'Require approval';

  @override
  String get allowInstantJoinButton => 'Allow instant join';

  @override
  String get requireApprovalEnabledMessage =>
      'New members must now be approved to join.';

  @override
  String get requireApprovalDisabledMessage => 'Anyone can now join instantly.';

  @override
  String get couldNotUpdateJoinSettingError =>
      'Could not update this group\'s join settings. Please try again.';

  @override
  String get requestToJoinButton => 'Request to join';

  @override
  String get approvalRequiredTag => 'Approval required';

  @override
  String joinedGroupMessage(String name) {
    return 'You joined \"$name\".';
  }

  @override
  String joinRequestSentMessage(String name) {
    return 'Request sent — waiting for \"$name\" to approve you.';
  }

  @override
  String alreadyInGroupMessage(String name) {
    return 'You\'re already in \"$name\".';
  }

  @override
  String groupCreatedApprovalMessage(String name, String code) {
    return 'Created \"$name\". Code $code lets people request to join — you approve who gets in.';
  }

  @override
  String groupCreatedOpenMessage(String name, String code) {
    return 'Created \"$name\". Share code $code so others can join instantly.';
  }

  @override
  String get groupCreatedPrivateNote =>
      'It won\'t show up in search — only people with the code can find it.';

  @override
  String get couldNotJoinGroupError =>
      'Could not join the group. Please try again.';

  @override
  String get onlyLguCanCreateGroupError =>
      'Only verified LGU members can create a group. You can still join one by searching its name or entering a code.';

  @override
  String get deleteGroupButton => 'Delete group';

  @override
  String get deleteGroupHint =>
      'Permanently delete this group and remove all its members. Events already posted here stay, but lose their group association.';

  @override
  String deleteGroupConfirmTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteGroupConfirmBody =>
      'This permanently deletes the group and removes all its members. Events already posted here stay, but lose their group association. This cannot be undone.';

  @override
  String get couldNotDeleteGroupError =>
      'Could not delete the group. Please try again.';

  @override
  String groupDeletedMessage(String name) {
    return '\"$name\" was deleted.';
  }

  @override
  String get enableKioskModeButton => 'Enable Kiosk Mode';

  @override
  String get exitKioskModeButton => 'Exit Kiosk Mode';

  @override
  String get kioskExitPasscodeTitle => 'Enter Passcode';

  @override
  String get kioskExitPasscodeSubtitle =>
      'Enter the 4-digit passcode to exit Kiosk Mode.';

  @override
  String get kioskExitPasscodeWrong => 'Incorrect passcode. Try again.';

  @override
  String get kioskPasscodeSectionTitle => 'Kiosk Passcode';

  @override
  String get kioskPasscodeSectionSubtitle =>
      'Used to exit Kiosk Mode on this account\'s devices.';

  @override
  String get kioskPasscodeCurrentLabel => 'Current passcode';

  @override
  String get kioskPasscodeNewLabel => 'New passcode';

  @override
  String get kioskPasscodeConfirmLabel => 'Confirm new passcode';

  @override
  String get kioskPasscodeUpdateButton => 'Update Passcode';

  @override
  String get kioskPasscodeMismatch => 'Passcodes do not match.';

  @override
  String get kioskPasscodeInvalidLength => 'Passcode must be exactly 4 digits.';

  @override
  String get kioskPasscodeUpdateSuccess => 'Passcode updated.';

  @override
  String get aboutThisAppSection => 'About This App';

  @override
  String get aboutThisAppBody =>
      'eBongabong Calendar is the official community events app of the Municipality of Bongabong, Philippines — built to keep residents informed about barangay activities, government announcements, and community gatherings, all in one place.';

  @override
  String get aboutThisAppFeaturesIntro => 'With eBongabong Calendar, you can:';

  @override
  String get aboutFeaturePublicEvents =>
      'See public announcements and events posted by the LGU';

  @override
  String get aboutFeatureGroups =>
      'Join groups for your barangay, office, or organization to see events shared just with that circle';

  @override
  String get aboutFeaturePersonal =>
      'Keep personal reminders and notes only you can see';

  @override
  String get aboutFeatureNotifications =>
      'Get notified the moment a new event is posted, and set a reminder before it starts';

  @override
  String get aboutFeatureLanguage =>
      'Switch between English and Filipino anytime';

  @override
  String get aboutFeatureDisplay =>
      'Adjust the display size for phones, tablets, or a public kiosk screen';

  @override
  String get faqTile => 'Frequently Asked Questions';

  @override
  String get faqTileCaption => 'Common questions about using the app';

  @override
  String get faqPageTitle => 'Frequently Asked Questions';

  @override
  String get faqPageSubtitle =>
      'Answers to common questions about eBongabong Calendar. Tap a question to expand it.';

  @override
  String get faqQ1 =>
      'What\'s the difference between Public, Group, and Personal events?';

  @override
  String get faqA1 =>
      'Public events are official barangay-wide announcements posted only by the superadmin — everyone using the app can see them. Group events are shared just with the members of a specific group, like your barangay office or a club — only members see them. Personal events are private notes only you can see, for your own reminders.';

  @override
  String get faqQ2 => 'How do I join a group?';

  @override
  String get faqA2 =>
      'From the Groups tab, tap the search icon to browse public groups, or enter a 6-character invite code if you have one. Public groups let you join instantly, or send a request if the group requires approval; private groups always require the code.';

  @override
  String get faqQ3 => 'How do I create a group?';

  @override
  String get faqA3 =>
      'Group creation is limited to verified LGU members and the superadmin. If you\'re a citizen, ask your barangay office or the superadmin about applying for LGU access from the Groups tab.';

  @override
  String get faqQ4 => 'Why can\'t I post a Public event?';

  @override
  String get faqA4 =>
      'Public events reach the entire community, so only the superadmin can post them — this keeps official barangay-wide announcements from getting lost among community events. LGU members can still post Group events to their own group\'s members.';

  @override
  String get faqQ5 => 'How do event reminders work?';

  @override
  String get faqA5 =>
      'In Settings, under Notifications, choose when you\'d like to be reminded — 1 hour or 1 day before an event starts. You\'ll get a notification for every event you can already see: public events, your groups\' events, and your own personal events.';

  @override
  String get faqQ6 => 'How do I switch the app to Filipino?';

  @override
  String get faqA6 =>
      'Open Settings and tap Language, then choose Filipino or English. It takes effect immediately and is remembered on every device you sign in on.';

  @override
  String get faqQ7 => 'What is Kiosk Mode?';

  @override
  String get faqA7 =>
      'Kiosk Mode turns the app into a full-screen, read-only calendar display — no menu, no Add Event button — meant for an unattended public screen, like one at the barangay hall. Only an account the superadmin has designated as a kiosk account can turn it on, from a button at the top of the Calendar tab.';

  @override
  String get faqQ8 => 'How do I become a verified LGU member?';

  @override
  String get faqA8 =>
      'From the Groups tab or the LGU admin portal, submit an application with your office or department. A superadmin will review and approve it — once approved, you can create groups and post Group events.';

  @override
  String get faqQ9 => 'Is my information private?';

  @override
  String get faqA9 =>
      'Your profile is only visible to you unless you choose to share it, such as by joining a group. See the Privacy Policy in Settings for full details on what\'s collected and how it\'s used.';

  @override
  String get privacyPolicyTile => 'Privacy Policy';

  @override
  String get privacyPolicyTileCaption => 'What we collect and how it\'s used';

  @override
  String get privacyPolicyTitle => 'Privacy Policy';

  @override
  String get privacyPolicySubtitle =>
      'How eBongabong Calendar handles your information.';

  @override
  String get privacyIntro =>
      'This Privacy Policy explains what information eBongabong Calendar collects, how it\'s used, and who can see it. It applies to everyone who uses the app, whether you\'re a resident, an LGU member, or a superadmin.';

  @override
  String get privacyCollectHeading => 'Information We Collect';

  @override
  String get privacyCollectBody =>
      'When you create an account, we collect your email address and the details you choose to add to your profile — display name, department, phone number, address, a short bio, and a profile picture chosen from a fixed set of avatars (the app never accesses your camera or photo library). We also store the events, groups, and preferences (language, theme, display size, reminders) you set up while using the app.';

  @override
  String get privacyUseHeading => 'How We Use Your Information';

  @override
  String get privacyUseBody =>
      'Your information is used only to run the app\'s own features: showing you relevant events, letting you join and manage groups, remembering your display and language preferences across devices, and sending the notifications you\'ve asked for. We don\'t use your information for advertising, and we don\'t sell it to anyone.';

  @override
  String get privacyVisibilityHeading => 'Who Can See Your Information';

  @override
  String get privacyVisibilityBody =>
      'Your profile details are visible only to you. If you join a group, that group\'s other members can see your display name and profile picture in the member list. Events follow their own visibility: Public events are visible to everyone, Group events only to that group\'s members, and Personal events only to you.';

  @override
  String get privacyThirdPartyHeading => 'Third-Party Services';

  @override
  String get privacyThirdPartyBody =>
      'The app is built on Supabase, which hosts our database and handles sign-in, and Firebase Cloud Messaging, which delivers push notifications on Android. Both encrypt data in transit, and Supabase encrypts data at rest. These providers process data only to help the app function — they don\'t have their own separate use for it.';

  @override
  String get privacyRetentionHeading => 'Your Choices';

  @override
  String get privacyRetentionBody =>
      'You can edit or remove most of your profile details, delete events and groups you created, and change your notification and language preferences at any time from within the app. To request deletion of your account entirely, contact your barangay office or the municipality\'s LGU admin team.';

  @override
  String get privacyChildrenHeading => 'Children\'s Privacy';

  @override
  String get privacyChildrenBody =>
      'eBongabong Calendar is intended for general community use and isn\'t specifically directed at children. If you believe a child has provided personal information without appropriate consent, please contact your barangay office so it can be removed.';

  @override
  String get privacyChangesHeading => 'Changes to This Policy';

  @override
  String get privacyChangesBody =>
      'If this policy changes, the update will be reflected here with a new effective date. Continuing to use the app after a change means you accept the updated policy.';

  @override
  String get privacyLegalHeading => 'Compliance';

  @override
  String get privacyLegalBody =>
      'This app is operated by the Municipality of Bongabong in line with the Data Privacy Act of 2012 (Republic Act No. 10173). For questions about your data, contact your barangay office or the municipality\'s LGU admin team.';
}

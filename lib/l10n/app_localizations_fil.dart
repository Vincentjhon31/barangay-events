// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Filipino Pilipino (`fil`).
class AppLocalizationsFil extends AppLocalizations {
  AppLocalizationsFil([String locale = 'fil']) : super(locale);

  @override
  String get appTagline => 'Mga kaganapan sa komunidad, makikita agad.';

  @override
  String get loginTitle => 'Mag-login';

  @override
  String get signUpTitle => 'Gumawa ng Account';

  @override
  String get authSubtitle =>
      'Gamitin ang iyong account para makita at makapag-post ng mga kaganapan sa barangay.';

  @override
  String get nameLabel => 'Pangalan';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPasswordLabel => 'Kumpirmahin ang Password';

  @override
  String get pleaseWait => 'Sandali lang...';

  @override
  String get createAccountButton => 'Gumawa ng Account';

  @override
  String get loginButton => 'Mag-login';

  @override
  String get haveAccountPrompt => 'May account ka na? Mag-login';

  @override
  String get needAccountPrompt => 'Wala ka pang account? Gumawa ng isa';

  @override
  String get continueAsGuestButton => 'Magpatuloy bilang Guest';

  @override
  String get registerOrLoginButton => 'o Mag-register / Mag-login';

  @override
  String get guestRegisterLoginButton => 'Mag-register / Mag-login';

  @override
  String get authEmailPasswordRequired => 'Kailangan ang email at password.';

  @override
  String get authNameRequired => 'Kailangan ang pangalan.';

  @override
  String get authPasswordTooShort =>
      'Dapat hindi bababa sa 6 na karakter ang password.';

  @override
  String get authPasswordsDontMatch => 'Hindi magkatugma ang mga password.';

  @override
  String get authAccountCreated =>
      'Nagawa na ang account. Maaaring kailangan mong kumpirmahin ang iyong email bago mag-login.';

  @override
  String get authFailedGeneric => 'Nabigo ang pag-verify.';

  @override
  String get tabCalendar => 'Kalendaryo';

  @override
  String get tabFeed => 'Mga Balita';

  @override
  String get tabGroups => 'Mga Grupo';

  @override
  String get tabProfile => 'Profile';

  @override
  String get cancel => 'Kanselahin';

  @override
  String get delete => 'Burahin';

  @override
  String get save => 'I-save';

  @override
  String get edit => 'I-edit';

  @override
  String get settingsTitle => 'Mga Setting';

  @override
  String get settingsSubtitle => 'I-personalize kung paano magmukha ang app.';

  @override
  String get settingsAppearance => 'Itsura';

  @override
  String get settingsSystemDefault => 'Default ng System';

  @override
  String get settingsLight => 'Maliwanag';

  @override
  String get settingsDark => 'Madilim';

  @override
  String get settingsAppStyle => 'Estilo ng App';

  @override
  String get settingsLiquidGlass => 'Liquid Glass';

  @override
  String get settingsLiquidGlassSubtitle =>
      'Malinaw na mga panel at nagniningning na mga kulay';

  @override
  String get settingsSolid => 'Solid';

  @override
  String get settingsSolidSubtitle =>
      'Payak na mga kulay — mas mabilis sa karamihan ng telepono';

  @override
  String get settingsDisplaySize => 'Sukat ng Display';

  @override
  String get settingsDisplaySizeHint =>
      'Awtomatikong iaangkop ng Auto ang sukat sa screen — pumili ng nakapirming sukat kung kailangan itong ma-lock sa device na ito (hal. isang kiosk display).';

  @override
  String get settingsDisplayAuto => 'Awtomatikong iaangkop sa screen';

  @override
  String get settingsDisplayMobile => 'Compact, walang scaling';

  @override
  String get settingsDisplayTablet => 'Katamtaman — mga 1.5x';

  @override
  String get settingsDisplayWindows =>
      'Malaki — mga 2x, para sa mga kiosk display';

  @override
  String get settingsLanguage => 'Wika';

  @override
  String get settingsLanguageHint =>
      'Palitan ang wika ng app. Agad itong magkakabisa.';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFilipino => 'Filipino';

  @override
  String get settingsNotifications => 'Mga Paalala';

  @override
  String get settingsNotificationsHint =>
      'Tumanggap ng paalala bago magsimula ang isang event na makikita mo.';

  @override
  String get settingsReminderOff => 'Naka-off';

  @override
  String get settingsReminderOneHour => '1 oras bago';

  @override
  String get settingsReminderOneDay => '1 araw bago';

  @override
  String get eventReminderNoticeLabel => 'Paalala sa event';

  @override
  String get eventReminderGenericTitle =>
      'Malapit nang mangyari ang isang event na sinusundan mo';

  @override
  String get calendarViewMonth => 'Buwan';

  @override
  String get calendarViewWeek => 'Linggo';

  @override
  String get calendarViewList => 'Listahan';

  @override
  String get calendarViewFull => 'Araw';

  @override
  String get addEventButton => 'Magdagdag ng Kaganapan';

  @override
  String get upcomingHeader => 'Paparating';

  @override
  String eventsForDate(String date) {
    return 'Mga kaganapan para sa $date';
  }

  @override
  String noEventsForDate(String date) {
    return 'Walang kaganapan para sa $date';
  }

  @override
  String get nothingTodayFallback =>
      'Walang kaganapan ngayon — narito ang mga paparating:';

  @override
  String get calendarSearchLabel => 'Maghanap ng kaganapan';

  @override
  String get calendarSearchHint => 'Pamagat, lokasyon, o sino ang nag-post';

  @override
  String get deleteEventTitle => 'Burahin ang Kaganapan';

  @override
  String deleteEventConfirm(String title) {
    return 'Buburahin ang \"$title\"? Hindi na ito maibabalik.';
  }

  @override
  String get feedTitle => 'Mga Balita';

  @override
  String get feedSubtitle =>
      'Mga bagong kaganapan mula sa mga sinusundan mo at sa komunidad.';

  @override
  String get feedSearchLabel => 'Maghanap sa Balita';

  @override
  String get feedSearchHint => 'Pamagat, lokasyon, o sino ang nag-post';

  @override
  String get clearSearch => 'I-clear ang paghahanap';

  @override
  String get feedEmptyFiltered =>
      'Walang post na tumugma sa iyong paghahanap o filter.';

  @override
  String get feedEmpty =>
      'Wala pang laman dito. Sumali sa mga grupo mula sa tab na Mga Grupo para makita ang kanilang mga kaganapan, o bumalik para sa mga pampublikong anunsyo.';

  @override
  String get previousPage => 'Nakaraang pahina';

  @override
  String get nextPage => 'Susunod na pahina';

  @override
  String pageOfTotal(int current, int total) {
    return 'Pahina $current ng $total';
  }

  @override
  String get groupsTitle => 'Mga Grupo';

  @override
  String get groupsSubtitle =>
      'Parang group chat, pero para sa mga kaganapang dapat makita ng lahat.';

  @override
  String get searchGroups => 'Maghanap ng grupo';

  @override
  String get closeSearch => 'Isara ang paghahanap';

  @override
  String get groupsCreateTile => 'Gumawa';

  @override
  String get groupsCreateCaption => 'Magsimula ng bagong grupo';

  @override
  String get groupsCreateLguOnly => 'Para lang sa miyembro ng LGU';

  @override
  String get groupsJoinTile => 'Sumali gamit ang code';

  @override
  String get groupsJoinCaption => 'Gumamit ng invite code';

  @override
  String myGroupsHeader(int count) {
    return 'Aking mga Grupo ($count)';
  }

  @override
  String get myGroupsEmpty =>
      'Wala ka pang kasaping grupo. Gamitin ang \"Magdagdag ng grupo\" sa ibaba para gumawa ng bago, maghanap, o maglagay ng code.';

  @override
  String joinRequestsHeader(int count) {
    return 'Mga humihiling sumali ($count)';
  }

  @override
  String get accountSectionHeader => 'Account';

  @override
  String get profileInformationTile => 'Impormasyon ng Profile';

  @override
  String get profileInformationCaption =>
      'Pangalan, departamento, contact, at address';

  @override
  String get settingsTile => 'Mga Setting';

  @override
  String get settingsTileCaption => 'Itsura at mga preference ng app';

  @override
  String get aboutTile => 'Tungkol Dito';

  @override
  String get aboutTileCaption => 'Bersyon, mga update, at ano ang bago';

  @override
  String get signOut => 'Mag-sign Out';

  @override
  String get defaultMemberName => 'Kasapi ng Barangay';

  @override
  String get noEmailAvailable => 'Walang available na email';

  @override
  String get searchByName => 'Maghanap gamit ang pangalan';

  @override
  String get searchHintExample => 'hal. Mayor';

  @override
  String get searchButton => 'Maghanap';

  @override
  String get noGroupsFound =>
      'Walang nahanap na grupo. Subukan ang ibang pangalan, o magtanong ng code.';

  @override
  String get privateGroupsHint =>
      'Hindi lalabas dito ang mga pribadong grupo — kakailanganin mo ang kanilang code.';

  @override
  String get declineButton => 'Tanggihan';

  @override
  String get acceptButton => 'Tanggapin';

  @override
  String wantsToJoinGroup(String groupName) {
    return 'gustong sumali sa \"$groupName\"';
  }

  @override
  String get copyGroupCode => 'Kopyahin ang code ng grupo';

  @override
  String get leaveButton => 'Umalis';

  @override
  String memberCountWithCode(int count, String code) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count na miyembro',
      one: '$count miyembro',
    );
    return '$_temp0 • code $code';
  }

  @override
  String memberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count na miyembro',
      one: '$count miyembro',
    );
    return '$_temp0';
  }

  @override
  String get joinedButton => 'Sumali na';

  @override
  String get joinButton => 'Sumali';

  @override
  String get eventTypeAll => 'Lahat';

  @override
  String get eventTypePublic => 'Pampubliko';

  @override
  String get eventTypeGroup => 'Grupo';

  @override
  String get eventTypePersonal => 'Personal';

  @override
  String get eventColorLabel => 'Kulay na etiketa';

  @override
  String get groupFilterPickerTitle => 'I-filter ang mga grupo';

  @override
  String get groupFilterPickerSubtitle =>
      'Piliin kung aling mga grupo mo ang lalabas bilang mga Group event.';

  @override
  String get groupFilterPickerApply => 'I-apply';

  @override
  String get eventDetailsTitle => 'Detalye ng Kaganapan';

  @override
  String get shareEvent => 'Ibahagi ang kaganapan';

  @override
  String get detailTime => 'Oras';

  @override
  String get detailLocation => 'Lokasyon';

  @override
  String get detailPostedBy => 'Ni-post ni';

  @override
  String postedByPrefix(String name) {
    return 'Ni $name';
  }

  @override
  String get detailDescription => 'Deskripsyon';

  @override
  String get detailAttachment => 'Attachment';

  @override
  String get attachmentAvailable => 'May attachment';

  @override
  String get comingSoon => 'Malapit na';

  @override
  String get editEventMenuItem => 'I-edit ang kaganapan';

  @override
  String get deleteEventMenuItem => 'Burahin ang kaganapan';

  @override
  String get groupEventFallbackName => 'Kaganapan ng grupo';

  @override
  String get loadingMembers => 'Ikinakarga ang mga miyembro…';

  @override
  String get fileTypePdf => 'PDF Document';

  @override
  String get fileTypeImage => 'Larawan';

  @override
  String get fileTypeVideo => 'Video';

  @override
  String get fileTypeWord => 'Word Document';

  @override
  String get fileTypeSpreadsheet => 'Spreadsheet';

  @override
  String addedEventToGroup(String title, String groupName) {
    return 'Naidagdag ang \"$title\" sa $groupName.';
  }

  @override
  String addedEventToCalendar(String title) {
    return 'Naidagdag ang \"$title\" sa kalendaryo.';
  }

  @override
  String get editEventTitle => 'I-edit ang Kaganapan';

  @override
  String get addEventTitle => 'Magdagdag ng Kaganapan';

  @override
  String get editEventSubtitle => 'I-update ang mga detalye ng kaganapang ito.';

  @override
  String get addEventSubtitle => 'Ibahagi ang isang nangyayari sa barangay.';

  @override
  String get typeHelperGroup =>
      'Makikita lang ito ng mga miyembro ng grupong pinili mo.';

  @override
  String get typeHelperPersonal => 'Ikaw lang ang makakakita nito.';

  @override
  String get typeHelperPublic => 'Makikita ito ng lahat sa app.';

  @override
  String get typeHelperRestrictedSuffix =>
      'Mga beripikadong LGU member lang ang puwedeng mag-post ng mga kaganapan ng Grupo, at ang admin lang ang puwedeng mag-post ng mga Pampublikong kaganapan.';

  @override
  String get personalEventLabel => 'Personal na kaganapan';

  @override
  String get noGroupsYetError =>
      'Wala ka pang grupo — gumawa muna ng isa sa tab na Mga Grupo.';

  @override
  String get postToGroupLabel => 'I-post sa grupo';

  @override
  String get eventTitleLabel => 'Pamagat ng kaganapan';

  @override
  String get eventTitleHint => 'hal. Asembleya ng Barangay';

  @override
  String get locationHint => 'hal. Barangay Hall';

  @override
  String get additionalDetailsLabel => 'Karagdagang Detalye (opsyonal)';

  @override
  String get additionalDetailsHint =>
      'Magdagdag ng maikling tala para sa mga residente';

  @override
  String get multiDayEventLabel => 'Kaganapang maraming araw';

  @override
  String get multiDayEventHint =>
      'Tumatagal nang higit sa isang araw, hal. isang 3-araw na pista.';

  @override
  String get startDateLabel => 'Petsa ng simula';

  @override
  String get endDateLabel => 'Petsa ng pagtatapos';

  @override
  String get dateLabel => 'Petsa';

  @override
  String get defaultStartTimeLabel => 'Default na oras ng simula';

  @override
  String get startTimeLabel => 'Oras ng simula';

  @override
  String get defaultEndTimeLabel => 'Default na oras ng pagtatapos';

  @override
  String get endTimeLabel => 'Oras ng pagtatapos';

  @override
  String get changeButton => 'Palitan';

  @override
  String get overlapsWithOne => 'Nagtatapat sa isang umiiral na kaganapan:';

  @override
  String overlapsWithMany(int count) {
    return 'Nagtatapat sa $count umiiral na kaganapan:';
  }

  @override
  String get adjustOverlapHint =>
      'Ayusin ang oras o saklaw ng petsa para maalis ang pagkakatapat.';

  @override
  String get noFreeSlotHint =>
      'Wala nang bakanteng oras sa araw na iyon — subukan ang ibang petsa.';

  @override
  String freeSlotSuggestion(String start, String end) {
    return 'Bakanteng oras: $start – $end · I-tap para gamitin';
  }

  @override
  String get overlapDialogTitleOne =>
      'Nagtatapat ito sa isang umiiral na kaganapan';

  @override
  String overlapDialogTitleMany(int count) {
    return 'Nagtatapat ito sa $count umiiral na kaganapan';
  }

  @override
  String get overlapDialogBody =>
      'Puwede mo pa rin itong i-save, pero baka makita ng iba ang dalawang kaganapang magkasabay ang oras:';

  @override
  String get proceedAnyway => 'Ituloy pa rin';

  @override
  String get savingButton => 'Sine-save...';

  @override
  String get saveChangesButton => 'I-save ang mga pagbabago';

  @override
  String get saveEventButton => 'I-save ang kaganapan';

  @override
  String get titleLocationRequired => 'Kailangan ang pamagat at lokasyon.';

  @override
  String get pastDateError =>
      'Hindi puwedeng magdagdag ng kaganapan sa nakaraang petsa.';

  @override
  String get endAfterStartMultiDay =>
      'Dapat mauna ang simula bago ang pagtatapos.';

  @override
  String get endAfterStartSingleDay =>
      'Dapat mauna ang oras ng simula bago ang oras ng pagtatapos.';

  @override
  String get pickGroupError =>
      'Pumili ng grupo para sa kaganapang ito — gumawa o sumali sa isa sa tab na Mga Grupo.';

  @override
  String saveEventError(String error) {
    return 'Hindi ma-save ang kaganapan: $error';
  }

  @override
  String get perDayScheduleTitle => 'Iskedyul bawat araw';

  @override
  String get perDayScheduleHint =>
      'Ginagamit ng bawat araw ang default na oras sa itaas maliban kung babaguhin mo ito — hal. buong araw sa unang araw, ilang oras lang sa ikalawa.';

  @override
  String defaultTimeRangeSuffix(String start, String end) {
    return '$start – $end (default)';
  }

  @override
  String timeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get resetButton => 'I-reset';

  @override
  String get allDayButton => 'Buong araw';

  @override
  String get customizeButton => 'I-customize';

  @override
  String get securityTile => 'Seguridad';

  @override
  String get securityTileCaption => 'Palitan ang iyong email at password';

  @override
  String get securityTitle => 'Seguridad';

  @override
  String get securitySubtitle =>
      'Pamahalaan ang iyong email at password para sa pag-login.';

  @override
  String get securityEmailSectionTitle => 'Email';

  @override
  String securityCurrentEmail(String email) {
    return 'Kasalukuyan: $email';
  }

  @override
  String get newEmailLabel => 'Bagong email';

  @override
  String get updateEmailButton => 'I-update ang email';

  @override
  String get updatingButton => 'Ina-update...';

  @override
  String get invalidEmailError => 'Maglagay ng wastong email address.';

  @override
  String get sameEmailError => 'Iyan na ang kasalukuyan mong email.';

  @override
  String get emailUpdateSuccess =>
      'Tingnan ang iyong bagong email address para sa link ng kumpirmasyon — magkakabisa ang pagbabago sa sandaling i-click mo ito.';

  @override
  String updateEmailError(String error) {
    return 'Hindi ma-update ang email: $error';
  }

  @override
  String get securityPasswordSectionTitle => 'Password';

  @override
  String get newPasswordLabel => 'Bagong password';

  @override
  String get confirmNewPasswordLabel => 'Kumpirmahin ang bagong password';

  @override
  String get showPasswordTooltip => 'Ipakita ang password';

  @override
  String get hidePasswordTooltip => 'Itago ang password';

  @override
  String get updatePasswordButton => 'I-update ang password';

  @override
  String get passwordTooShortError =>
      'Dapat hindi bababa sa 6 na karakter ang password.';

  @override
  String get passwordMismatchError => 'Hindi magkatugma ang mga password.';

  @override
  String get passwordUpdateSuccess => 'Na-update na ang password.';

  @override
  String updatePasswordError(String error) {
    return 'Hindi ma-update ang password: $error';
  }

  @override
  String get createGroupTitle => 'Gumawa ng grupo';

  @override
  String get createGroupSubtitle =>
      'Gumawa ng espasyo para ibahagi ang mga kaganapan sa isang partikular na grupo ng mga tao.';

  @override
  String get howGroupsWorkTitle => 'Paano gumagana ang mga grupo';

  @override
  String get howGroupsWorkBody =>
      'Ang grupo ay parang group chat para sa isang partikular na bilog — ang iyong purok, opisina, o liga. Makikita ng bawat sasali ang bawat kaganapang \"Grupo\" na na-post dito, at ang mga miyembro lang ang makakakita nito. Kapag ginawa mo ito, makakakuha ka ng 6-karakter na code na maibabahagi para makasali ang iba — at mapamamahalaan mo kung sino ang kasapi mula sa listahan ng miyembro ng grupo pagkatapos.';

  @override
  String get groupNameLabel => 'Pangalan ng grupo';

  @override
  String get groupNameHint => 'hal. Mga Update sa Purok 3';

  @override
  String get privateGroupLabel => 'Pribadong grupo';

  @override
  String get privateGroupHint =>
      'Nakatago mula sa paghahanap — kailangan ng iba ang iyong code, at ikaw ang aaprubahan kung sino ang sasali. Mainam para sa mas maliit o mas sensitibong grupo.';

  @override
  String get creatingButton => 'Gumagawa...';

  @override
  String get createGroupButton => 'Gumawa ng grupo';

  @override
  String get enterGroupNameError => 'Maglagay muna ng pangalan ng grupo.';

  @override
  String get createGroupError => 'Hindi magawa ang grupo. Subukan ulit.';

  @override
  String get joinWithCodeTitle => 'Sumali gamit ang code';

  @override
  String get joinWithCodeSubtitle =>
      'May invite code ka ba? Gamitin ito para sumali sa grupong iyon.';

  @override
  String get howJoiningWorksTitle => 'Paano gumagana ang pagsali';

  @override
  String get howJoiningWorksBody =>
      'Tanungin ang gumawa ng grupo para sa kanilang 6-karakter na code — makikita ito sa page ng miyembro ng grupo. Ang paglalagay nito dito ay gumagana rin para sa mga pribadong grupo: sa halip na agad sumali, magpapadala ito ng hiling na aaprubahan ng admin ng grupo.';

  @override
  String get groupCodeLabel => 'Code ng grupo';

  @override
  String get groupCodeHint => 'hal. QXK2P9';

  @override
  String get joiningButton => 'Sumasali...';

  @override
  String get joinGroupButton => 'Sumali sa grupo';

  @override
  String get enterCodeError => 'Maglagay muna ng code ng grupo.';

  @override
  String get joinGroupError =>
      'Hindi makasali. Tingnan ang code at subukan ulit.';

  @override
  String get couldNotLoadMembersError =>
      'Hindi ma-load ang mga miyembro. Subukan ulit.';

  @override
  String promotedToAdminMessage(String name) {
    return 'Si $name ay admin na ngayon.';
  }

  @override
  String get couldNotPromoteError =>
      'Hindi ma-promote ang miyembrong ito. Subukan ulit.';

  @override
  String removeMemberTitle(String name) {
    return 'Alisin si $name?';
  }

  @override
  String get removeMemberBody =>
      'Mawawalan sila ng access sa mga kaganapan ng grupong ito hanggang sumali ulit sila gamit ang code.';

  @override
  String get removeButton => 'Alisin';

  @override
  String removedMemberMessage(String name) {
    return 'Inalis si $name.';
  }

  @override
  String get couldNotRemoveError =>
      'Hindi maialis ang miyembrong ito. Subukan ulit.';

  @override
  String get verifiedGroupMarked => 'Minarkahan bilang opisyal na grupo.';

  @override
  String get verifiedGroupUnmarked => 'Inalis ang opisyal na marka.';

  @override
  String get couldNotUpdateGroupError =>
      'Hindi ma-update ang grupong ito. Subukan ulit.';

  @override
  String get noOtherMembersError =>
      'Walang ibang miyembro na mapagbibigyan ng pagmamay-ari.';

  @override
  String get transferOwnershipToTitle => 'Ilipat ang pagmamay-ari kay...';

  @override
  String makeOwnerTitle(String name) {
    return 'Gawing may-ari si $name?';
  }

  @override
  String get makeOwnerBody =>
      'Magagawa nilang burahin ang grupong ito at alisin ang mga kapwa admin — mga pribilehiyong may-ari lang ang may hawak. Hindi mo na ito maibabalik pagkatapos.';

  @override
  String get transferButton => 'Ilipat';

  @override
  String ownershipTransferredMessage(String name) {
    return 'Si $name na ang may-ari ngayon.';
  }

  @override
  String get couldNotTransferError =>
      'Hindi maialipat ang pagmamay-ari. Subukan ulit.';

  @override
  String get copyCodeTooltip => 'Kopyahin ang code';

  @override
  String codeCopiedMessage(String code) {
    return 'Nakopya ang code na $code.';
  }

  @override
  String get verifiedOfficialGroup => 'Beripikadong opisyal na grupo';

  @override
  String get notVerified => 'Hindi beripikado';

  @override
  String get removeMarkButton => 'Alisin ang marka';

  @override
  String get markAsOfficialButton => 'Markahan bilang opisyal';

  @override
  String get staffTurnoverHint =>
      'May pagpapalit ng tauhan? Ilipat ang mga pribilehiyong ito para sa may-ari lang sa ibang miyembro.';

  @override
  String get transferOwnershipButton => 'Ilipat ang pagmamay-ari';

  @override
  String get invitePeopleTitle => 'Mag-imbita ng tao';

  @override
  String invitePeopleBody(String action) {
    return 'Walang direktoryo ng user para magdagdag ng tao — ibahagi na lang ang code na ito. Ang sinumang maglagay nito ay $action.';
  }

  @override
  String get joinsInstantlyAction => 'agad na sasali';

  @override
  String get sendsJoinRequestAction => 'magpapadala ng hiling na aaprubahan mo';

  @override
  String get searchMembersLabel => 'Maghanap ng miyembro';

  @override
  String get searchMembersHint => 'I-type ang pangalan';

  @override
  String get membersHeader => 'Mga Miyembro';

  @override
  String get noMembersYet => 'Wala pang miyembro.';

  @override
  String noMembersMatch(String query) {
    return 'Walang miyembrong tumugma sa \"$query\".';
  }

  @override
  String get adminBadge => 'Admin';

  @override
  String joinedDatePrefix(String date) {
    return 'Sumali noong $date';
  }

  @override
  String get promoteToAdminMenuItem => 'I-promote bilang admin';

  @override
  String get removeFromGroupMenuItem => 'Alisin sa grupo';

  @override
  String memberYouSuffix(String name) {
    return '$name (Ikaw)';
  }

  @override
  String get aboutSubtitle => 'Impormasyon ng bersyon at kung ano ang bago.';

  @override
  String get shareAppSection => 'Ibahagi ang app';

  @override
  String get shareAppHint =>
      'I-scan ang QR code o ibahagi ang link para makapag-install ang iba ng eBongabong Calendar.';

  @override
  String get shareDownloadLinkButton => 'Ibahagi ang link ng download';

  @override
  String get updatesSection => 'Mga Update';

  @override
  String get updateCheckingUnavailable =>
      'Hindi available ang pagsuri ng update sa build na ito.';

  @override
  String versionAvailable(String version) {
    return 'Available na ang bersyon $version.';
  }

  @override
  String get updateNowButton => 'I-update ngayon';

  @override
  String get upToDateMessage => 'Ikaw ay updated na.';

  @override
  String get checkForUpdatesButton => 'Suriin ang mga update';

  @override
  String get checkUpdateError => 'Hindi makasuri ng update sa ngayon.';

  @override
  String get openUpdateLinkError => 'Hindi mabuksan ang link ng update.';

  @override
  String get loadingVersion => 'Ikinakarga ang bersyon…';

  @override
  String versionLabel(String version) {
    return 'Bersyon $version';
  }

  @override
  String whatsNewInVersion(String version) {
    return 'Ano ang bago sa $version';
  }

  @override
  String get profilePictureTitle => 'Larawan sa Profile';

  @override
  String get profilePictureSubtitle => 'Pumili ng isa — agad itong mase-save.';

  @override
  String get couldNotSaveAvatarError =>
      'Hindi ma-save ang iyong larawan sa profile. Subukan ulit.';

  @override
  String get avatarCategoryAnime => 'Anime';

  @override
  String get avatarCategoryAnimal => 'Hayop';

  @override
  String get avatarCategoryPerson => 'Tao';

  @override
  String get requiresApprovalLabel => 'Kailangan ng pag-apruba para sumali';

  @override
  String get requiresApprovalHint =>
      'Dapat tanggapin muna ng admin ang mga bagong miyembro bago nila makita ang mga kaganapan ng grupong ito.';

  @override
  String get joinPolicyOpen => 'Sinumang may access ay agad na makakasali';

  @override
  String get joinPolicyApprovalRequired =>
      'Kailangan ng pag-apruba ang mga bagong miyembro';

  @override
  String get requireApprovalButton => 'Kailanganin ang pag-apruba';

  @override
  String get allowInstantJoinButton => 'Payagan ang agarang pagsali';

  @override
  String get requireApprovalEnabledMessage =>
      'Kailangan na ngayong aprubahan ang mga bagong miyembro bago sumali.';

  @override
  String get requireApprovalDisabledMessage =>
      'Kahit sino ay puwede nang agad sumali.';

  @override
  String get couldNotUpdateJoinSettingError =>
      'Hindi ma-update ang setting ng pagsali ng grupong ito. Subukan ulit.';

  @override
  String get requestToJoinButton => 'Humiling na sumali';

  @override
  String get approvalRequiredTag => 'Kailangan ng pag-apruba';

  @override
  String joinedGroupMessage(String name) {
    return 'Sumali ka sa \"$name\".';
  }

  @override
  String joinRequestSentMessage(String name) {
    return 'Naipadala ang hiling — hinihintay na aprubahan ka ng \"$name\".';
  }

  @override
  String alreadyInGroupMessage(String name) {
    return 'Kasapi ka na sa \"$name\".';
  }

  @override
  String groupCreatedApprovalMessage(String name, String code) {
    return 'Nagawa ang \"$name\". Ang code na $code ay nagpapahintulot sa mga tao na humiling na sumali — ikaw ang aaprubahan kung sino ang papasok.';
  }

  @override
  String groupCreatedOpenMessage(String name, String code) {
    return 'Nagawa ang \"$name\". Ibahagi ang code na $code para makasali agad ang iba.';
  }

  @override
  String get groupCreatedPrivateNote =>
      'Hindi ito lalabas sa paghahanap — ang mga taong may code lang ang makakahanap nito.';

  @override
  String get couldNotJoinGroupError => 'Hindi makasali sa grupo. Subukan ulit.';

  @override
  String get onlyLguCanCreateGroupError =>
      'Mga beripikadong LGU member lang ang puwedeng gumawa ng grupo. Puwede ka pa ring sumali sa isa sa pamamagitan ng paghahanap ng pangalan nito o paglalagay ng code.';

  @override
  String get deleteGroupButton => 'Burahin ang grupo';

  @override
  String get deleteGroupHint =>
      'Permanenteng buburahin ang grupong ito at aalisin ang lahat ng miyembro nito. Mananatili ang mga kaganapang na-post na dito, pero mawawala ang koneksyon nila sa grupo.';

  @override
  String deleteGroupConfirmTitle(String name) {
    return 'Burahin ang \"$name\"?';
  }

  @override
  String get deleteGroupConfirmBody =>
      'Permanenteng buburahin nito ang grupo at aalisin ang lahat ng miyembro nito. Mananatili ang mga kaganapang na-post na dito, pero mawawala ang koneksyon nila sa grupo. Hindi na ito maibabalik.';

  @override
  String get couldNotDeleteGroupError =>
      'Hindi maburahan ang grupo. Subukan ulit.';

  @override
  String groupDeletedMessage(String name) {
    return 'Nabura ang \"$name\".';
  }

  @override
  String get enableKioskModeButton => 'I-enable ang Kiosk Mode';

  @override
  String get exitKioskModeButton => 'Lumabas sa Kiosk Mode';

  @override
  String get kioskExitPasscodeTitle => 'Ilagay ang Passcode';

  @override
  String get kioskExitPasscodeSubtitle =>
      'Ilagay ang 4-digit na passcode para lumabas sa Kiosk Mode.';

  @override
  String get kioskExitPasscodeWrong => 'Maling passcode. Subukan ulit.';

  @override
  String get kioskPasscodeSectionTitle => 'Passcode ng Kiosk';

  @override
  String get kioskPasscodeSectionSubtitle =>
      'Ginagamit para lumabas sa Kiosk Mode sa mga device ng account na ito.';

  @override
  String get kioskPasscodeCurrentLabel => 'Kasalukuyang passcode';

  @override
  String get kioskPasscodeNewLabel => 'Bagong passcode';

  @override
  String get kioskPasscodeConfirmLabel => 'Kumpirmahin ang bagong passcode';

  @override
  String get kioskPasscodeUpdateButton => 'I-update ang Passcode';

  @override
  String get kioskPasscodeMismatch => 'Hindi magkatugma ang mga passcode.';

  @override
  String get kioskPasscodeInvalidLength =>
      'Dapat eksaktong 4 na numero ang passcode.';

  @override
  String get kioskPasscodeUpdateSuccess => 'Na-update na ang passcode.';

  @override
  String get aboutThisAppSection => 'Tungkol sa App na Ito';

  @override
  String get aboutThisAppBody =>
      'Ang eBongabong Calendar ang opisyal na app ng mga kaganapan sa komunidad ng Munisipalidad ng Bongabong, Pilipinas — ginawa para malaman agad ng mga residente ang mga gawain sa barangay, anunsyo ng pamahalaan, at mga pagtitipon ng komunidad, lahat sa isang lugar.';

  @override
  String get aboutThisAppFeaturesIntro =>
      'Sa eBongabong Calendar, puwede kang:';

  @override
  String get aboutFeaturePublicEvents =>
      'Makakita ng mga pampublikong anunsyo at kaganapang na-post ng LGU';

  @override
  String get aboutFeatureGroups =>
      'Sumali sa mga grupo ng iyong barangay, opisina, o organisasyon para makita ang mga kaganapang ibinabahagi lang sa bilog na iyon';

  @override
  String get aboutFeaturePersonal =>
      'Mag-ingat ng personal na paalala at tala na ikaw lang ang makakakita';

  @override
  String get aboutFeatureNotifications =>
      'Mabigyan ng abiso sa sandaling may na-post na bagong kaganapan, at magtakda ng paalala bago ito magsimula';

  @override
  String get aboutFeatureLanguage =>
      'Magpalit sa pagitan ng Ingles at Filipino anumang oras';

  @override
  String get aboutFeatureDisplay =>
      'Ayusin ang sukat ng display para sa telepono, tablet, o pampublikong kiosk screen';

  @override
  String get faqTile => 'Mga Madalas Itanong';

  @override
  String get faqTileCaption =>
      'Mga karaniwang tanong tungkol sa paggamit ng app';

  @override
  String get faqPageTitle => 'Mga Madalas Itanong';

  @override
  String get faqPageSubtitle =>
      'Mga sagot sa karaniwang tanong tungkol sa eBongabong Calendar. I-tap ang tanong para makita ang sagot.';

  @override
  String get faqQ1 =>
      'Ano ang pagkakaiba ng Pampubliko, Grupo, at Personal na kaganapan?';

  @override
  String get faqA1 =>
      'Ang mga Pampublikong kaganapan ay opisyal na anunsyo para sa buong barangay na ang superadmin lang ang puwedeng mag-post — makikita ito ng lahat ng gumagamit ng app. Ang mga kaganapan ng Grupo ay ibinabahagi lang sa mga miyembro ng partikular na grupo, tulad ng iyong opisina sa barangay o isang klub — ang mga miyembro lang ang makakakita. Ang mga Personal na kaganapan ay pribadong tala na ikaw lang ang makakakita, para sa sarili mong paalala.';

  @override
  String get faqQ2 => 'Paano ako sasali sa isang grupo?';

  @override
  String get faqA2 =>
      'Mula sa tab na Mga Grupo, i-tap ang icon ng paghahanap para tingnan ang mga pampublikong grupo, o maglagay ng 6-karakter na invite code kung mayroon ka. Agad kang sasali sa mga pampublikong grupo, o magpapadala ng hiling kung kailangan ng pag-apruba ng grupo; laging kailangan ng code ang mga pribadong grupo.';

  @override
  String get faqQ3 => 'Paano ako gagawa ng grupo?';

  @override
  String get faqA3 =>
      'Ang paggawa ng grupo ay para lang sa mga beripikadong LGU member at ang superadmin. Kung isa kang citizen, magtanong sa iyong opisina sa barangay o sa superadmin tungkol sa pag-apply para sa access bilang LGU mula sa tab na Mga Grupo.';

  @override
  String get faqQ4 => 'Bakit hindi ako makapag-post ng Pampublikong kaganapan?';

  @override
  String get faqA4 =>
      'Naaabot ng mga Pampublikong kaganapan ang buong komunidad, kaya ang superadmin lang ang puwedeng mag-post nito — nakakatulong ito para hindi malunod ang opisyal na mga anunsyo sa gitna ng mga kaganapan ng komunidad. Puwede pa ring mag-post ang mga LGU member ng mga kaganapan ng Grupo sa mga miyembro ng sarili nilang grupo.';

  @override
  String get faqQ5 => 'Paano gumagana ang mga paalala sa kaganapan?';

  @override
  String get faqA5 =>
      'Sa Mga Setting, sa ilalim ng Mga Abiso, piliin kung kailan mo gustong paalalahanan — 1 oras o 1 araw bago magsimula ang kaganapan. Makakatanggap ka ng abiso para sa bawat kaganapang nakikita mo na: mga pampublikong kaganapan, kaganapan ng iyong mga grupo, at ang iyong sariling personal na kaganapan.';

  @override
  String get faqQ6 => 'Paano ko papalitan ang app sa Filipino?';

  @override
  String get faqA6 =>
      'Buksan ang Mga Setting at i-tap ang Wika, pagkatapos piliin ang Filipino o English. Agad itong magkakabisa at maaalala sa bawat device kung saan ka mag-log in.';

  @override
  String get faqQ7 => 'Ano ang Kiosk Mode?';

  @override
  String get faqA7 =>
      'Ginagawang full-screen, view-only na display ng kalendaryo ang app sa Kiosk Mode — walang menu, walang button na Magdagdag ng Kaganapan — para sa isang pampublikong screen na walang bantay, tulad ng nasa barangay hall. Isang account lang na itinalaga ng superadmin bilang kiosk account ang makapagbubukas nito, mula sa isang button sa itaas ng tab na Kalendaryo.';

  @override
  String get faqQ8 => 'Paano ako magiging beripikadong LGU member?';

  @override
  String get faqA8 =>
      'Mula sa tab na Mga Grupo o sa LGU admin portal, magsumite ng aplikasyon kasama ang iyong opisina o departamento. Susuriin at aaprubahan ito ng superadmin — kapag naaprubahan, puwede ka nang gumawa ng grupo at mag-post ng mga kaganapan ng Grupo.';

  @override
  String get faqQ9 => 'Pribado ba ang aking impormasyon?';

  @override
  String get faqA9 =>
      'Makikita lang ang iyong profile ng iba kung pipiliin mong ibahagi ito, tulad ng pagsali sa isang grupo. Tingnan ang Patakaran sa Privacy sa Mga Setting para sa buong detalye kung ano ang kinokolekta at paano ito ginagamit.';

  @override
  String get privacyPolicyTile => 'Patakaran sa Privacy';

  @override
  String get privacyPolicyTileCaption =>
      'Ano ang kinokolekta namin at paano ito ginagamit';

  @override
  String get privacyPolicyTitle => 'Patakaran sa Privacy';

  @override
  String get privacyPolicySubtitle =>
      'Paano hinahawakan ng eBongabong Calendar ang iyong impormasyon.';

  @override
  String get privacyIntro =>
      'Ipinapaliwanag ng Patakaran sa Privacy na ito kung anong impormasyon ang kinokolekta ng eBongabong Calendar, paano ito ginagamit, at sino ang makakakita nito. Ito ay para sa lahat ng gumagamit ng app, maging ikaw ay isang residente, LGU member, o superadmin.';

  @override
  String get privacyCollectHeading => 'Impormasyong Kinokolekta Namin';

  @override
  String get privacyCollectBody =>
      'Kapag gumawa ka ng account, kinokolekta namin ang iyong email address at ang mga detalyeng idadagdag mo sa iyong profile — pangalan, departamento, numero ng telepono, address, maikling bio, at larawan sa profile na pinili mula sa nakapirming set ng mga avatar (hindi kailanman ina-access ng app ang iyong camera o photo library). Iniimbak din namin ang mga kaganapan, grupo, at kagustuhan (wika, tema, sukat ng display, paalala) na itinakda mo habang ginagamit ang app.';

  @override
  String get privacyUseHeading => 'Paano Namin Ginagamit ang Iyong Impormasyon';

  @override
  String get privacyUseBody =>
      'Ang iyong impormasyon ay ginagamit lang para patakbuhin ang mga tampok ng app: pagpapakita ng mga may-kaugnayang kaganapan, pagpapahintulot sa iyong sumali at pamahalaan ang mga grupo, pag-alala ng iyong mga kagustuhan sa display at wika sa iba\'t ibang device, at pagpapadala ng mga abisong hiniling mo. Hindi namin ginagamit ang iyong impormasyon para sa advertising, at hindi namin ito ibinebenta kaninuman.';

  @override
  String get privacyVisibilityHeading =>
      'Sino ang Makakakita ng Iyong Impormasyon';

  @override
  String get privacyVisibilityBody =>
      'Ikaw lang ang makakakita ng mga detalye ng iyong profile. Kung sumali ka sa isang grupo, makikita ng ibang miyembro ng grupong iyon ang iyong pangalan at larawan sa listahan ng miyembro. Sinusunod ng mga kaganapan ang sarili nilang visibility: makikita ng lahat ang mga Pampublikong kaganapan, ng mga miyembro lang ng grupo ang mga kaganapan ng Grupo, at ikaw lang ang makakakita ng mga Personal na kaganapan.';

  @override
  String get privacyThirdPartyHeading => 'Mga Serbisyo ng Ikatlong Partido';

  @override
  String get privacyThirdPartyBody =>
      'Ang app ay binuo gamit ang Supabase, na nag-hohost ng aming database at humahawak ng pag-sign in, at Firebase Cloud Messaging, na naghahatid ng mga push notification sa Android. Pareho itong nag-e-encrypt ng data habang ipinapadala, at ang Supabase ay nag-e-encrypt din ng data habang nakaimbak. Pinoproseso lang ng mga provider na ito ang data para tumulong patakbuhin ang app — wala silang sariling hiwalay na gamit para dito.';

  @override
  String get privacyRetentionHeading => 'Ang Iyong mga Pagpipilian';

  @override
  String get privacyRetentionBody =>
      'Puwede mong i-edit o alisin ang karamihan ng detalye ng iyong profile, burahin ang mga kaganapan at grupong ginawa mo, at baguhin ang iyong mga kagustuhan sa abiso at wika anumang oras mula sa loob ng app. Para humiling ng pagbura ng buo mong account, makipag-ugnayan sa iyong opisina sa barangay o sa LGU admin team ng munisipalidad.';

  @override
  String get privacyChildrenHeading => 'Privacy ng mga Bata';

  @override
  String get privacyChildrenBody =>
      'Ang eBongabong Calendar ay para sa pangkalahatang gamit ng komunidad at hindi partikular na nakatuon sa mga bata. Kung sa palagay mo ay may nagbigay ng personal na impormasyon ng isang bata nang walang naaangkop na pahintulot, makipag-ugnayan sa iyong opisina sa barangay para maalis ito.';

  @override
  String get privacyChangesHeading => 'Mga Pagbabago sa Patakarang Ito';

  @override
  String get privacyChangesBody =>
      'Kung magbabago ang patakarang ito, makikita ang update dito na may bagong petsa ng pagkakabisa. Ang pagpapatuloy sa paggamit ng app pagkatapos ng pagbabago ay nangangahulugang tinatanggap mo ang na-update na patakaran.';

  @override
  String get privacyLegalHeading => 'Pagsunod sa Batas';

  @override
  String get privacyLegalBody =>
      'Ang app na ito ay pinapatakbo ng Munisipalidad ng Bongabong alinsunod sa Data Privacy Act of 2012 (Republic Act No. 10173). Para sa mga tanong tungkol sa iyong data, makipag-ugnayan sa iyong opisina sa barangay o sa LGU admin team ng munisipalidad.';
}

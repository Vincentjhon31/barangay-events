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
  String get calendarViewMonth => 'Buwan';

  @override
  String get calendarViewWeek => 'Linggo';

  @override
  String get calendarViewList => 'Listahan';

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
}

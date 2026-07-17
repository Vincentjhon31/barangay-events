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
      other: '# na miyembro',
      one: '# miyembro',
    );
    return '$_temp0 • code $code';
  }

  @override
  String memberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# na miyembro',
      one: '# miyembro',
    );
    return '$_temp0';
  }

  @override
  String get joinedButton => 'Sumali na';

  @override
  String get joinButton => 'Sumali';
}

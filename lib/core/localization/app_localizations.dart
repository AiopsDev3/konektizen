import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:konektizen/core/localization/app_language.dart';

const _storage = FlutterSecureStorage();
const _languageStorageKey = 'konektizen_language';

final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
      return AppLanguageNotifier();
    });

final appStringsProvider = Provider<AppStrings>((ref) {
  return AppStrings(ref.watch(appLanguageProvider));
});

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier() : super(AppLanguage.english) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: _languageStorageKey);
    state = AppLanguage.fromCode(saved);
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    await _storage.write(key: _languageStorageKey, value: language.code);
  }
}

class AppStrings {
  AppStrings(this.language);

  final AppLanguage language;

  String text(String key) =>
      _strings[language]?[key] ?? _strings[AppLanguage.english]?[key] ?? key;
}

const _strings = {
  AppLanguage.english: {
    'nav.home': 'Home',
    'nav.sos': 'SOS',
    'nav.map': 'Map',
    'nav.advisory': 'Advisory',
    'nav.profile': 'Profile',
    'home.greeting': 'Good Morning',
    'home.quickReport': 'Report an Issue',
    'home.category.garbage': 'Garbage',
    'home.category.road': 'Road',
    'home.category.flood': 'Flood',
    'home.category.streetLight': 'Street Light',
    'home.category.traffic': 'Traffic',
    'home.category.report': 'Report',
    'home.alertsNews': 'Alerts and News',
    'home.alertsNotifications': 'Alerts & Notifications',
    'home.newsSources': 'News Sources',
    'home.activeReports': 'Active Reports',
    'home.viewAll': 'View All',
    'home.noActiveReports': 'No active reports',
    'home.checkHistory': 'Check History',
    'profile.title': 'Profile',
    'profile.verified': 'Verified Citizen',
    'profile.pending': 'Verification Pending',
    'profile.notVerified': 'Not Verified',
    'profile.verifyAccount': 'Verify Your Account',
    'profile.verifySubtitle': 'Get verified to help your barangay.',
    'profile.verificationProgress': 'Verification In Progress',
    'profile.verificationProgressSubtitle': 'We are checking your documents.',
    'profile.edit': 'Edit Profile',
    'profile.myCases': 'My Cases',
    'profile.language': 'Language',
    'profile.accessibility': 'Accessibility',
    'profile.help': 'Help & Support',
    'profile.about': 'About KONEKTIZEN',
    'profile.logout': 'Log Out',
    'profile.chooseLanguage': 'Choose Language',
    'cases.title': 'My Cases',
    'cases.active': 'Active',
    'cases.inProgress': 'In Progress',
    'cases.history': 'History',
    'cases.empty': 'No cases found',
  },
  AppLanguage.tagalog: {
    'nav.home': 'Tahanan',
    'nav.sos': 'SOS',
    'nav.map': 'Mapa',
    'nav.advisory': 'Abiso',
    'nav.profile': 'Profile',
    'home.greeting': 'Magandang umaga',
    'home.quickReport': 'Mag-ulat ng Isyu',
    'home.category.garbage': 'Basura',
    'home.category.road': 'Kalsada',
    'home.category.flood': 'Pagbaha',
    'home.category.streetLight': 'Ilaw sa Kalye',
    'home.category.traffic': 'Trapiko',
    'home.category.report': 'Mag-ulat',
    'home.alertsNews': 'Mga Abiso at Balita',
    'home.alertsNotifications': 'Mga Abiso at Notipikasyon',
    'home.newsSources': 'Pinagmumulan ng Balita',
    'home.activeReports': 'Aktibong mga Ulat',
    'home.viewAll': 'Tingnan Lahat',
    'home.noActiveReports': 'Walang aktibong ulat',
    'home.checkHistory': 'Suriin ang History',
    'profile.title': 'Profile',
    'profile.verified': 'Beripikadong Mamamayan',
    'profile.pending': 'Naka-pending ang Beripikasyon',
    'profile.notVerified': 'Hindi Pa Beripikado',
    'profile.verifyAccount': 'I-verify ang Account',
    'profile.verifySubtitle': 'Magpa-verify para makatulong sa barangay.',
    'profile.verificationProgress': 'Kasalukuyang Bine-verify',
    'profile.verificationProgressSubtitle':
        'Sinusuri namin ang iyong mga dokumento.',
    'profile.edit': 'I-edit ang Profile',
    'profile.myCases': 'Aking mga Kaso',
    'profile.language': 'Wika',
    'profile.accessibility': 'Accessibility',
    'profile.help': 'Tulong at Suporta',
    'profile.about': 'Tungkol sa KONEKTIZEN',
    'profile.logout': 'Mag-log Out',
    'profile.chooseLanguage': 'Pumili ng Wika',
    'cases.title': 'Aking mga Kaso',
    'cases.active': 'Aktibo',
    'cases.inProgress': 'Ginagawa',
    'cases.history': 'History',
    'cases.empty': 'Walang nakitang kaso',
  },
  AppLanguage.ilocano: {
    'nav.home': 'Balay',
    'nav.sos': 'SOS',
    'nav.map': 'Mapa',
    'nav.advisory': 'Pakaammo',
    'nav.profile': 'Profile',
    'home.greeting': 'Naimbag a bigat',
    'home.quickReport': 'Agreport ti Isyu',
    'home.category.garbage': 'Basura',
    'home.category.road': 'Kalsada',
    'home.category.flood': 'Layus',
    'home.category.streetLight': 'Silaw ti Kalsada',
    'home.category.traffic': 'Trapiko',
    'home.category.report': 'Agreport',
    'home.alertsNews': 'Dagiti Pakaammo ken Damag',
    'home.alertsNotifications': 'Dagiti Pakaammo',
    'home.newsSources': 'Pagtaudan ti Damag',
    'home.activeReports': 'Aktibo a Report',
    'home.viewAll': 'Kitaen Amin',
    'home.noActiveReports': 'Awan ti aktibo a report',
    'home.checkHistory': 'Kitaen ti History',
    'profile.title': 'Profile',
    'profile.verified': 'Napaneknekan nga Umili',
    'profile.pending': 'Ur-urayen ti Panangpaneknek',
    'profile.notVerified': 'Saan pay a Napaneknekan',
    'profile.verifyAccount': 'Paneknekan ti Account',
    'profile.verifySubtitle': 'Agpa-verify tapno makatulong iti barangay.',
    'profile.verificationProgress': 'Mapaspasamak ti Panangpaneknek',
    'profile.verificationProgressSubtitle': 'Sursurien mi dagiti dokumentom.',
    'profile.edit': 'Urnosen ti Profile',
    'profile.myCases': 'Dagiti Kasok',
    'profile.language': 'Pagsasao',
    'profile.accessibility': 'Accessibility',
    'profile.help': 'Tulong ken Suporta',
    'profile.about': 'Maipapan iti KONEKTIZEN',
    'profile.logout': 'Ag-log Out',
    'profile.chooseLanguage': 'Pilien ti Pagsasao',
    'cases.title': 'Dagiti Kasok',
    'cases.active': 'Aktibo',
    'cases.inProgress': 'Mapaspasamak',
    'cases.history': 'History',
    'cases.empty': 'Awan ti nakitada a kaso',
  },
};

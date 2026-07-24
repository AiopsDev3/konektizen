enum AppEdition { standard, laoag }

class AppFeatures {
  AppFeatures._();

  static AppEdition _edition = AppEdition.standard;

  static AppEdition get edition => _edition;
  static bool get isLaoag => _edition == AppEdition.laoag;
  static bool get sosCallsEnabled => !isLaoag;

  static void configure(AppEdition edition) {
    _edition = edition;
  }
}

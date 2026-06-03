enum AppLanguage {
  english('en', 'English', 'English'),
  tagalog('tl', 'Tagalog', 'Tagalog'),
  ilocano('ilo', 'Ilocano', 'Ilocano');

  const AppLanguage(this.code, this.label, this.nativeLabel);

  final String code;
  final String label;
  final String nativeLabel;

  static AppLanguage fromCode(String? code) {
    return AppLanguage.values.firstWhere(
      (language) => language.code == code,
      orElse: () => AppLanguage.english,
    );
  }
}

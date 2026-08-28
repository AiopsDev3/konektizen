import 'package:flutter_test/flutter_test.dart';
import 'package:konektizen/core/update/mobile_update_gate.dart';

void main() {
  group('KonektizenMobileRelease', () {
    test('parses the generic Konektizen release manifest', () {
      final release = KonektizenMobileRelease.fromJson({
        'versionName': '1.1.0',
        'versionCode': 2,
        'releaseNotes': 'Improved citizen reporting.',
        'requiredForCurrentVersion': true,
        'downloadUrl': '/api/v1/mobile-releases/download/9',
        'sha256': 'abc123',
        'fileSize': 1024,
      }, origin: Uri.parse('https://montalban.c3.aitelligenz.com:5175'));

      expect(release.versionName, '1.1.0');
      expect(release.versionCode, 2);
      expect(release.required, isTrue);
      expect(
        release.downloadUrl,
        'https://montalban.c3.aitelligenz.com:5175/api/v1/mobile-releases/download/9',
      );
      expect(release.sha256, 'abc123');
      expect(release.fileSize, 1024);
    });

    test('rejects a manifest without a download URL', () {
      expect(
        () => KonektizenMobileRelease.fromJson(const {
          'versionName': '1.1.0',
          'versionCode': 2,
        }, origin: Uri.parse('https://c3.aitelligenz.com')),
        throwsFormatException,
      );
    });
  });
}

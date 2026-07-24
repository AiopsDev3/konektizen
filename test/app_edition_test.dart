import 'package:flutter_test/flutter_test.dart';
import 'package:konektizen/core/config/app_edition.dart';
import 'package:konektizen/features/sos/sos_service.dart';

void main() {
  tearDown(() => AppFeatures.configure(AppEdition.standard));

  test('standard Konektizen keeps SOS calls enabled', () {
    AppFeatures.configure(AppEdition.standard);

    expect(AppFeatures.sosCallsEnabled, isTrue);
    expect(AppFeatures.isLaoag, isFalse);
  });

  test('Laoag Konektizen disables SOS calls only for that edition', () {
    AppFeatures.configure(AppEdition.laoag);

    expect(AppFeatures.sosCallsEnabled, isFalse);
    expect(AppFeatures.isLaoag, isTrue);
  });

  test('Laoag edition blocks SOS network actions', () async {
    AppFeatures.configure(AppEdition.laoag);
    final service = SOSService();

    expect(
      await service.sendSOS(
        latitude: 18.198,
        longitude: 120.594,
        hotlineNumber: '911',
      ),
      isNull,
    );
    expect(
      await service.startVideoCall(
        latitude: 18.198,
        longitude: 120.594,
        hotlineNumber: '911',
      ),
      isNull,
    );
  });
}

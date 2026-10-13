import 'package:flutter_test/flutter_test.dart';
import 'package:waterflyiii/updater.dart';

void main() {
  test('AppUpdateInfo deserializes version.json correctly', () {
    final Map<String, dynamic> json = <String, dynamic>{
      'version': '1.3.0',
      'versionCode': 10300,
      'apkUrl': 'https://example.com/fireflytonic/fireflytonic-arm64-v8a.apk',
      'changelog': 'Soporte de actualizador in-app integrado.',
      'minSupportVersionCode': 10000,
    };

    final AppUpdateInfo info = AppUpdateInfo.fromJson(json);
    expect(info.version, equals('1.3.0'));
    expect(info.versionCode, equals(10300));
    expect(
      info.apkUrl,
      equals('https://example.com/fireflytonic/fireflytonic-arm64-v8a.apk'),
    );
    expect(info.changelog, equals('Soporte de actualizador in-app integrado.'));
    expect(info.minSupportVersionCode, equals(10000));
  });

  test('AppUpdateInfo handles alternative key names', () {
    final Map<String, dynamic> json = <String, dynamic>{
      'versionName': '1.2.1',
      'versionCode': 121,
      'downloadUrl': 'https://example.com/app.apk',
      'notes': 'Notas de actualización',
    };

    final AppUpdateInfo info = AppUpdateInfo.fromJson(json);
    expect(info.version, equals('1.2.1'));
    expect(info.versionCode, equals(121));
    expect(info.apkUrl, equals('https://example.com/app.apk'));
    expect(info.changelog, equals('Notas de actualización'));
  });

  test('UpdateChannel URLs and properties are configured correctly', () {
    expect(UpdateChannel.stable.defaultUrl, equals(defaultUpdateUrl));
    expect(UpdateChannel.beta.defaultUrl, equals(betaUpdateUrl));
    expect(UpdateChannel.stable.label, equals('Estable'));
    expect(UpdateChannel.beta.label, equals('Beta'));
  });
}

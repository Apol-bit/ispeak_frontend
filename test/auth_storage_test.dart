import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispeak/services/auth_service.dart';

void main() {
  test('secure session can be saved and cleared', () async {
    FlutterSecureStorage.setMockInitialValues({});

    await AuthService.saveSession(
      token: 'test-token',
      userId: 'user-id',
      role: 'user',
    );
    expect(await AuthService.getToken(), 'test-token');

    await AuthService.clearSession();
    expect(await AuthService.getToken(), isNull);
  });
}

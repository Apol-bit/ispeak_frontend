import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ispeak/main.dart';

void main() {
  testWidgets('app opens on the iSpeak welcome screen', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('iSpeak'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}

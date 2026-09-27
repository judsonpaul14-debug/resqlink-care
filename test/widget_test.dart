import 'package:flutter_test/flutter_test.dart';
import 'package:resqlink_care/main.dart';

void main() {
  testWidgets('ResQLink Care loads successfully', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ResQLinkApp());

    expect(find.text('ResQLink Care'), findsOneWidget);
    expect(find.text('Community status'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Emergency overview'), findsOneWidget);
  });
}
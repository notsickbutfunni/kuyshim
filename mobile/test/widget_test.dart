import 'package:flutter_test/flutter_test.dart';
import 'package:kuyshim/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KuyshimApp());
    expect(find.text('Kuyshim'), findsAny);
  });
}

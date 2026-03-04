import 'package:flutter_test/flutter_test.dart';

import 'package:volvoxgrid_example/main.dart';

void main() {
  testWidgets('VolvoxGrid demo app renders core chrome',
      (WidgetTester tester) async {
    await tester.pumpWidget(const VolvoxGridDemoApp());
    await tester.pump();

    expect(find.text('VolvoxGrid Demo'), findsOneWidget);
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Hierarchy'), findsOneWidget);
    expect(find.text('Stress'), findsOneWidget);
  });
}

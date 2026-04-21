import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:volvoxgrid_example/main.dart';

void main() {
  testWidgets('VolvoxGrid demo app renders core chrome',
      (WidgetTester tester) async {
    await tester.pumpWidget(const VolvoxGridDemoApp());
    await tester.pump();
    await tester.pump(Duration.zero);

    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Hierarchy'), findsOneWidget);
    expect(find.text('Stress'), findsOneWidget);
    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('Debug'), findsOneWidget);
    expect(find.text('Cache'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}

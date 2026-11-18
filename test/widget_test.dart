import 'package:flutter_test/flutter_test.dart';

import 'package:e_archive/app.dart';

void main() {
  testWidgets('renders the role-choice landing page after splash', (
    tester,
  ) async {
    await tester.pumpWidget(const EArchiveApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Student records,\norganized.'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
  });
}

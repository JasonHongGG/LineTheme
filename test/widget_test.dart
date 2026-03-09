import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:line_theme/app/line_theme_app.dart';

void main() {
  testWidgets('renders theme tester shell', (WidgetTester tester) async {
    await tester.pumpWidget(const LineThemeApp());

    expect(find.text('Shizuku 授權'), findsOneWidget);
    expect(find.text('選擇槽位'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('主題網址'), findsOneWidget);
  });
}

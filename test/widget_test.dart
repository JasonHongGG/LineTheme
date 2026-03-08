import 'package:flutter_test/flutter_test.dart';

import 'package:line_theme_tester/main.dart';

void main() {
  testWidgets('renders theme tester shell', (WidgetTester tester) async {
    await tester.pumpWidget(const LineThemeTesterApp());

    expect(find.text('LINE Theme Tester'), findsOneWidget);
    expect(find.text('1. Theme 目標槽位'), findsOneWidget);
    expect(find.text('2. 輸入主題網址'), findsOneWidget);
  });
}

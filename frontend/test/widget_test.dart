import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('renders the camera dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartCityAIApp(cameras: []));

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}

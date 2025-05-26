// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';

import 'package:network_diagnostic_app/main.dart';

void main() {
  testWidgets('App should start correctly', (WidgetTester tester) async {
    // Mock cameras for testing
    final List<CameraDescription> mockCameras = [];
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(cameras: mockCameras));

    // Verify that the home screen loads with expected text
    expect(find.text('Olá, Técnico!'), findsOneWidget);
    expect(find.text('Relate o problema encontrado'), findsOneWidget);
    expect(find.text('Gravar Relato'), findsOneWidget);
    expect(find.text('Iniciar Gravação'), findsOneWidget);
  });

  testWidgets('Navigation button should be present', (WidgetTester tester) async {
    final List<CameraDescription> mockCameras = [];
    
    await tester.pumpWidget(MyApp(cameras: mockCameras));

    // Verify that the main button is present
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.text('Iniciar Gravação'), findsOneWidget);
  });
}
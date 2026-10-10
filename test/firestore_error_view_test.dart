import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/ui/feedback/friendly_error.dart';
import 'package:vetbiz_pro/widgets/firestore_error_view.dart';

Future<void> _show(WidgetTester tester, Object? error) => tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppColorTheme.kilimanjaro, Brightness.light),
      home: Scaffold(body: SingleChildScrollView(child: FirestoreErrorView(error: error))),
    ));

/// FirestoreErrorView never shows the raw error first: a friendly sentence,
/// the index link when there is one, and the technical text behind Details.
void main() {
  testWidgets('a known Firestore error shows its friendly sentence, raw text only under Details', (tester) async {
    final error = FirebaseException(
        plugin: 'cloud_firestore', code: 'permission-denied', message: '[cloud_firestore/permission-denied] raw text');
    await _show(tester, error);

    expect(find.text(FriendlyError.noPermission), findsOneWidget);
    expect(find.textContaining('cloud_firestore'), findsNothing);

    await tester.tap(find.text('Details'));
    await tester.pump();
    expect(find.textContaining('permission-denied: [cloud_firestore/permission-denied] raw text'), findsOneWidget);
    expect(find.text('Hide details'), findsOneWidget);
  });

  testWidgets('an unknown error shows the fallback, never the exception text', (tester) async {
    await _show(tester, Exception('[boom] at foo.dart:12'));

    expect(find.text(FriendlyError.fallback), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('foo.dart'), findsNothing);
  });

  testWidgets('a missing-index error keeps its explanation and Create Missing Index button', (tester) async {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'failed-precondition',
      message: 'The query requires an index. You can create it here: https://console.firebase.google.com/project/x/indexes?create=abc',
    );
    await _show(tester, error);

    expect(find.text('This view needs a one-time database index to be created first.'), findsOneWidget);
    expect(find.text('Create Missing Index'), findsOneWidget);
    expect(find.textContaining('https://'), findsNothing);

    await tester.tap(find.text('Details'));
    await tester.pump();
    expect(find.textContaining('https://console.firebase.google.com'), findsOneWidget);
  });

  testWidgets('no error object still shows a sentence and no Details', (tester) async {
    await _show(tester, null);
    expect(find.text(FriendlyError.fallback), findsOneWidget);
    expect(find.text('Details'), findsNothing);
  });
}

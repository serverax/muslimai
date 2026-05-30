import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina_frontend/services/api_service.dart' show Citation;
import 'package:sakina_frontend/widgets/citation_widget.dart';

void main() {
  testWidgets('CitationBadge renders title/author and opens a detail dialog',
      (tester) async {
    final c = Citation(
      id: 'citation-1',
      title: 'Sahih al-Bukhari',
      author: 'al-Bukhari',
      chapter: 'Book of Faith',
      authenticityGrade: 'Sahih',
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: CitationBadge(source: c)))),
    );

    expect(find.text('Sahih al-Bukhari'), findsOneWidget);
    expect(find.text('by al-Bukhari'), findsOneWidget);

    await tester.tap(find.byType(CitationBadge));
    await tester.pumpAndSettle();

    // Dialog shows the field values.
    expect(find.text('Book of Faith'), findsOneWidget);
    expect(find.text('Sahih'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}

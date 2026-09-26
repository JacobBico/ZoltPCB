import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/data/repositories/symbol_library_repository.dart';
import 'package:zolt/features/home/home_screen.dart';
import 'package:zolt/features/home/whats_new.dart';
import 'package:zolt/features/learn/learn_library.dart';
import 'package:zolt/features/learn/markdown_view.dart';
import 'package:zolt/features/project/project_screen.dart';

import '../helpers/library_fixture.dart';
import '../helpers/pump_app.dart';

void main() {
  group('the changelog', () {
    test('is read a version at a time, newest first', () {
      final releases = Release.parse('''
## 1.1.0 — Silkscreen

- Fonts
- Pictures

## 1.0.0 — The first

- Everything else
''');
      expect(releases.map((r) => r.version), ['1.1.0', '1.0.0']);
      expect(releases.first.title, 'Silkscreen');
      expect(releases.first.notes, contains('- Pictures'));
      expect(releases.first.notes, isNot(contains('Everything else')));
    });

    test('the one the app ships says what this version is', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final releases = Release.parse(
        await rootBundle.loadString('assets/changelog.md'),
      );
      expect(releases, isNotEmpty);
      expect(releases.first.notes, isNotEmpty);
    });
  });

  group('Learn', () {
    test('a note is titled by its first heading', () {
      final note = LearnLibrary.parse(
        'assets/learn/decoupling/02-values.md',
        'decoupling',
        '# Choosing values\n\nSmall and close.',
      );
      expect(note.title, 'Choosing values');
      expect(note.text, 'Small and close.');
    });

    test('every category the app ships loads, with its notes', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final library = await LearnLibrary.load(rootBundle);
      expect(library.categories, hasLength(2));
      for (final category in library.categories) {
        expect(category.articles, isNotEmpty, reason: category.id);
        expect(category.short, isNotEmpty);
      }
    });

    test('every picture a note shows is there, and draws', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final library = await LearnLibrary.load(rootBundle);
      var pictures = 0;
      for (final category in library.categories) {
        for (final note in category.articles) {
          final dir = note.path.substring(0, note.path.lastIndexOf('/'));
          for (final match in RegExp(
            r'^!\[.*\]\((.+)\)$',
            multiLine: true,
          ).allMatches(note.text)) {
            final svg = await rootBundle.loadString('$dir/${match[1]}');
            final info = await vg.loadPicture(SvgStringLoader(svg), null);
            expect(info.size.isEmpty, isFalse, reason: match[1]);
            info.picture.dispose();
            pictures++;
          }
        }
      }
      expect(pictures, greaterThanOrEqualTo(5));
    });

    testWidgets('a picture line shows the picture and its caption', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarkdownView(
              '![Two plates](images/capacitor-structure.svg)',
              assetDir: 'assets/learn/capacitors',
            ),
          ),
        ),
      );
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('Two plates'), findsOneWidget);
    });

    testWidgets('Markdown draws its headings, lists and tips', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarkdownView('''
## Placing them

- **Close** to the pin
- Short `via` to ground

> Measure twice.
'''),
          ),
        ),
      );
      expect(find.text('Placing them'), findsOneWidget);
      expect(find.text('•'), findsNWidgets(2));
      expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
      expect(
        find.textContaining('Measure twice.', findRichText: true),
        findsOneWidget,
      );
    });
  });

  testAppWithStorage(
    'home shows the getting-started list, then where you left off',
    (tester, db, storage) async {
      await pumpApp(tester, const HomeScreen(), database: db, storage: storage);
      expect(find.textContaining('GET STARTED — 0 OF 3'), findsOneWidget);

      // With libraries and a project, the list gives way to the project.
      await SymbolLibraryRepository(
        db,
        storage,
      ).import(fileName: 'Device.kicad_sym', bytes: libraryBytes());
      final project = await ProjectRepository(db).create(name: 'Preamp');
      await settleApp(tester);
      expect(find.textContaining('GET STARTED'), findsNothing);
      expect(find.text('CONTINUE WHERE YOU LEFT OFF'), findsOneWidget);
      expect(find.text('Preamp'), findsOneWidget);

      // It reopens on the schematic, the section a new project starts in.
      await tester.tap(find.byKey(ValueKey('recent-${project.id}')));
      await settleApp(tester);
      expect(find.byType(ProjectScreen), findsOneWidget);
      expect(find.text('Schematic'), findsWidgets);
    },
  );
}

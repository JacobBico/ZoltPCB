import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/features/project/component_sidebar.dart';
import 'package:hintpcb/features/project/schematic_panel.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/core/widgets/app_logo.dart';
import 'package:hintpcb/core/widgets/app_top_bar.dart';
import 'package:hintpcb/features/project/project_screen.dart';
import 'package:hintpcb/features/home/home_screen.dart';
import 'package:hintpcb/features/projects/projects_panel.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  testApp('shows an empty state before any project exists', (tester, db) async {
    await pumpApp(tester, const HomeScreen(), database: db);

    expect(find.text('No projects yet'), findsOneWidget);
    expect(find.text('NEW PROJECT'), findsNWidgets(2));
  });

  testApp('the header clears the status bar and a display cutout', (
    tester,
    db,
  ) async {
    // A landscape phone with a notch on the left and a gesture bar below.
    await pumpApp(
      tester,
      const HomeScreen(),
      database: db,
      padding: const EdgeInsets.fromLTRB(48, 32, 24, 16),
    );

    // The bar's background reaches the physical edges...
    final header = tester.getRect(find.byType(AppTopBar));
    expect(header.left, 0);
    expect(header.top, 0);

    // ...while its contents clear the status bar and the cutout.
    final title = tester.getRect(find.byType(AppLogo));
    expect(title.top, greaterThanOrEqualTo(32));
    expect(title.left, greaterThanOrEqualTo(48));

    // The action sits in the top-right corner, just inside the cutout.
    // byWidgetPredicate rather than byType: FilledButton.icon builds a
    // private subclass that byType would not match.
    final action = find
        .ancestor(
          of: find.text('NEW PROJECT').first,
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        )
        .first;
    final screenWidth = landscapePhone.width / 2; // physical px / dpr
    expect(tester.getRect(action).right, closeTo(screenWidth - 24 - 8, 1));

    // Body content stays clear of the cutout too.
    final body = tester.getRect(find.text('No projects yet'));
    expect(body.left, greaterThanOrEqualTo(48));
  });

  testApp('lists projects with their part and net counts', (tester, db) async {
    final projects = ProjectRepository(db);
    final parts = PartRepository(db);
    final nets = NetRepository(db);
    final project = await projects.create(name: 'Preamp', description: 'MM');
    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec());
    await nets.connectPins(r1.pins.first.id, r2.pins.first.id);
    await projects.create(name: 'Bench PSU');

    await pumpApp(tester, const HomeScreen(), database: db);

    expect(find.text('Preamp'), findsOneWidget);
    expect(find.text('MM'), findsOneWidget);
    expect(find.text('Bench PSU'), findsOneWidget);
    expect(find.text('A4'), findsNWidgets(2));

    // Preamp: 2 parts, 1 net. Bench PSU: none of either.
    // Scoped to the table, because the navigation rail also shows counts.
    Finder inTable(String text) => find.descendant(
      of: find.byType(ProjectsPanel),
      matching: find.text(text),
    );
    expect(inTable('2'), findsOneWidget);
    expect(inTable('1'), findsOneWidget);
    expect(inTable('0'), findsNWidgets(2));
  });

  testApp('the new project dialog rejects a blank name', (tester, db) async {
    final projects = ProjectRepository(db);
    await pumpApp(tester, const HomeScreen(), database: db);

    await tester.tap(find.text('NEW PROJECT').first);
    await tester.pumpAndSettle();
    expect(find.text('New project'), findsOneWidget);

    await tester.tap(find.text('CREATE'));
    await tester.pumpAndSettle();

    expect(find.text('A project needs a name'), findsOneWidget);
    expect(await projects.getAll(), isEmpty);
  });

  testApp('creating a project persists it and opens the workspace', (
    tester,
    db,
  ) async {
    final projects = ProjectRepository(db);
    await pumpApp(tester, const HomeScreen(), database: db);

    await tester.tap(find.text('NEW PROJECT').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Line driver',
    );
    await tester.tap(find.text('CREATE'));
    await tester.pumpAndSettle();

    final stored = await projects.getAll();
    expect(stored.map((p) => p.name), ['Line driver']);
    expect(find.byType(ProjectScreen), findsOneWidget);

    // A brand-new project opens where its first job is — the schematic,
    // with the component list already out — not on an overview that would
    // be a page of zeros.
    expect(find.byType(SchematicPanel), findsOneWidget);
    expect(find.byType(ComponentSidebar), findsOneWidget);
  });

  testApp('deleting a project asks first, then removes it', (tester, db) async {
    final projects = ProjectRepository(db);
    await projects.create(name: 'Scratch');
    await pumpApp(tester, const HomeScreen(), database: db);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete "Scratch"?'), findsOneWidget);

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(await projects.getAll(), hasLength(1));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();

    expect(await projects.getAll(), isEmpty);
    expect(find.text('No projects yet'), findsOneWidget);
  });
}

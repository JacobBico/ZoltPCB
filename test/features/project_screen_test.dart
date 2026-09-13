import 'package:flutter_test/flutter_test.dart';
import 'package:hintpcb/data/repositories/net_repository.dart';
import 'package:hintpcb/data/repositories/part_repository.dart';
import 'package:hintpcb/data/repositories/project_repository.dart';
import 'package:hintpcb/domain/models/models.dart';
import 'package:hintpcb/core/widgets/panel.dart';
import 'package:hintpcb/features/project/project_screen.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  testApp('shows the sheet properties of the project', (tester, db) async {
    final project = await ProjectRepository(db).create(
      name: 'Preamp',
      description: 'MM phono',
      paper: PaperSize.a3,
      company: 'Bench',
      revision: 'B',
    );

    await pumpApp(
      tester,
      ProjectScreen(projectId: project.id),
      database: db,
    );

    expect(find.text('Preamp'), findsOneWidget);
    // The top bar names the section now that the rail is hidden; the
    // description moved into the sheet panel. `hitTestable` matters here:
    // the closed rail stays in the tree so it can slide, so its label is
    // findable even though nobody can see or touch it.
    expect(find.text('Overview').hitTestable(), findsOneWidget);
    expect(find.text('MM phono'), findsOneWidget);
    expect(find.text('A3  420 × 297 mm'), findsOneWidget);
    expect(find.text('Bench'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testApp('counts components, nets and unconnected pins', (tester, db) async {
    final project = await ProjectRepository(db).create(name: 'Counts');
    final parts = PartRepository(db);
    final nets = NetRepository(db);

    // Two resistors: four pins. One net joins two of them, so two pins are
    // left unconnected.
    final r1 = await parts.addPart(project.id, resistorSpec());
    final r2 = await parts.addPart(project.id, resistorSpec());
    await nets.connectPins(r1.pins.first.id, r2.pins.first.id);

    await pumpApp(
      tester,
      ProjectScreen(projectId: project.id),
      database: db,
    );

    expect(find.text('components'), findsOneWidget);
    expect(find.text('nets'), findsOneWidget);
    expect(find.text('unconnected pins'), findsOneWidget);

    // Scoped to the counter panels, because the rail also shows counts.
    Finder counter(String text) =>
        find.descendant(of: find.byType(Panel), matching: find.text(text));
    expect(counter('2'), findsNWidgets(2)); // components and unconnected
    expect(counter('1'), findsOneWidget); // nets
  });

  testAppWithStorage('the rail reaches every section', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Empty');

    await pumpApp(
      tester,
      ProjectScreen(projectId: project.id),
      database: db,
      storage: storage,
    );

    await openRail(tester);
    await tester.tap(find.text('Components'));
    await settleApp(tester);
    expect(find.text('No components yet'), findsOneWidget);

    await openRail(tester);
    await tester.tap(find.text('Nets'));
    await settleApp(tester);
    expect(find.text('Nothing to connect yet'), findsOneWidget);
  });

  testAppWithStorage('the rail closes once a section is chosen', (
    tester,
    db,
    storage,
  ) async {
    final project = await ProjectRepository(db).create(name: 'Empty');

    await pumpApp(
      tester,
      ProjectScreen(projectId: project.id),
      database: db,
      storage: storage,
    );

    // Hidden to begin with: the section fills the screen.
    expect(find.text('Export').hitTestable(), findsNothing);

    await openRail(tester);
    expect(find.text('Export').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Export'));
    await settleApp(tester);

    expect(
      find.text('Components').hitTestable(),
      findsNothing,
      reason: 'the rail slides away again once a section is chosen',
    );
  });

  testApp('reports a project that has been deleted', (tester, db) async {
    final projects = ProjectRepository(db);
    final project = await projects.create(name: 'Doomed');

    await pumpApp(
      tester,
      ProjectScreen(projectId: project.id),
      database: db,
    );
    expect(find.text('Doomed'), findsOneWidget);

    await projects.delete(project.id);
    await tester.pumpAndSettle();

    expect(find.text('This project no longer exists'), findsOneWidget);
  });
}

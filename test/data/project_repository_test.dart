import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/domain/models/models.dart';

import '../helpers/fixtures.dart';

void main() {
  late AppDatabase db;
  late ProjectRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = ProjectRepository(db);
  });

  tearDown(() async => db.close());

  test('creates a project with generated id and timestamps', () async {
    final project = await repo.create(name: 'Preamp');

    expect(project.id, isNotEmpty);
    expect(project.name, 'Preamp');
    expect(project.paper, PaperSize.a4);
    expect(project.createdAt, project.modifiedAt);

    final stored = await repo.getById(project.id);
    expect(stored, project);
  });

  test('trims whitespace from names', () async {
    final project = await repo.create(name: '  Preamp  ');
    expect(project.name, 'Preamp');
  });

  test('lists projects most recently modified first', () async {
    final first = await repo.create(name: 'First');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await repo.create(name: 'Second');

    var all = await repo.getAll();
    expect(all.map((p) => p.id), [second.id, first.id]);

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.touch(first.id);

    all = await repo.getAll();
    expect(all.map((p) => p.id), [first.id, second.id]);
  });

  test('rename updates the name and bumps modifiedAt', () async {
    final project = await repo.create(name: 'Old');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.rename(project.id, 'New');

    final stored = await repo.getById(project.id);
    expect(stored!.name, 'New');
    expect(stored.modifiedAt.isAfter(project.modifiedAt), isTrue);
  });

  test('update persists paper size and metadata', () async {
    final project = await repo.create(name: 'Board');
    await repo.update(
      project.copyWith(
        paper: PaperSize.a3,
        company: 'Bench',
        revision: 'B',
        description: 'Analog front end',
      ),
    );

    final stored = await repo.getById(project.id);
    expect(stored!.paper, PaperSize.a3);
    expect(stored.company, 'Bench');
    expect(stored.revision, 'B');
    expect(stored.description, 'Analog front end');
  });

  test('deleting a project cascades to its parts and pins', () async {
    final parts = PartRepository(db);
    final project = await repo.create(name: 'Doomed');
    await parts.addPart(project.id, resistorSpec());

    expect(await parts.getPartsWithDetails(project.id), hasLength(1));

    await repo.delete(project.id);

    expect(await repo.getById(project.id), isNull);
    expect(await db.select(db.parts).get(), isEmpty);
    expect(await db.select(db.partPins).get(), isEmpty);
    expect(await db.select(db.partUnits).get(), isEmpty);
  });

  test('watchAll emits on change', () async {
    final emissions = <List<Project>>[];
    final sub = repo.watchAll().listen(emissions.add);

    await repo.create(name: 'A');
    await pumpEventQueue();

    expect(emissions.last.map((p) => p.name), ['A']);
    await sub.cancel();
  });
}

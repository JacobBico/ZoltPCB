import 'package:flutter_test/flutter_test.dart';
import 'package:zolt/data/db/database.dart';
import 'package:zolt/data/repositories/net_repository.dart';
import 'package:zolt/data/repositories/part_repository.dart';
import 'package:zolt/data/repositories/project_repository.dart';
import 'package:zolt/domain/export/schematic_document.dart';
import 'package:zolt/domain/models/models.dart';
import 'package:zolt/kicad/bom_writer.dart';

import '../helpers/fixtures.dart';

void main() {
  late AppDatabase db;
  late ProjectRepository projects;
  late PartRepository parts;
  late Project project;

  setUp(() async {
    db = AppDatabase.memory();
    projects = ProjectRepository(db);
    parts = PartRepository(db);
    project = await projects.create(name: 'BOM');
  });

  tearDown(() async => db.close());

  Future<List<BomLine>> lines() async =>
      BomWriter.group(await parts.getPartsWithDetails(project.id));

  Future<String> csv() async => BomWriter.write(
    SchematicDocument(
      project: project,
      parts: await parts.getPartsWithDetails(project.id),
      nets: await NetRepository(db).getNets(project.id),
    ),
  );

  group('grouping', () {
    test('identical parts share a line with a quantity', () async {
      await parts.addPart(project.id, resistorSpec(value: '10k'));
      await parts.addPart(project.id, resistorSpec(value: '10k'));
      await parts.addPart(project.id, resistorSpec(value: '4k7'));

      final result = await lines();
      expect(result, hasLength(2));

      final tenK = result.firstWhere((l) => l.value == '10k');
      expect(tenK.quantity, 2);
      expect(tenK.referenceList, 'R1, R2');
    });

    test('parts differing only by footprint stay apart', () async {
      final a = await parts.addPart(project.id, resistorSpec(value: '10k'));
      final b = await parts.addPart(project.id, resistorSpec(value: '10k'));
      await parts.updatePart(a.part.copyWith(footprint: 'R_0402'));
      await parts.updatePart(b.part.copyWith(footprint: 'R_0805'));

      expect(await lines(), hasLength(2));
    });

    test('a component ID is its own column, and splits a line', () async {
      final a = await parts.addPart(project.id, resistorSpec(value: '10k'));
      final b = await parts.addPart(project.id, resistorSpec(value: '10k'));
      await parts.addPart(project.id, resistorSpec(value: '10k'));
      await parts.updatePart(a.part.copyWith(componentId: 'C25804'));
      await parts.updatePart(b.part.copyWith(componentId: 'C25804'));

      // Two ordered by C25804, and one with no number of its own.
      final result = await lines();
      expect(result.map((l) => (l.quantity, l.componentId)), [
        (2, 'C25804'),
        (1, ''),
      ]);

      final text = await csv();
      expect(text.split('\n').first, contains('LCSC Part #'));
      expect(text, contains('C25804'));
    });

    test('a part kept out of the BOM does not appear', () async {
      await parts.addPart(project.id, resistorSpec());
      await parts.addPart(project.id, groundSpec());

      final result = await lines();
      expect(result, hasLength(1));
      expect(result.single.references, ['R1']);
    });

    test('do-not-populate parts are listed and flagged', () async {
      final fitted = await parts.addPart(project.id, resistorSpec());
      final unfitted = await parts.addPart(project.id, resistorSpec());
      await parts.updatePart(unfitted.part.copyWith(dnp: true));

      final result = await lines();
      // Same value, but one is fitted and one is not, so they are separate
      // lines: a buyer needs a different quantity for each.
      expect(result, hasLength(2));
      expect(result.where((l) => l.dnp).single.references, ['R2']);
      expect(result.where((l) => !l.dnp).single.references, [
        fitted.part.reference,
      ]);
    });

    test('a multi-unit package is one line, not one per unit', () async {
      await parts.addPart(project.id, dualOpampSpec());

      final result = await lines();
      expect(result, hasLength(1));
      expect(result.single.quantity, 1);
      expect(result.single.references, ['U1']);
    });

    test('designators sort numerically, not lexically', () async {
      for (var i = 0; i < 11; i++) {
        await parts.addPart(project.id, resistorSpec());
      }

      final result = await lines();
      expect(result.single.references.take(3), ['R1', 'R2', 'R3']);
      expect(result.single.references.last, 'R11');
    });

    test('lines are ordered by their first designator', () async {
      await parts.addPart(project.id, dualOpampSpec());
      await parts.addPart(project.id, resistorSpec());

      final result = await lines();
      expect(result.map((l) => l.references.first), ['R1', 'U1']);
    });
  });

  group('csv', () {
    test('starts with a header row', () async {
      final text = await csv();
      expect(text.split('\n').first, BomWriter.columns.join(','));
    });

    test('writes one row per line, numbered from one', () async {
      await parts.addPart(project.id, resistorSpec(value: '10k'));
      await parts.addPart(project.id, resistorSpec(value: '10k'));

      final rows = (await csv()).trim().split('\n');
      expect(rows, hasLength(2));
      expect(rows[1], startsWith('1,2,"R1, R2",10k,'));
    });

    test('quotes fields containing commas', () async {
      await parts.addPart(project.id, resistorSpec());
      await parts.addPart(project.id, resistorSpec());

      expect(await csv(), contains('"R1, R2"'));
    });

    test('escapes quotes by doubling them', () {
      expect(BomWriter.escape('10k 1% "tight"'), '"10k 1% ""tight"""');
      expect(BomWriter.escape('plain'), 'plain');
      expect(BomWriter.escape('a,b'), '"a,b"');
    });

    test('an empty project still produces a usable file', () async {
      final text = await csv();
      expect(text.trim(), BomWriter.columns.join(','));
    });

    test('every row has the same number of columns as the header', () async {
      final added = await parts.addPart(project.id, resistorSpec());
      await parts.updatePart(
        added.part.copyWith(
          value: 'has,comma',
          description: 'has "quotes"',
          footprint: 'Resistor_SMD:R_0603',
        ),
      );

      final rows = (await csv()).trim().split('\n');
      for (final row in rows) {
        expect(countCsvFields(row), BomWriter.columns.length, reason: row);
      }
    });
  });
}

/// Counts CSV fields, respecting quoting — a plain split on commas would
/// not notice a value that legitimately contains one.
int countCsvFields(String row) {
  var fields = 1;
  var inQuotes = false;
  for (var i = 0; i < row.length; i++) {
    final char = row[i];
    if (char == '"') {
      if (inQuotes && i + 1 < row.length && row[i + 1] == '"') {
        i++;
        continue;
      }
      inQuotes = !inQuotes;
    } else if (char == ',' && !inQuotes) {
      fields++;
    }
  }
  return fields;
}

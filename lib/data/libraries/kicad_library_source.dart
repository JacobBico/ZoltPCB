import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../kicad/sexpr/sexpr_parser.dart';

/// Symbols or footprints: the two libraries KiCad publishes separately.
enum RemoteLibraryKind { symbols, footprints }

/// One library KiCad publishes, as its index lists it.
class RemoteLibrary {
  const RemoteLibrary({
    required this.kind,
    required this.name,
    this.description = '',
  });

  final RemoteLibraryKind kind;

  /// The nickname: `Device`, `Resistor_SMD`. Also what it is called here
  /// once imported, so the `lib_id`s match the desktop's.
  final String name;
  final String description;

  @override
  bool operator ==(Object other) =>
      other is RemoteLibrary && other.kind == kind && other.name == name;

  @override
  int get hashCode => Object.hash(kind, name);

  @override
  String toString() => 'RemoteLibrary(${kind.name}:$name)';
}

/// Where KiCad's own libraries are published, and how to read their index.
///
/// The app ships with no component data; these are fetched from KiCad's
/// official repositories only when the user asks, the same libraries a
/// desktop install comes with. Pinned to a KiCad 9 release, because the app
/// writes KiCad 9 files and symbols are copied into them.
abstract final class KicadLibrarySource {
  static const version = '9.0.9.1';

  static const _base = 'https://gitlab.com/kicad/libraries';

  /// The index of every library of [kind]: `sym-lib-table` or
  /// `fp-lib-table`, each entry with a name and a description.
  static Uri indexUri(RemoteLibraryKind kind) => switch (kind) {
    RemoteLibraryKind.symbols => Uri.parse(
      '$_base/kicad-symbols/-/raw/$version/sym-lib-table',
    ),
    RemoteLibraryKind.footprints => Uri.parse(
      '$_base/kicad-footprints/-/raw/$version/fp-lib-table',
    ),
  };

  /// A symbol library is one `.kicad_sym` file; a footprint library is a
  /// `.pretty` folder, which comes as a zip of just that folder.
  static Uri downloadUri(RemoteLibrary library) => switch (library.kind) {
    RemoteLibraryKind.symbols => Uri.parse(
      '$_base/kicad-symbols/-/raw/$version/'
      '${Uri.encodeComponent(library.name)}.kicad_sym',
    ),
    RemoteLibraryKind.footprints => Uri.parse(
      '$_base/kicad-footprints/-/archive/$version/'
      'kicad-footprints-$version.zip'
      '?path=${Uri.encodeQueryComponent('${library.name}.pretty')}',
    ),
  };

  /// The libraries a `sym-lib-table` or `fp-lib-table` lists, by name.
  static List<RemoteLibrary> parseIndex(RemoteLibraryKind kind, String text) {
    final root = SExprParser.parseDocument(text);
    return [
      for (final lib in root.children('lib'))
        if (lib.childAtom('name') case final name? when name.isNotEmpty)
          RemoteLibrary(
            kind: kind,
            name: name,
            description: lib.childAtom('descr') ?? '',
          ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// A small set that covers most hobby boards: passives, the common
  /// semiconductors, regulators, connectors and the usual packages.
  /// Names the index does not list are simply not offered.
  static const essentials = {
    RemoteLibraryKind.symbols: {
      'Device',
      'power',
      'Connector',
      'Connector_Generic',
      'Diode',
      'LED',
      'Transistor_BJT',
      'Transistor_FET',
      'Regulator_Linear',
      'Regulator_Switching',
      'Amplifier_Operational',
      'Switch',
      'Timer',
      'Interface_USB',
      'Mechanical',
    },
    RemoteLibraryKind.footprints: {
      'Resistor_SMD',
      'Resistor_THT',
      'Capacitor_SMD',
      'Capacitor_THT',
      'Inductor_SMD',
      'Diode_SMD',
      'Diode_THT',
      'LED_SMD',
      'LED_THT',
      'Package_TO_SOT_SMD',
      'Package_TO_SOT_THT',
      'Package_SO',
      'Package_DIP',
      'Package_DFN_QFN',
      'Package_QFP',
      'Connector_PinHeader_2.54mm',
      'Connector_PinSocket_2.54mm',
      'Connector_USB',
      'Button_Switch_SMD',
      'Button_Switch_THT',
      'Crystal',
      'MountingHole',
      'TestPoint',
    },
  };
}

/// Fetches bytes from the web. An interface so tests never touch the
/// network.
abstract class LibraryFetcher {
  /// The body at [uri]. [onProgress] hears bytes received so far, and the
  /// total when the server says it.
  Future<Uint8List> get(
    Uri uri, {
    void Function(int received, int? total)? onProgress,
  });
}

/// A plain HTTPS fetch, following redirects.
class HttpLibraryFetcher implements LibraryFetcher {
  HttpLibraryFetcher({HttpClient? client})
    : _client = client ?? HttpClient()
        ..connectionTimeout = const Duration(seconds: 20);

  final HttpClient _client;

  @override
  Future<Uint8List> get(
    Uri uri, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final request = await _client.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 60));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('Server answered ${response.statusCode}', uri: uri);
    }
    final total = response.contentLength >= 0 ? response.contentLength : null;
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 60))) {
      bytes.add(chunk);
      onProgress?.call(bytes.length, total);
    }
    return bytes.takeBytes();
  }
}

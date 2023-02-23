import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:process/process.dart';

const FileSystem fs = LocalFileSystem();
const ProcessManager pm = LocalProcessManager();

Future<void> main(List<String> args) async {
  final Directory flutterRepo = await _findFlutterRepo();
  final Directory flutterPkg = flutterRepo
    .childDirectory('packages')
    .childDirectory('flutter');
  print(flutterPkg);
  final Directory flutterLib = flutterPkg.childDirectory('lib');

  final Directory flute = await _findFlute();
  print(flute);
  _expect(
    flute.existsSync(),
    onFail: '${flute.path} does not exist.',
  );

  final Directory fluteLib = flute.childDirectory('lib');
  if (fluteLib.existsSync()) {
    fluteLib.deleteSync(recursive: true);
  }
  fluteLib.createSync();

  await _sync(flutterLib, fluteLib);
}

Future<void> _sync(Directory flutterLib, Directory fluteLib) async {
  final Iterable<File> dartSources = flutterLib.listSync(recursive: true).whereType<File>().where((File f) => f.path.endsWith('.dart'));
  for (final File file in dartSources) {
    final String relPath = p.relative(file.path, from: flutterLib.path);
    final File destFile = fs.file(p.join(fluteLib.path, relPath));

    String source = file.readAsStringSync();
    source = source.replaceAll("'package:flutter/", "'package:flute/");
    source = source.replaceAll('exception is NullThrownError', 'false');
    if (relPath == p.join('src', 'material', 'dialog.dart') ||
        relPath == p.join('src', 'material', 'navigation_rail.dart') ||
        relPath == p.join('src', 'material', 'switch.dart') ||
        relPath == p.join('src', 'widgets', 'icon.dart') ||
        relPath == p.join('src', 'material', 'time_picker.dart') ||
        relPath == p.join('src', 'material', 'time_picker_theme.dart')) {
      source = source.replaceAll("'dart:ui'", "'package:engine/ui.dart' hide TextStyle");
    } else {
      source = source.replaceAll("'dart:ui'", "'package:engine/ui.dart'");
    }

    if (relPath == p.join('src', 'foundation', 'math.dart')) {
      source = source.split('\n').where((String line) {
        return line.trim().isEmpty || line.trim().startsWith('//');
      }).join('\n');
      source += "\nexport 'package:engine/ui.dart' show clampDouble;";
    }

    if (relPath != p.join('src', 'foundation', 'bitfield.dart') &&
        relPath != p.join('src', 'foundation', 'platform.dart') &&
        relPath != p.join('src', 'services', 'platform_channel.dart')) {
      source = source.split('\n').map<String>((String line) {
        final int indexOfConditionalImport = line.indexOf(r'if (dart.library');
        if (indexOfConditionalImport == -1) {
          return line;
        }

        final int indexOfAs = line.indexOf(r' as ');

        if (indexOfAs != -1) {
          return '${line.substring(0, indexOfConditionalImport)} ${line.substring(indexOfAs)}';
        }

        return '${line.substring(0, indexOfConditionalImport)};';
      }).join('\n');
    }

    if (relPath == p.join('src', 'foundation', '_platform_web.dart')) {
      source = source.replaceAll('if (ui.debugEmulateFlutterTesterEnvironment as bool)', 'if (true)');
      source = source.replaceAll('domWindow.navigator.platform?.toLowerCase()', '"android"');
    }

    bool skip = false;
    if (destFile.existsSync()) {
      final String currentSrc = destFile.readAsStringSync();
      if (source == currentSrc) {
        skip = true;
      }
    }

    if (skip) {
      print('SKIP: $relPath');
    } else {
      print('SYNC: ${file.path} => ${destFile.path}');
      destFile.createSync(recursive: true);
      destFile.writeAsStringSync(source);
    }
  }
}

Future<Directory> _findFlutterRepo() async {
  final String whereOrWhich = io.Platform.operatingSystem == 'window'
    ? 'where' : 'which';
  final String where = (await pm.run(<String>[whereOrWhich, 'flutter'])).stdout as String;
  final String pathToFlutterBin = where.split('\n').first;
  final Directory bin = fs.directory(p.dirname(pathToFlutterBin));
  return bin.parent;
}

Future<Directory> _findFlute() async {
  final List<String> fluteDirectories = fs.currentDirectory.listSync()
    .whereType<Directory>()
    .map<String>((Directory dir) => p.basename(dir.path))
    .toList();
  _expect(
    <String>['benchmarks', 'engine', 'framework', 'script'].every(fluteDirectories.contains),
    onFail: 'This script must be run from the root of the flute repository.'
  );
  final Directory result = fs.directory(p.join(fs.currentDirectory.path, 'framework'));
  _expect(
    result.existsSync(),
    onFail: '${result.path} does not exist.'
  );
  return result;
}

void _expect(bool result, { required String onFail }) {
  if (!result) {
    throw StateError(onFail);
  }
}

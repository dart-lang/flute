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
    if (relPath == r'src\material\dialog.dart' ||
        relPath == r'src\material\navigation_rail.dart' ||
        relPath == r'src\material\switch.dart' ||
        relPath == r'src\widgets\icon.dart') {
      source = source.replaceAll("'dart:ui'", "'package:engine/ui.dart' hide TextStyle");
    } else {
      source = source.replaceAll("'dart:ui'", "'package:engine/ui.dart'");
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
  final String where = (await pm.run(<String>['where', 'flutter'])).stdout as String;
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

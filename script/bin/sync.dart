import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:process/process.dart';

final FileSystem fs = LocalFileSystem();
final ProcessManager pm = LocalProcessManager();

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

}

Future<Directory> _findFlutterRepo() async {
  final String where = (await pm.run(['where', 'flutter'])).stdout as String;
  final String pathToFlutterBin = where.split('\n').first;
  final Directory bin = fs.directory(p.dirname(pathToFlutterBin));
  return bin.parent;
}

Future<Directory> _findFlute() async {
  final List<String> fluteDirectories = fs.currentDirectory.listSync()
    .whereType<Directory>()
    .map<String>((dir) => p.basename(dir.path))
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

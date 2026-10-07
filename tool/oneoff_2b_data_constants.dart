// ONE-OFF (Phase 2, step 2B). Delete after step 2B is done.
//
// Mechanical, unambiguous replacements only:
//   .collection('sales')      -> .collection(Collections.sales)
//   .collectionGroup('users') -> .collectionGroup(Collections.users)
//   'facilityId' (and status, role, userId, createdAt, updatedAt) as a whole
//   string literal -> Fields.facilityId ...
// and adds the relative import each file then needs. The stored strings do
// not change: the constants hold the same text.
//
// Roles and statuses are NOT done here: the same word ('active', 'pending')
// is also a subscription or payment status, so those are done by hand.
//
//   dart run tool/oneoff_2b_data_constants.dart <file or folder> ...
import 'dart:io';

final _collectionDecl = RegExp(r"static const String (\w+) = '([^']+)';");
final _collectionCall = RegExp(r"\.(collection|collectionGroup)\('([^'$]+)'\)");
const _fields = ['facilityId', 'status', 'role', 'userId', 'createdAt', 'updatedAt'];
// A whole single-quoted literal, not part of a longer string or identifier.
final _fieldLiteral = RegExp("(?<![\\w\$'\"\\\\])'(${_fields.join('|')})'(?![\\w'\"])");

void main(List<String> args) {
  final names = <String, String>{
    for (final m in _collectionDecl.allMatches(File('lib/data/collections.dart').readAsStringSync()))
      m.group(2)!: m.group(1)!,
  };

  final files = <File>[];
  for (final a in args) {
    if (FileSystemEntity.isDirectorySync(a)) {
      files.addAll(Directory(a).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')));
    } else {
      files.add(File(a));
    }
  }

  var totalCollections = 0, totalFields = 0;
  final unknown = <String>{};
  for (final file in files) {
    final path = file.path.replaceAll('\\', '/');
    if (RegExp(r'^lib/(theme|config|data|l10n)/').hasMatch(path)) continue;

    final lines = file.readAsLinesSync();
    var c = 0, f = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('//') || line.trimLeft().startsWith('import ')) continue;
      var out = line.replaceAllMapped(_collectionCall, (m) {
        final id = names[m.group(2)];
        if (id == null) {
          unknown.add('${m.group(2)} ($path:${i + 1})');
          return m.group(0)!;
        }
        c++;
        return '.${m.group(1)}(Collections.$id)';
      });
      // Fields are Firestore field names only. A SharedPreferences key or a key
      // of the in-app userInfo map can be the same word, but is not a field.
      final notAField = out.contains('prefs.') || out.contains('userInfo[');
      if (!notAField) {
        out = out.replaceAllMapped(_fieldLiteral, (m) {
          f++;
          return 'Fields.${m.group(1)}';
        });
      }
      lines[i] = out;
    }
    if (c == 0 && f == 0) continue;

    if (c > 0) _addImport(lines, path, 'lib/data/collections.dart');
    if (f > 0) _addImport(lines, path, 'lib/data/fields.dart');
    // Keep the file's own line endings.
    final eol = file.readAsStringSync().contains('\r\n') ? '\r\n' : '\n';
    file.writeAsStringSync('${lines.join(eol)}$eol');
    totalCollections += c;
    totalFields += f;
    stdout.writeln('$path: collections $c, fields $f');
  }
  stdout.writeln('TOTAL collections $totalCollections, fields $totalFields');
  if (unknown.isNotEmpty) stdout.writeln('NOT IN Collections (left as is): ${unknown.join(', ')}');
}

void _addImport(List<String> lines, String filePath, String target) {
  final fromDir = File(filePath).parent.path.replaceAll('\\', '/').split('/');
  final to = target.split('/');
  var common = 0;
  while (common < fromDir.length && common < to.length - 1 && fromDir[common] == to[common]) {
    common++;
  }
  final rel = [...List.filled(fromDir.length - common, '..'), ...to.sublist(common)].join('/');
  final stmt = "import '$rel';";
  if (lines.any((l) => l.trim() == stmt)) return;
  final lastImport = lines.lastIndexWhere((l) => l.startsWith('import '));
  lines.insert(lastImport + 1, stmt);
}

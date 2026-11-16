import 'dart:io';

/// Tiny file logger: %APPDATA%\Mono\log.txt (helps debug on the user's PC).
class Log {
  static File? _file;

  static void init() {
    try {
      final base = Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
      final dir = Directory('$base${Platform.pathSeparator}Mono')..createSync(recursive: true);
      _file = File('${dir.path}${Platform.pathSeparator}log.txt');
      if (_file!.existsSync() && _file!.lengthSync() > 512 * 1024) _file!.deleteSync();
    } catch (_) {}
  }

  static void w(Object msg) {
    final line = '${DateTime.now().toIso8601String()}  $msg\n';
    try {
      _file?.writeAsStringSync(line, mode: FileMode.append, flush: true);
    } catch (_) {}
  }
}

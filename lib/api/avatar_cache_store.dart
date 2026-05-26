import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class AvatarCacheStore {
  static Future<File> _fileForUser(String userUid) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeUid = userUid.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File('${dir.path}\\avatar_$safeUid.bin');
  }

  static Future<void> save(String userUid, Uint8List bytes) async {
    if (userUid.trim().isEmpty || bytes.isEmpty) return;
    final file = await _fileForUser(userUid.trim());
    await file.writeAsBytes(bytes, flush: true);
  }

  static Future<Uint8List?> load(String userUid) async {
    if (userUid.trim().isEmpty) return null;
    final file = await _fileForUser(userUid.trim());
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static Future<void> clear(String userUid) async {
    if (userUid.trim().isEmpty) return;
    final file = await _fileForUser(userUid.trim());
    if (await file.exists()) {
      await file.delete();
    }
  }
}

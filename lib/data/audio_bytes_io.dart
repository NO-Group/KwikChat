import 'dart:io';
import 'dart:typed_data';

String newRecordingPath() {
  final dir = Directory.systemTemp.createTempSync('kwik_rec_');
  return '${dir.path}/note.m4a';
}

Future<Uint8List> readAudioBytes(String path) => File(path).readAsBytes();

Future<void> deleteAudioFile(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {}
}

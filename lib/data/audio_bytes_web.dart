import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// The browser recorder ignores the filename and returns a blob URL on stop.
String newRecordingPath() => 'kwik-note.m4a';

Future<Uint8List> readAudioBytes(String path) async {
  final response = await web.window.fetch(path.toJS).toDart;
  final blob = await response.blob().toDart;
  final buffer = await blob.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

Future<void> deleteAudioFile(String path) async {
  try {
    web.URL.revokeObjectURL(path);
  } catch (_) {}
}

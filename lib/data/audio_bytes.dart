/// Platform-split helper for reading recorded audio.
///
/// Web hands back a `blob:` URL from the recorder; native hands back a file
/// path. Both are normalised to bytes here so the upload path is identical.
library;

export 'audio_bytes_io.dart' if (dart.library.js_interop) 'audio_bytes_web.dart';

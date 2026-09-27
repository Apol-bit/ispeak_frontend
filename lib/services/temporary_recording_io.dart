import 'dart:io';

Future<void> discardTemporaryRecording(String? path) async {
  if (path == null) return;
  // Only called with paths created by the recorder, never a saved session URL.
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // A temporary file may already have been removed by the OS.
  }
}

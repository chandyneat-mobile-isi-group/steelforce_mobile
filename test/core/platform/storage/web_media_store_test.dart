@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/platform/storage/captured_media_store_web.dart';
import 'package:steelforce/core/platform/storage/local_files_web.dart';
import 'package:steelforce/core/platform/storage/web_media_registry.dart';

// Run with: flutter test --platform chrome test/core/platform/storage/
void main() {
  final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));

  test('a picked blob image can be shown and read back by path', () async {
    // What `image_picker_for_web` hands back: a `blob:` URL, no bytes.
    final blobUrl = XFile.fromData(bytes, mimeType: 'image/jpeg').path;
    final picked = XFile(blobUrl, mimeType: 'image/jpeg');
    expect(localFileExists(picked.path), isFalse);

    await retainCapturedFile(picked);

    expect(localFileExists(picked.path), isTrue);
    expect(readLocalFileSync(picked.path), bytes);
    final image = localFileImage(picked.path).image as MemoryImage;
    expect(image.bytes, bytes);
  });

  test('stamped bytes are readable under the path they are given', () async {
    final path = await persistCapturedBytes(
      bytes,
      sourcePath: 'blob:ignored',
      fileName: 'proof.jpg',
    );

    expect(path, startsWith('blob:'));
    expect(readLocalFileSync(path), bytes);
  });

  test('a deleted image is reported missing', () async {
    final path = await persistCapturedBytes(
      bytes,
      sourcePath: 'blob:ignored',
      fileName: 'gone.jpg',
    );

    deleteCapturedFile(path);

    expect(localFileExists(path), isFalse);
    expect(readLocalFileSync(path), isNull);
  });

  test('a path from an earlier session or a phone is absent, not a crash',
      () async {
    const stale = 'blob:https://example.invalid/0000-dead';
    await retainCapturedFile(XFile(stale));

    expect(localFileExists(stale), isFalse);
    expect(localFileExists('/data/user/0/app/files/photo.jpg'), isFalse);
    expect(WebMediaRegistry.get(stale), isNull);
  });
}

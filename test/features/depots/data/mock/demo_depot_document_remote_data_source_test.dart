import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_document_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/entities/depot_document.dart';

void main() {
  late DemoNetwork network;
  late DemoDepotDocumentRemoteDataSource source;
  late Directory temp;

  setUp(() {
    network = DemoNetwork();
    source = DemoDepotDocumentRemoteDataSource(network);
    temp = Directory.systemTemp.createTempSync('demo_docs_');
  });

  tearDown(() => temp.deleteSync(recursive: true));

  File photo(String name) => File('${temp.path}/$name')..writeAsBytesSync([1]);

  test('an upload is listed, completes the checklist, and can be removed',
      () async {
    expect((await source.fetch('d1')).missingRequired, {
      DepotDocumentType.storefront,
      DepotDocumentType.insideStore,
      DepotDocumentType.idCard,
    });

    for (final type in [
      DepotDocumentType.storefront,
      DepotDocumentType.insideStore,
      DepotDocumentType.idCard,
    ]) {
      await source.upload(depotId: 'd1', type: type, file: photo('a.jpg'));
    }
    final complete = await source.fetch('d1');
    expect(complete.isComplete, isTrue);
    expect(complete[DepotDocumentType.idCard]?.publicUrl, isNull);

    final id = complete[DepotDocumentType.storefront]!.id;
    await source.delete(depotId: 'd1', documentId: id);
    final after = await source.fetch('d1');
    expect(after.isComplete, isFalse);
    expect(after[DepotDocumentType.storefront], isNull);
  });

  test('a PDF in a photo slot is refused before upload', () async {
    await expectLater(
      source.upload(
        depotId: 'd1',
        type: DepotDocumentType.storefront,
        file: photo('a.pdf'),
      ),
      throwsA(isA<ServerException>()),
    );
  });

  test('offline fails as a network error', () async {
    network.setOnline(false);

    await expectLater(
      source.upload(
        depotId: 'd1',
        type: DepotDocumentType.storefront,
        file: photo('a.jpg'),
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCodes.network)),
    );
  });
}

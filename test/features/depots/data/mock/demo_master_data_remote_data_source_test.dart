import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/features/depots/data/mock/demo_master_data_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/entities/master_data_type.dart';

void main() {
  test('online returns the mock rows', () async {
    final source = DemoMasterDataRemoteDataSource(DemoNetwork());

    expect(await source.fetch(MasterDataType.paymentTerm), isNotEmpty);
  });

  test('offline is a typed NetworkFailure, as the contract requires', () async {
    final source = DemoMasterDataRemoteDataSource(DemoNetwork(online: false));

    await expectLater(
      source.fetch(MasterDataType.paymentTerm),
      throwsA(isA<NetworkFailure>()),
    );
  });
}

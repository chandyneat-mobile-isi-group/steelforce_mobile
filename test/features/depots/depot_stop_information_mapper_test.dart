import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/depots/data/models/depot_stop_information_mapper.dart';

/// Binding rules for `GET /mobile/depots/{id}/stop-information`.
///
/// Every case here is one the backend notice calls out by name, because each
/// is a way the payload can be misread that produces a plausible-looking wrong
/// answer rather than an error — the kind a rep reads out to an outlet owner.
void main() {
  /// The response body from the notice, verbatim.
  Map<String, dynamic> live() => {
        'customer': <String, dynamic>{
          'id': '01a03189-0000-0000-0000-000000000001',
          'code': '6100000123',
          'name': 'Sok Heng Hardware',
          'nameKh': 'ហាង សុខ ហេង',
          'contact': 'Sok Heng',
          'phone': '012345678',
          'address': 'Street 271, Chamkarmon, Phnom Penh',
          'telegram': 'phnom_penh_steel_outlet',
          'outletType': 'Wholesaler',
        },
        'financial': <String, dynamic>{
          'creditLimit': {'amount': 50000.00, 'currency': 'USD'},
          'creditLimitDate': '2026-08-10T00:00:00+00:00',
          'creditBalance': {'amount': 12500.00, 'currency': 'USD'},
          'availableCredit': {'amount': 37500.00, 'currency': 'USD'},
          'currency': 'USD',
          'paymentTermCode': 'T030',
          'paymentTermLabel': '30 days due net',
          'paymentTermDays': 30,
        },
      };

  group('the documented payload', () {
    test('every key binds', () {
      final info = DepotStopInformationMapper.fromData(live());

      expect(info.outlet.code, '6100000123');
      expect(info.outlet.name, 'Sok Heng Hardware');
      expect(info.outlet.nameKh, 'ហាង សុខ ហេង');
      expect(info.outlet.contact, 'Sok Heng');
      expect(info.outlet.phone, '012345678');
      expect(info.outlet.address, 'Street 271, Chamkarmon, Phnom Penh');
      expect(info.outlet.outletType, 'Wholesaler');

      expect(info.credit.creditLimit.amount, 50000.00);
      expect(info.credit.creditLimit.currency, 'USD');
      expect(info.credit.creditBalance.amount, 12500.00);
      expect(info.credit.availableCredit.amount, 37500.00);
      expect(info.credit.paymentTermDays, 30);
      expect(info.credit.creditLimitDate, DateTime.utc(2026, 8, 10));
    });

    test('it reads data.customer, not data.depot', () {
      // The route says depot; the payload keeps SAP's word (ADR-0007). A
      // parser looking for `depot` finds an empty outlet and renders blanks.
      final wrongKey = DepotStopInformationMapper.fromData({
        'depot': live()['customer'],
        'financial': live()['financial'],
      });

      expect(wrongKey.outlet.code, isEmpty,
          reason: 'proves the mapper is keyed on `customer` — if this ever '
              'passes with data, someone has started accepting both');
    });
  });

  group('telegram', () {
    test('is stored without @ and displayed with one', () {
      final info = DepotStopInformationMapper.fromData(live());

      expect(info.outlet.telegram, 'phnom_penh_steel_outlet');
      expect(info.outlet.telegramHandle, '@phnom_penh_steel_outlet');
    });

    test('a server that starts sending @ does not produce @@', () {
      final body = live();
      (body['customer']! as Map<String, dynamic>)['telegram'] =
          '@already_prefixed';

      expect(DepotStopInformationMapper.fromData(body).outlet.telegramHandle,
          '@already_prefixed');
    });

    test('absent stays absent — @ alone is not an account', () {
      final body = live();
      (body['customer']! as Map<String, dynamic>)['telegram'] = null;

      expect(DepotStopInformationMapper.fromData(body).outlet.telegramHandle,
          isNull);
    });
  });

  group('absence is null, not empty string', () {
    test('nameKh', () {
      // The route sync uses `''` for the same idea. Sharing a parser between
      // the two contracts is what the notice forbids.
      final body = live();
      (body['customer']! as Map<String, dynamic>)['nameKh'] = null;

      expect(DepotStopInformationMapper.fromData(body).outlet.nameKh, isNull);
    });

    test('an empty string is normalised to null too', () {
      final body = live();
      (body['customer']! as Map<String, dynamic>)['nameKh'] = '';
      (body['customer']! as Map<String, dynamic>)['contact'] = '   ';

      final outlet = DepotStopInformationMapper.fromData(body).outlet;
      expect(outlet.nameKh, isNull);
      expect(outlet.contact, isNull,
          reason: 'one absence case for the caller to handle, not two');
    });

    test('a null contact means nobody was recorded', () {
      final body = live();
      (body['customer']! as Map<String, dynamic>)['contact'] = null;

      expect(DepotStopInformationMapper.fromData(body).outlet.contact, isNull);
    });
  });

  group('money', () {
    test('zero credit limit is a real answer, not unknown', () {
      // Cash-only trade. Re-defaulting this to a placeholder tells a rep the
      // outlet has undisclosed headroom when it has none.
      final body = live();
      (body['financial']! as Map<String, dynamic>)['creditLimit'] = {
        'amount': 0.0,
        'currency': 'USD',
      };

      final credit = DepotStopInformationMapper.fromData(body).credit;
      expect(credit.creditLimit.amount, 0.0);
      expect(credit.creditLimit.isZero, isTrue);
      expect(credit.creditLimit.currency, 'USD');
    });

    test('availableCredit is read, never recomputed', () {
      // The server's figure wins even when it disagrees with limit − balance.
      // A client that subtracts can disagree with the server about an outlet's
      // headroom, and the rep is the one standing in front of the owner.
      final body = live();
      (body['financial']! as Map<String, dynamic>)['availableCredit'] = {
        'amount': 999.0,
        'currency': 'USD',
      };

      expect(
        DepotStopInformationMapper.fromData(body).credit.availableCredit.amount,
        999.0,
        reason: 'limit − balance would be 37500; the server said 999',
      );
    });

    test('currency survives — KHR is not silently USD', () {
      final body = live();
      (body['financial']! as Map<String, dynamic>)['currency'] = 'KHR';
      (body['financial']! as Map<String, dynamic>)['creditLimit'] = {
        'amount': 200000.0,
        'currency': 'KHR',
      };

      final credit = DepotStopInformationMapper.fromData(body).credit;
      expect(credit.currency, 'KHR');
      expect(credit.creditLimit.currency, 'KHR');
    });
  });

  group('payment term', () {
    test('the label is used when the catalogue resolved it', () {
      expect(
          DepotStopInformationMapper.fromData(live()).credit.paymentTermDisplay,
          '30 days due net');
    });

    test('a null label falls back to the code', () {
      // The server will not echo the code back as a label, so null genuinely
      // means unresolved — showing nothing would lose a term the rep needs.
      final body = live();
      (body['financial']! as Map<String, dynamic>)['paymentTermLabel'] = null;

      expect(
          DepotStopInformationMapper.fromData(body).credit.paymentTermDisplay,
          'T030');
    });

    test('neither label nor code resolves to nothing, not to a guess', () {
      final body = live();
      (body['financial']! as Map<String, dynamic>)['paymentTermLabel'] = null;
      (body['financial']! as Map<String, dynamic>)['paymentTermCode'] = null;

      expect(
          DepotStopInformationMapper.fromData(body).credit.paymentTermDisplay,
          isNull);
    });
  });

  test('a malformed body degrades instead of throwing', () {
    // One unexpected null must not take down a stop screen a rep is standing
    // in front of a shop to read.
    final info = DepotStopInformationMapper.fromData(const {});

    expect(info.outlet.code, isEmpty);
    expect(info.outlet.contact, isNull);
    expect(info.credit.creditLimit.amount, 0);
    expect(info.credit.paymentTermDisplay, isNull);
  });

  test('a SAP code or phone sent as a JSON number still binds', () {
    final info = DepotStopInformationMapper.fromData(const {
      'customer': {'id': 'd1', 'code': 6100000123, 'phone': 12345678},
      'financial': {'currency': 'USD'},
    });

    expect(info.outlet.code, '6100000123');
    expect(info.outlet.phone, '12345678');
  });
}

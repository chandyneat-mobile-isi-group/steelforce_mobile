import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';

/// Step 3 of the registration form collects a contact name, a role and a mobile
/// number. They describe one person, but the draft stores them as three loose
/// fields — so the pairing has to live in one place, or each call site invents
/// its own and nothing catches a role attached to the wrong number.
///
/// `BpDepotDraft.contacts` is that place. These tests pin the matching rule:
/// the name goes with the role, and the phone is the **mobile**, never the
/// landline.
void main() {
  BpDepotDraft draftWith({
    String name = 'Yim Vithou',
    String? role = 'Owner',
    String mobile = '012345678',
    String telephone = '023456789',
    bool sameAsMobile = false,
  }) {
    return BpDepotDraft()
      ..contactPersonName = name
      ..contactPersonRole = role
      ..mobilePhone = mobile
      ..telephone = telephone
      ..telephoneSameAsMobile = sameAsMobile;
  }

  test('pairs the name, the role and the mobile as one person', () {
    final contacts = draftWith().contacts;

    expect(contacts, hasLength(1));
    final contact = contacts.single;
    expect(contact.name, 'Yim Vithou');
    expect(contact.position, 'Owner');
    expect(contact.phone, '012345678');
  });

  test('takes the mobile, never the landline', () {
    // The landline is the shop's, and `telephoneSameAsMobile` means it may not
    // even be a distinct number. Putting it on a person would give a rep a
    // number that rings the counter when they wanted the owner.
    final contacts = draftWith(mobile: '012111222', telephone: '023999888');

    expect(contacts.contacts.single.phone, '012111222');
    expect(contacts.contacts.single.phone, isNot('023999888'));
  });

  test('is the primary contact — the form captures exactly one', () {
    expect(draftWith().contacts.single.isPrimary, isTrue);
  });

  test('is empty when no name was entered, rather than a nameless contact', () {
    expect(draftWith(name: '').contacts, isEmpty);
    expect(draftWith(name: '   ').contacts, isEmpty);
  });

  test('omits the role rather than sending a blank position', () {
    expect(draftWith(role: null).contacts.single.position, isNull);
    expect(draftWith(role: '  ').contacts.single.position, isNull);
    // …and the contact still exists: a name and a number are useful without a
    // role, and the role is the one of the three the rep may not know.
    expect(draftWith(role: null).contacts, hasLength(1));
  });

  test('trims what the rep typed', () {
    final contact = draftWith(
            name: '  Yim Vithou  ', role: ' Owner ', mobile: ' 012345678 ')
        .contacts
        .single;

    expect(contact.name, 'Yim Vithou');
    expect(contact.position, 'Owner');
    expect(contact.phone, '012345678');
  });

  test('serialises to the contact shape the depot API documents', () {
    final json = draftWith().contacts.single.toJson();

    // `position`, not `role` — the wire's word. Getting this wrong sends a
    // contact the server accepts and silently files with no position.
    expect(json, {
      'name': 'Yim Vithou',
      'phone': '012345678',
      'position': 'Owner',
      'isPrimary': true,
    });
  });
}

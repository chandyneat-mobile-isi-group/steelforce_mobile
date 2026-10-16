enum DepotActivityType {
  call('Call', 'call'),
  whatsapp('WhatsApp', 'whatsapp'),
  visit('Visit', 'visit'),
  note('Note', 'note'),
  opportunityCreated('Opportunity Created', 'opportunity'),
  order('Order', 'order');

  const DepotActivityType(this.label, this.value);
  final String label;
  final String value;

  static DepotActivityType fromValue(String value) =>
      DepotActivityType.values.firstWhere(
        (t) => t.value == value,
        orElse: () => DepotActivityType.note,
      );
}

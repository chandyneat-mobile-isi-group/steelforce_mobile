/// A SAP key/description pair as shown in a dropdown ("Z001 - Local Depot").
class SapOption {
  final String code;
  final String labelEn;
  final String? labelKh;

  const SapOption(this.code, this.labelEn, [this.labelKh]);

  String get display => '$code - $labelEn';

  @override
  String toString() => display;
}

import 'package:icon_font/src/otf/cff/operator.dart';

enum DictOperator {
  // Top DICT operators
  /// 1/unitsPerEm 0 0 1/unitsPerEm 0 0. Omitted if unitsPerEm is 1000.
  fontMatrix(label: 'FontMatrix', b0: 12, b1: 7),

  /// CharStrings INDEX offset.
  charStrings(label: 'CharStrings', b0: 17),

  /// Font DICT (FD) INDEX offset.
  fdArray(label: 'FDArray', b0: 12, b1: 36),

  /// FDSelect structure offset. Omitted if just one Font DICT.
  fdSelect(label: 'FDSelect', b0: 12, b1: 37),

  /// VariationStore structure offset. Omitted if there is no varation data.
  vstore(label: 'vstore', b0: 24),

  // CFF1 Top DICT operators
  version(label: 'version', b0: 0),
  notice(label: 'Notice', b0: 1),
  copyright(label: 'Copyright', b0: 12, b1: 0),
  fullName(label: 'FullName', b0: 2),
  familyName(label: 'FamilyName', b0: 3),
  weight(label: 'Weight', b0: 4),
  fontBBox(label: 'FontBBox', b0: 5),
  charset(label: 'charset', b0: 15),
  encoding(label: 'Encoding', b0: 16),
  nominalWidthX(label: 'nominalWidthX', b0: 21),

  // Font DICT operators
  /// Private DICT size and offset
  private(label: 'Private', b0: 18),
  blueValues(label: 'BlueValues', b0: 6),
  otherBlues(label: 'OtherBlues', b0: 7),
  familyBlues(label: 'FamilyBlues', b0: 8),
  familyOtherBlues(label: 'FamilyOtherBlues', b0: 9),
  stdHW(label: 'StdHW', b0: 10),
  stdVW(label: 'StdVW', b0: 11),
  escape(label: 'escape', b0: 12),
  subrs(label: 'Subrs', b0: 19),
  vsindex(label: 'vsindex', b0: 22),
  blend(label: 'blend', b0: 23),
  bcd(label: 'BCD', b0: 30),
  blueScale(label: 'BlueScale', b0: 12, b1: 9),
  blueShift(label: 'BlueShift', b0: 12, b1: 10),
  blueFuzz(label: 'BlueFuzz', b0: 12, b1: 11),
  stemSnapH(label: 'StemSnapH', b0: 12, b1: 12),
  stemSnapV(label: 'StemSnapV', b0: 12, b1: 13),
  languageGroup(label: 'LanguageGroup', b0: 12, b1: 17),
  expansionFactor(label: 'ExpansionFactor', b0: 12, b1: 18);

  const DictOperator({required this.label, required int b0, int? b1})
    : _b0 = b0,
      _b1 = b1,
      context = CFFOperatorContext.dict;

  final int _b0;
  final int? _b1;
  final String label;
  final CFFOperatorContext context;

  CFFOperator get operator => CFFOperator(context: context, b0: _b0, b1: _b1);
}

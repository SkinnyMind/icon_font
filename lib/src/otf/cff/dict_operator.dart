import 'dart:collection';

import 'package:icon_font/src/otf/cff/operator.dart';

// Top DICT operators

/// 1/unitsPerEm 0 0 1/unitsPerEm 0 0. Omitted if unitsPerEm is 1000.
const fontMatrix = CFFOperator(context: CFFOperatorContext.dict, b0: 12, b1: 7);

/// CharStrings INDEX offset.
const charStrings = CFFOperator(context: CFFOperatorContext.dict, b0: 17);

/// Font DICT (FD) INDEX offset.
const fdArray = CFFOperator(context: CFFOperatorContext.dict, b0: 12, b1: 36);

/// FDSelect structure offset. OOmitted if just one Font DICT.
const fdSelect = CFFOperator(context: CFFOperatorContext.dict, b0: 12, b1: 37);

/// VariationStore structure offset. Omitted if there is no varation data.
const vstore = CFFOperator(context: CFFOperatorContext.dict, b0: 24);

// CFF1 Top DICT operators

/// version
const version = CFFOperator(context: CFFOperatorContext.dict, b0: 0);

/// Notice
const notice = CFFOperator(context: CFFOperatorContext.dict, b0: 1);

/// Copyright
const copyright = CFFOperator(context: CFFOperatorContext.dict, b0: 12, b1: 0);

/// Full Name
const fullName = CFFOperator(context: CFFOperatorContext.dict, b0: 2);

/// Family Name
const familyName = CFFOperator(context: CFFOperatorContext.dict, b0: 3);

/// Weight
const weight = CFFOperator(context: CFFOperatorContext.dict, b0: 4);

/// Font BBox
const fontBBox = CFFOperator(context: CFFOperatorContext.dict, b0: 5);

/// Charset offset
const charset = CFFOperator(context: CFFOperatorContext.dict, b0: 15);

/// Encoding offset
const encoding = CFFOperator(context: CFFOperatorContext.dict, b0: 16);

/// Nominal Width X
const nominalWidthX = CFFOperator(context: CFFOperatorContext.dict, b0: 21);

// Font DICT operators

/// Private DICT size and offset
const private = CFFOperator(context: CFFOperatorContext.dict, b0: 18);

const blueValues = CFFOperator(context: CFFOperatorContext.dict, b0: 6);
const otherBlues = CFFOperator(context: CFFOperatorContext.dict, b0: 7);
const familyBlues = CFFOperator(context: CFFOperatorContext.dict, b0: 8);
const familyOtherBlues = CFFOperator(context: CFFOperatorContext.dict, b0: 9);
const stdHW = CFFOperator(context: CFFOperatorContext.dict, b0: 10);
const stdVW = CFFOperator(context: CFFOperatorContext.dict, b0: 11);
const escape = CFFOperator(context: CFFOperatorContext.dict, b0: 12);
const subrs = CFFOperator(context: CFFOperatorContext.dict, b0: 19);
const vsindex = CFFOperator(context: CFFOperatorContext.dict, b0: 22);
const blend = CFFOperator(context: CFFOperatorContext.dict, b0: 23);
const bcd = CFFOperator(context: CFFOperatorContext.dict, b0: 30);

const blueScale = CFFOperator(context: CFFOperatorContext.dict, b0: 12, b1: 9);
const blueShift = CFFOperator(context: CFFOperatorContext.dict, b0: 12, b1: 10);
const blueFuzz = CFFOperator(context: CFFOperatorContext.dict, b0: 12, b1: 11);
const stemSnapH = CFFOperator(context: CFFOperatorContext.dict, b0: 12, b1: 12);
const stemSnapV = CFFOperator(context: CFFOperatorContext.dict, b0: 12, b1: 13);
const languageGroup =
    CFFOperator(context: CFFOperatorContext.dict, b0: 12, b1: 17);
const expansionFactor =
    CFFOperator(context: CFFOperatorContext.dict, b0: 12, b1: 18);

final Map<CFFOperator, String> dictOperatorNames = UnmodifiableMapView({
  fontMatrix: 'FontMatrix',
  charStrings: 'CharStrings',
  fdArray: 'FDArray',
  fdSelect: 'FDSelect',
  vstore: 'vstore',
  private: 'Private',
  blueValues: 'BlueValues',
  otherBlues: 'OtherBlues',
  familyBlues: 'FamilyBlues',
  familyOtherBlues: 'FamilyOtherBlues',
  stdHW: 'StdHW',
  stdVW: 'StdVW',
  escape: 'escape',
  subrs: 'Subrs',
  vsindex: 'vsindex',
  blend: 'blend',
  bcd: 'BCD',
  blueScale: 'BlueScale',
  blueShift: 'BlueShift',
  blueFuzz: 'BlueFuzz',
  stemSnapH: 'StemSnapH',
  stemSnapV: 'StemSnapV',
  languageGroup: 'LanguageGroup',
  expansionFactor: 'ExpansionFactor',
  charset: 'charset',
  encoding: 'Encoding',
  version: 'version',
  notice: 'Notice',
  copyright: 'Copyright',
  fullName: 'FullName',
  familyName: 'FamilyName',
  weight: 'Weight',
  fontBBox: 'FontBBox',
  nominalWidthX: 'nominalWidthX',
});

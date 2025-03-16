import 'dart:collection';

import 'package:icon_font/src/otf/cff/operator.dart';

// CharString operators
const hstem = CFFOperator(context: CFFOperatorContext.charString, b0: 1);
const vstem = CFFOperator(context: CFFOperatorContext.charString, b0: 3);
const vmoveto = CFFOperator(context: CFFOperatorContext.charString, b0: 4);
const rlineto = CFFOperator(context: CFFOperatorContext.charString, b0: 5);
const hlineto = CFFOperator(context: CFFOperatorContext.charString, b0: 6);
const vlineto = CFFOperator(context: CFFOperatorContext.charString, b0: 7);
const rrcurveto = CFFOperator(context: CFFOperatorContext.charString, b0: 8);
const callsubr = CFFOperator(context: CFFOperatorContext.charString, b0: 10);
const escape = CFFOperator(context: CFFOperatorContext.charString, b0: 12);
const vsindex = CFFOperator(context: CFFOperatorContext.charString, b0: 15);
const blend = CFFOperator(context: CFFOperatorContext.charString, b0: 16);
const hstemhm = CFFOperator(context: CFFOperatorContext.charString, b0: 18);
const hintmask = CFFOperator(context: CFFOperatorContext.charString, b0: 19);
const cntrmask = CFFOperator(context: CFFOperatorContext.charString, b0: 20);
const rmoveto = CFFOperator(context: CFFOperatorContext.charString, b0: 21);
const hmoveto = CFFOperator(context: CFFOperatorContext.charString, b0: 22);
const vstemhm = CFFOperator(context: CFFOperatorContext.charString, b0: 23);
const rcurveline = CFFOperator(context: CFFOperatorContext.charString, b0: 24);
const rlinecurve = CFFOperator(context: CFFOperatorContext.charString, b0: 25);
const vvcurveto = CFFOperator(context: CFFOperatorContext.charString, b0: 26);
const hhcurveto = CFFOperator(context: CFFOperatorContext.charString, b0: 27);
const callgsubr = CFFOperator(context: CFFOperatorContext.charString, b0: 29);
const vhcurveto = CFFOperator(context: CFFOperatorContext.charString, b0: 30);
const hvcurveto = CFFOperator(context: CFFOperatorContext.charString, b0: 31);

const hflex = CFFOperator(
  context: CFFOperatorContext.charString,
  b0: 12,
  b1: 34,
);
const flex = CFFOperator(
  context: CFFOperatorContext.charString,
  b0: 12,
  b1: 35,
);
const hflex1 = CFFOperator(
  context: CFFOperatorContext.charString,
  b0: 12,
  b1: 36,
);
const flex1 = CFFOperator(
  context: CFFOperatorContext.charString,
  b0: 12,
  b1: 37,
);

/// CFF1 endchar
const endchar = CFFOperator(context: CFFOperatorContext.charString, b0: 14);

final Map<CFFOperator, String> charStringOperatorNames = UnmodifiableMapView({
  vstem: 'vstem',
  vmoveto: 'vmoveto',
  rlineto: 'rlineto',
  hlineto: 'hlineto',
  vlineto: 'vlineto',
  rrcurveto: 'rrcurveto',
  callsubr: 'callsubr',
  escape: 'escape',
  vsindex: 'vsindex',
  blend: 'blend',
  hstemhm: 'hstemhm',
  hintmask: 'hintmask',
  cntrmask: 'cntrmask',
  rmoveto: 'rmoveto',
  hmoveto: 'hmoveto',
  vstemhm: 'vstemhm',
  rcurveline: 'rcurveline',
  rlinecurve: 'rlinecurve',
  vvcurveto: 'vvcurveto',
  hhcurveto: 'hhcurveto',
  callgsubr: 'callgsubr',
  vhcurveto: 'vhcurveto',
  hvcurveto: 'hvcurveto',
  hflex: 'hflex',
  flex: 'flex',
  hflex1: 'hflex1',
  flex1: 'flex1',
  endchar: 'endchar',
});

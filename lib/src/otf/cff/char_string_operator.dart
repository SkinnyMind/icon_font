import 'package:icon_font/src/otf/cff/operator.dart';

enum CharStringOperator({required final int b0, final int? b1}) {
  hstem(b0: 1),
  vstem(b0: 3),
  vmoveto(b0: 4),
  rlineto(b0: 5),
  hlineto(b0: 6),
  vlineto(b0: 7),
  rrcurveto(b0: 8),
  callsubr(b0: 10),
  escape(b0: 12),
  endchar(b0: 14),
  vsindex(b0: 15),
  blend(b0: 16),
  hstemhm(b0: 18),
  hintmask(b0: 19),
  cntrmask(b0: 20),
  rmoveto(b0: 21),
  hmoveto(b0: 22),
  vstemhm(b0: 23),
  rcurveline(b0: 24),
  rlinecurve(b0: 25),
  vvcurveto(b0: 26),
  hhcurveto(b0: 27),
  callgsubr(b0: 29),
  vhcurveto(b0: 30),
  hvcurveto(b0: 31),
  hflex(b0: 12, b1: 34),
  flex(b0: 12, b1: 35),
  hflex1(b0: 12, b1: 36),
  flex1(b0: 12, b1: 37);

  this : context = CFFOperatorContext.charString;

  final CFFOperatorContext context;

  CFFOperator get operator => CFFOperator(context: context, b0: b0, b1: b1);
}

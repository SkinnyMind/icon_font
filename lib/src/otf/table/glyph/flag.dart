import 'dart:typed_data';

import 'package:icon_font/src/common/codable/binary.dart';
import 'package:icon_font/src/utils/otf.dart';

const _kOnCurvePointValue = 0x01;
const _kXshortVectorValue = 0x02;
const _kYshortVectorValue = 0x04;
const _kRepeatFlagValue = 0x08;
const _kXisSameValue = 0x10;
const _kYisSameValue = 0x20;
const _kOverlapSimpleValue = 0x40;
const _kReservedValue = 0x80;

class SimpleGlyphFlag implements BinaryCodable {
  SimpleGlyphFlag({
    required this.onCurvePoint,
    required this.xShortVector,
    required this.yShortVector,
    required this.repeat,
    required this.xIsSameOrPositive,
    required this.yIsSameOrPositive,
    required this.overlapSimple,
    required this.reserved,
  });

  factory SimpleGlyphFlag.fromIntValue({required int flag, int? repeatTimes}) {
    return SimpleGlyphFlag(
      onCurvePoint: checkBitMask(value: flag, mask: _kOnCurvePointValue),
      xShortVector: checkBitMask(value: flag, mask: _kXshortVectorValue),
      yShortVector: checkBitMask(value: flag, mask: _kYshortVectorValue),
      repeat: repeatTimes,
      xIsSameOrPositive: checkBitMask(value: flag, mask: _kXisSameValue),
      yIsSameOrPositive: checkBitMask(value: flag, mask: _kYisSameValue),
      overlapSimple: checkBitMask(value: flag, mask: _kOverlapSimpleValue),
      reserved: checkBitMask(value: flag, mask: _kReservedValue),
    );
  }

  factory SimpleGlyphFlag.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final flag = byteData.getUint8(offset);
    final repeatFlag = checkBitMask(value: flag, mask: _kRepeatFlagValue);
    final repeatTimes = repeatFlag ? byteData.getUint8(offset + 1) : null;

    return SimpleGlyphFlag.fromIntValue(flag: flag, repeatTimes: repeatTimes);
  }

  factory SimpleGlyphFlag.createForPoint({
    required int x,
    required int y,
    required bool isOnCurve,
  }) {
    final xIsShort = isShortInteger(x);
    final yIsShort = isShortInteger(y);

    return SimpleGlyphFlag(
      onCurvePoint: isOnCurve,
      xShortVector: xIsShort,
      yShortVector: yIsShort,
      repeat: null,
      // 1 if short and positive, 0 otherwise
      xIsSameOrPositive: xIsShort && !x.isNegative,
      // 1 if short and positive, 0 otherwise
      yIsSameOrPositive: yIsShort && !y.isNegative,
      overlapSimple: false,
      reserved: false,
    );
  }

  final bool onCurvePoint;
  final bool xShortVector;
  final bool yShortVector;
  final int? repeat;
  final bool xIsSameOrPositive;
  final bool yIsSameOrPositive;
  final bool overlapSimple;
  final bool reserved;

  Map<int, bool> get _valueForMaskMap => {
        _kOnCurvePointValue: onCurvePoint,
        _kXshortVectorValue: xShortVector,
        _kYshortVectorValue: yShortVector,
        _kXisSameValue: xIsSameOrPositive,
        _kYisSameValue: yIsSameOrPositive,
        _kOverlapSimpleValue: overlapSimple,
        _kReservedValue: reserved,
        _kRepeatFlagValue: isRepeating,
      };

  bool get isRepeating => repeat != null;

  int get repeatTimes => repeat ?? 0;

  int get intValue {
    var value = 0;

    _valueForMaskMap.forEach((mask, flagIsSet) {
      value |= flagIsSet ? mask : 0;
    });

    return value;
  }

  @override
  int get size => 1 + (isRepeating ? 1 : 0);

  @override
  void encodeToBinary(ByteData byteData) {
    byteData.setUint8(0, intValue);

    if (isRepeating) {
      byteData.setUint8(1, repeatTimes);
    }
  }
}

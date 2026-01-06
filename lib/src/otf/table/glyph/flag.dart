import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/utils/otf_utils.dart';

const _onCurvePointValue = 0x01;
const _xShortVectorValue = 0x02;
const _yShortVectorValue = 0x04;
const repeatFlagValue = 0x08;
const _xIsSameValue = 0x10;
const _yIsSameValue = 0x20;
const _overlapSimpleValue = 0x40;
const _reservedValue = 0x80;

class SimpleGlyphFlag implements BinaryCodable {
  SimpleGlyphFlag({
    required this.onCurvePoint,
    required this.xShortVector,
    required this.yShortVector,
    required this.xIsSameOrPositive,
    required this.yIsSameOrPositive,
    required this.overlapSimple,
    required this.reserved,
    this.repeat = 0,
  });

  factory SimpleGlyphFlag.fromIntValue({
    required int flag,
    int repeatTimes = 0,
  }) {
    return SimpleGlyphFlag(
      onCurvePoint: OtfUtils.checkBitMask(
        value: flag,
        mask: _onCurvePointValue,
      ),
      xShortVector: OtfUtils.checkBitMask(
        value: flag,
        mask: _xShortVectorValue,
      ),
      yShortVector: OtfUtils.checkBitMask(
        value: flag,
        mask: _yShortVectorValue,
      ),
      repeat: repeatTimes,
      xIsSameOrPositive: OtfUtils.checkBitMask(
        value: flag,
        mask: _xIsSameValue,
      ),
      yIsSameOrPositive: OtfUtils.checkBitMask(
        value: flag,
        mask: _yIsSameValue,
      ),
      overlapSimple: OtfUtils.checkBitMask(
        value: flag,
        mask: _overlapSimpleValue,
      ),
      reserved: OtfUtils.checkBitMask(value: flag, mask: _reservedValue),
    );
  }

  factory SimpleGlyphFlag.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final flag = byteData.getUint8(offset);
    final repeatFlag = OtfUtils.checkBitMask(
      value: flag,
      mask: repeatFlagValue,
    );
    final repeatTimes = repeatFlag ? byteData.getUint8(offset + 1) : 0;

    return SimpleGlyphFlag.fromIntValue(flag: flag, repeatTimes: repeatTimes);
  }

  factory SimpleGlyphFlag.createForPoint({
    required int x,
    required int y,
    required bool isOnCurve,
  }) {
    final xIsShort = OtfUtils.isShortInteger(x);
    final yIsShort = OtfUtils.isShortInteger(y);

    return SimpleGlyphFlag(
      onCurvePoint: isOnCurve,
      xShortVector: xIsShort,
      yShortVector: yIsShort,
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
  final int repeat;
  final bool xIsSameOrPositive;
  final bool yIsSameOrPositive;
  final bool overlapSimple;
  final bool reserved;

  Map<int, bool> get _valueForMaskMap => {
    _onCurvePointValue: onCurvePoint,
    _xShortVectorValue: xShortVector,
    _yShortVectorValue: yShortVector,
    _xIsSameValue: xIsSameOrPositive,
    _yIsSameValue: yIsSameOrPositive,
    _overlapSimpleValue: overlapSimple,
    _reservedValue: reserved,
    repeatFlagValue: isRepeating,
  };

  bool get isRepeating => repeat > 0;

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
      byteData.setUint8(1, repeat);
    }
  }
}

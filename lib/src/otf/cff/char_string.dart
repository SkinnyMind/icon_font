import 'dart:typed_data';

import 'package:icon_font/src/common/codable/binary.dart';
import 'package:icon_font/src/otf/cff/char_string_operator.dart';
import 'package:icon_font/src/otf/cff/operand.dart';
import 'package:icon_font/src/otf/cff/operator.dart';
import 'package:icon_font/src/utils/otf.dart';

class CharStringOperand extends CFFOperand {
  CharStringOperand({required super.value, required super.size});

  factory CharStringOperand.fromByteData({
    required ByteData byteData,
    required int offset,
    required int b0,
  }) {
    if (b0 == 255) {
      final value = byteData.getUint32(0);
      return CharStringOperand(value: value / 0x10000, size: 5);
    } else {
      final operand = CFFOperand.fromByteData(byteData, offset, b0);
      return CharStringOperand(value: operand.value, size: operand.size);
    }
  }

  @override
  void encodeToBinary(ByteData byteData) {
    var offset = 0;

    if (value is double) {
      byteData
        ..setUint8(offset++, 255)
        ..setUint32(offset, (value! * 0x10000).round());
      offset += 4;
    } else {
      super.encodeToBinary(byteData);
    }
  }

  @override
  int get size => value is double ? 5 : super.size;
}

class CharStringCommand implements BinaryCodable {
  CharStringCommand({
    required this.operator,
    required this.operandList,
  }) : assert(
          operator.context == CFFOperatorContext.charString,
          "Operator's context must be CharString",
        );

  factory CharStringCommand.hmoveto({required int dx}) {
    return CharStringCommand(
      operator: hmoveto,
      operandList: _getOperandList(operandValues: [dx]),
    );
  }

  factory CharStringCommand.vmoveto({required int dy}) {
    return CharStringCommand(
      operator: vmoveto,
      operandList: _getOperandList(operandValues: [dy]),
    );
  }

  factory CharStringCommand.rmoveto({required int dx, required int dy}) {
    return CharStringCommand(
      operator: rmoveto,
      operandList: _getOperandList(operandValues: [dx, dy]),
    );
  }

  factory CharStringCommand.moveto({required int dx, required int dy}) {
    if (dx == 0) {
      return CharStringCommand.vmoveto(dy: dy);
    } else if (dy == 0) {
      return CharStringCommand.hmoveto(dx: dx);
    }

    return CharStringCommand.rmoveto(dx: dx, dy: dy);
  }

  factory CharStringCommand.hlineto({required int dx}) {
    return CharStringCommand(
      operator: hlineto,
      operandList: _getOperandList(operandValues: [dx]),
    );
  }

  factory CharStringCommand.vlineto({required int dy}) {
    return CharStringCommand(
      operator: vlineto,
      operandList: _getOperandList(operandValues: [dy]),
    );
  }

  factory CharStringCommand.rlineto({required List<int> dlist}) {
    if (dlist.length.isOdd || dlist.length < 2) {
      throw ArgumentError('|- {dxa dya}+ rlineto (5) |-');
    }

    return CharStringCommand(
      operator: rlineto,
      operandList: _getOperandList(operandValues: dlist),
    );
  }

  factory CharStringCommand.lineto({required int dx, required int dy}) {
    if (dx == 0) {
      return CharStringCommand.vlineto(dy: dy);
    } else if (dy == 0) {
      return CharStringCommand.hlineto(dx: dx);
    }

    return CharStringCommand.rlineto(dlist: [dx, dy]);
  }

  factory CharStringCommand.hhcurveto({required List<int> dlist}) {
    if (dlist.length < 4 || (dlist.length % 4 != 0 && dlist.length % 4 != 1)) {
      throw ArgumentError('|- dy1? {dxa dxb dyb dxc}+ hhcurveto (27) |-');
    }

    return CharStringCommand(
      operator: hhcurveto,
      operandList: _getOperandList(operandValues: dlist),
    );
  }

  factory CharStringCommand.vvcurveto({required List<int> dlist}) {
    if (dlist.length < 4 || (dlist.length % 4 != 0 && dlist.length % 4 != 1)) {
      throw ArgumentError('|- dx1? {dya dxb dyb dyc}+ vvcurveto (26) |-');
    }

    return CharStringCommand(
      operator: vvcurveto,
      operandList: _getOperandList(operandValues: dlist),
    );
  }

  factory CharStringCommand.curveto({required List<int> dlist}) {
    if (dlist.length != 6) {
      throw ArgumentError('List length must be equal 6');
    }

    if (dlist[4] == 0) {
      dlist.removeAt(4);
      final dx = dlist.removeAt(0);

      if (dx != 0) {
        dlist.insert(0, dx);
      }

      return CharStringCommand.vvcurveto(dlist: dlist);
    } else if (dlist[5] == 0) {
      dlist.removeAt(5);
      final dy = dlist.removeAt(1);

      if (dy != 0) {
        dlist.insert(0, dy);
      }

      return CharStringCommand.hhcurveto(dlist: dlist);
    }

    return CharStringCommand(
      operator: rrcurveto,
      operandList: _getOperandList(operandValues: dlist),
    );
  }

  final CFFOperator operator;
  final List<CharStringOperand> operandList;

  static List<CharStringOperand> _getOperandList({
    required List<num> operandValues,
  }) {
    return operandValues
        .map((e) => CharStringOperand(value: e, size: null))
        .toList();
  }

  CharStringCommand copy() => CharStringCommand(
        operator: operator,
        operandList: operandList,
      );

  @override
  String toString() {
    var operandListString = operandList.map((e) => e.toString()).join(', ');

    if (operandListString.length > 10) {
      operandListString = '${operandListString.substring(0, 10)}...';
    }

    return '$operator [$operandListString]';
  }

  @override
  void encodeToBinary(ByteData byteData) {
    var offset = 0;

    for (final operand in operandList) {
      final operandSize = operand.size;
      operand.encodeToBinary(byteData.sublistView(offset, operandSize));
      offset += operandSize;
    }

    operator.encodeToBinary(byteData.sublistView(offset, operator.size));
  }

  @override
  int get size => operator.size + operandList.fold<int>(0, (p, e) => e.size);
}

/// A very basic implementation of the CFF2 CharString interpreter.
/// Doesn't support hinting, subroutines, blending.
/// Doesn't respect interpreter implementation limits.
class CharStringInterpreter {
  CharStringInterpreter({required this.isCFF1});

  final bool isCFF1;

  ByteData writeCommands({
    required List<CharStringCommand> commandList,
    int? glyphWidth,
  }) {
    final list = <int>[];

    void encodeAndPush({required BinaryEncodable encodable}) {
      final byteData = ByteData(encodable.size);
      encodable.encodeToBinary(byteData);
      list.addAll(byteData.buffer.asUint8List());
    }

    // CFF1 glyphs contain width value as a first operand
    if (isCFF1 && glyphWidth != null) {
      encodeAndPush(encodable: CFFOperand.fromValue(glyphWidth));
    }

    for (final command in commandList) {
      for (final operand in command.operandList) {
        encodeAndPush(encodable: operand);
      }
      encodeAndPush(encodable: command.operator);
    }

    return ByteData.sublistView(Uint8List.fromList(list));
  }
}

class CharStringInterpreterLimits {
  factory CharStringInterpreterLimits({required bool isCFF1}) => isCFF1
      ? const CharStringInterpreterLimits._cff1()
      : const CharStringInterpreterLimits._cff2();

  const CharStringInterpreterLimits._cff1() : argumentStackLimit = 48;

  const CharStringInterpreterLimits._cff2() : argumentStackLimit = 513;

  final int argumentStackLimit;
}

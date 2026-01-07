import 'package:icon_font/src/otf/cff/char_string.dart';
import 'package:icon_font/src/otf/cff/char_string_operator.dart';

class CharStringOptimizer {
  CharStringOptimizer({required bool isCFF1})
    : _limits = CharStringInterpreterLimits(isCFF1: isCFF1);

  final CharStringInterpreterLimits _limits;

  /// Returns true, if commands were compacted
  bool _tryToCompactSameOperator({
    required CharStringCommand prev,
    required CharStringCommand next,
  }) {
    final prevOpnds = prev.operandList;
    final currOpnds = next.operandList;

    final mergedArgLength = prevOpnds.length + currOpnds.length;

    if (mergedArgLength > _limits.argumentStackLimit) {
      // Can't optimize because of argument stack limit
      return false;
    }

    if (prev.operator != next.operator) {
      // Different operators
      return false;
    }

    final op = next.operator;

    if (op == CharStringOperator.rlineto.operator) {
      prevOpnds.addAll(currOpnds);
      return true;
    } else if (op == CharStringOperator.hlineto.operator ||
        op == CharStringOperator.vlineto.operator) {
      final prevIsOdd = prevOpnds.length.isOdd;
      final currIsOdd = currOpnds.length.isOdd;

      if (prevIsOdd &&
          currIsOdd &&
          prevOpnds.first.value == currOpnds.first.value) {
        currOpnds.removeAt(0);
        prevOpnds.addAll(currOpnds);
        return true;
      }
    } else if (op == CharStringOperator.rrcurveto.operator) {
      prevOpnds.addAll(currOpnds);
      return true;
    } else if (op == CharStringOperator.hhcurveto.operator ||
        op == CharStringOperator.vvcurveto.operator) {
      final prevHasDelta = prevOpnds.length % 4 != 0;
      final currHasDelta = currOpnds.length % 4 != 0;

      final p0prev = prevHasDelta ? prevOpnds.first : null;
      final p0 = currHasDelta ? currOpnds.first : null;

      // Is axis delta same for two curves
      if (p0?.value == p0prev?.value) {
        // Removing delta - it's already present in a previous command
        if (currHasDelta) {
          currOpnds.removeAt(0);
        }

        prevOpnds.addAll(currOpnds);
        return true;
      }
    }

    return false;
  }

  static List<CharStringCommand> _optimizeEmpty({
    required List<CharStringCommand> commandList,
  }) {
    return commandList.where((e) {
      final everyOperandIsZero = e.operandList.every((o) => o.value == 0);
      final isCurveToOperator = [
        CharStringOperator.rrcurveto.operator,
        CharStringOperator.vvcurveto.operator,
        CharStringOperator.hhcurveto.operator,
        CharStringOperator.vhcurveto.operator,
        CharStringOperator.hvcurveto.operator,
      ].contains(e.operator);

      if (isCurveToOperator) {
        return !everyOperandIsZero;
      }

      return true;
    }).toList();
  }

  List<CharStringCommand> _optimizeCommandsWithSameOperators(
    List<CharStringCommand> commandList,
  ) {
    if (commandList.isEmpty) {
      return [];
    }

    final newCommandList = <CharStringCommand>[commandList.first.copy()];

    for (var i = 1; i < commandList.length; i++) {
      final prev = newCommandList.last;
      final next = commandList[i].copy();

      final optimized = _tryToCompactSameOperator(prev: prev, next: next);
      if (!optimized) {
        newCommandList.add(next);
      }
    }

    return newCommandList;
  }

  List<CharStringCommand> optimize({
    required List<CharStringCommand> commandList,
  }) {
    return _optimizeCommandsWithSameOperators(
      _optimizeEmpty(commandList: commandList),
    );
  }
}

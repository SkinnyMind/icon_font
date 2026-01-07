import 'dart:typed_data';

import 'package:icon_font/src/otf/cff/dict.dart';
import 'package:icon_font/src/otf/cff/operand.dart';
import 'package:icon_font/src/otf/table/abstract.dart';
import 'package:icon_font/src/otf/table/cff1.dart';
import 'package:icon_font/src/otf/table/cff2.dart';
import 'package:icon_font/src/otf/table/table_record_entry.dart';
import 'package:icon_font/src/utils/logger.dart';

abstract class CFFTable extends FontTable {
  CFFTable.fromTableRecordEntry(super.entry) : super.fromTableRecordEntry();

  static CFFTable? fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
  }) {
    final major = byteData.getUint8(entry.offset);

    return switch (major) {
      0x0001 => CFF1Table.fromByteData(byteData: byteData, entry: entry),
      0x0002 => CFF2Table.fromByteData(byteData: byteData, entry: entry),
      _ => () {
        Log.unsupportedTableVersion('CFF', major);
        return null;
      }(),
    };
  }

  bool get isCFF1 => this is CFF1Table;
}

void calculateEntryOffsets({
  required List<CFFDictEntry> entryList,
  required List<int> offsetList,
  int? operandIndex,
  List<int>? operandIndexList,
}) {
  if (operandIndex == null && operandIndexList == null) {
    throw ArgumentError.notNull('Specify operand index');
  }

  bool sizeChanged;

  /// Iterating and changing offsets while operand size is changing
  /// A bit dirty, maybe there's easier way to do that
  do {
    sizeChanged = false;

    for (var i = 0; i < entryList.length; i++) {
      final entryOperandIndex = operandIndex ?? operandIndexList![i];
      final entry = entryList[i];
      final oldOperand = entry.operandList[entryOperandIndex];
      final newOperand = CFFOperand.fromValue(offsetList[i]);

      final sizeDiff = newOperand.size - oldOperand.size;

      if (oldOperand.value != newOperand.value) {
        entry.operandList.replaceRange(
          entryOperandIndex,
          entryOperandIndex + 1,
          [newOperand],
        );
      }

      if (sizeDiff > 0) {
        sizeChanged = true;

        for (var i = 0; i < offsetList.length; i++) {
          offsetList[i] += sizeDiff;
        }
      }
    }
  } while (sizeChanged);
}

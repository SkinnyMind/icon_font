import 'dart:typed_data';

import 'package:icon_font/src/common/calculatable_offsets.dart';
import 'package:icon_font/src/common/codable/binary.dart';
import 'package:icon_font/src/common/generic_glyph.dart';
import 'package:icon_font/src/otf/cff/char_string.dart';
import 'package:icon_font/src/otf/cff/char_string_operator.dart' as cs_op;
import 'package:icon_font/src/otf/cff/char_string_optimizer.dart';
import 'package:icon_font/src/otf/cff/dict.dart';
import 'package:icon_font/src/otf/cff/dict_operator.dart' as op;
import 'package:icon_font/src/otf/cff/index.dart';
import 'package:icon_font/src/otf/cff/operand.dart';
import 'package:icon_font/src/otf/cff/variations.dart';
import 'package:icon_font/src/otf/debugger.dart';
import 'package:icon_font/src/otf/table/abstract.dart';
import 'package:icon_font/src/otf/table/head.dart';
import 'package:icon_font/src/otf/table/hmtx.dart';
import 'package:icon_font/src/otf/table/name.dart';
import 'package:icon_font/src/otf/table/table_record_entry.dart';
import 'package:icon_font/src/utils/extensions.dart';
import 'package:icon_font/src/utils/konst.dart';

part '../cff/charset.dart';
part '../cff/standard_string.dart';
part 'cff1.dart';
part 'cff2.dart';

const _kMajorVersion1 = 0x0001;
const _kMajorVersion2 = 0x0002;

abstract class CFFTable extends FontTable {
  CFFTable.fromTableRecordEntry(super.entry) : super.fromTableRecordEntry();

  static CFFTable? fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
  }) {
    final major = byteData.getUint8(entry.offset);

    switch (major) {
      case _kMajorVersion1:
        return CFF1Table.fromByteData(byteData: byteData, entry: entry);
      case _kMajorVersion2:
        return CFF2Table.fromByteData(byteData: byteData, entry: entry);
    }

    debugUnsupportedTableVersion('CFF', major);
    return null;
  }

  bool get isCFF1 => this is CFF1Table;
}

void _calculateEntryOffsets({
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

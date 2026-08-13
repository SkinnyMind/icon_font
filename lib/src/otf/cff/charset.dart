import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/utils/constants.dart';
import 'package:icon_font/src/utils/extensions.dart';
import 'package:icon_font/src/utils/logger.dart';

abstract class const CharsetEntry({required final int format})
    implements BinaryCodable {
  static CharsetEntry? fromByteData({
    required ByteData byteData,
    required int glyphCount,
  }) {
    final format = byteData.getUint8(0);

    if (format == 1) {
      return CharsetEntryFormat1.fromByteData(
        byteData: byteData.sublistView(1),
        glyphCount: glyphCount,
      );
    } else {
      Log.unsupportedTableFormat('charsets', format);
      return null;
    }
  }
}

class const CharsetEntryFormat1({
  required super.format,
  required final List<Range1> rangeList,
}) extends CharsetEntry {
  factory fromByteData({required ByteData byteData, required int glyphCount}) {
    final rangeList = <Range1>[];

    var offset = 0;

    for (var i = 0; i < glyphCount - 1;) {
      final range = Range1.fromByteData(
        byteData: byteData.sublistView(offset, Range1.range1Size),
      );

      rangeList.add(range);

      i += 1 + range.nLeft;
      offset += range.size;
    }

    return CharsetEntryFormat1(format: 1, rangeList: rangeList);
  }

  factory create({required List<int> sIdList}) {
    final rangeList = <Range1>[];

    if (sIdList.isNotEmpty) {
      var prevSid = sIdList.first;
      var count = 1;

      int getNleft() => count - 1;

      void saveRange() {
        rangeList.add(Range1(sId: prevSid - count + 1, nLeft: getNleft()));
        count = 0;
      }

      for (var i = 1; i < sIdList.length; i++) {
        final sId = sIdList[i];
        final willOverflow = getNleft() + 1 > uInt8Max;

        if (willOverflow || prevSid + 1 != sId) {
          saveRange();
        }

        prevSid = sId;
        count++;
      }

      saveRange();
    }

    return CharsetEntryFormat1(format: 1, rangeList: rangeList);
  }

  @override
  void encodeToBinary(ByteData byteData) {
    byteData.setUint8(0, format);

    for (var i = 0; i < rangeList.length; i++) {
      rangeList[i].encodeToBinary(
        byteData.sublistView(1 + i * Range1.range1Size, Range1.range1Size),
      );
    }
  }

  @override
  int get size => 1 + rangeList.length * Range1.range1Size;
}

class const Range1({required final int sId, required final int nLeft})
    implements BinaryCodable {
  factory fromByteData({required ByteData byteData}) {
    return Range1(sId: byteData.getUint16(0), nLeft: byteData.getUint8(2));
  }

  static const range1Size = 3;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, sId)
      ..setUint8(2, nLeft);
  }

  @override
  int get size => range1Size;
}

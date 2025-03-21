part of '../table/cff.dart';

const _range1Size = 3;

abstract class CharsetEntry implements BinaryCodable {
  const CharsetEntry({required this.format});

  final int format;

  static CharsetEntry? fromByteData({
    required ByteData byteData,
    required int glyphCount,
  }) {
    final format = byteData.getUint8(0);

    switch (format) {
      case 1:
        return CharsetEntryFormat1.fromByteData(
          byteData: byteData.sublistView(1),
          glyphCount: glyphCount,
        );
      case 0:
      case 2:
      default:
        Log.unsupportedTableFormat('charsets', format);
    }

    return null;
  }
}

class CharsetEntryFormat1 extends CharsetEntry {
  CharsetEntryFormat1({required super.format, required this.rangeList});

  factory CharsetEntryFormat1.fromByteData({
    required ByteData byteData,
    required int glyphCount,
  }) {
    final rangeList = <Range1>[];

    var offset = 0;

    for (var i = 0; i < glyphCount - 1;) {
      final range = Range1.fromByteData(
        byteData: byteData.sublistView(offset, _range1Size),
      );

      rangeList.add(range);

      i += 1 + range.nLeft;
      offset += range.size;
    }

    return CharsetEntryFormat1(format: 1, rangeList: rangeList);
  }

  factory CharsetEntryFormat1.create({required List<int> sIdList}) {
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

  final List<Range1> rangeList;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData.setUint8(0, format);

    for (var i = 0; i < rangeList.length; i++) {
      rangeList[i].encodeToBinary(
        byteData.sublistView(1 + i * _range1Size, _range1Size),
      );
    }
  }

  @override
  int get size => 1 + rangeList.length * _range1Size;
}

class Range1 implements BinaryCodable {
  const Range1({required this.sId, required this.nLeft});

  factory Range1.fromByteData({required ByteData byteData}) {
    return Range1(sId: byteData.getUint16(0), nLeft: byteData.getUint8(2));
  }

  final int sId;
  final int nLeft;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, sId)
      ..setUint8(2, nLeft);
  }

  @override
  int get size => _range1Size;
}

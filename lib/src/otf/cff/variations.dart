import 'dart:typed_data';

import 'package:icon_font/src/common/codable/binary.dart';
import 'package:icon_font/src/utils/otf.dart';

const _kRegionAxisCoordinatesSize = 6;

class RegionAxisCoordinates extends BinaryCodable {
  RegionAxisCoordinates({
    required this.startCoord,
    required this.peakCoord,
    required this.endCoord,
  });

  factory RegionAxisCoordinates.fromByteData({required ByteData byteData}) {
    // NOTE: not converting F2DOT14, because variations are ignored anyway
    return RegionAxisCoordinates(
      startCoord: byteData.getUint16(0),
      peakCoord: byteData.getUint16(2),
      endCoord: byteData.getUint16(4),
    );
  }

  final int startCoord;
  final int peakCoord;
  final int endCoord;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, startCoord)
      ..setUint16(2, peakCoord)
      ..setUint16(4, endCoord);
  }

  @override
  int get size => _kRegionAxisCoordinatesSize;
}

class ItemVariationData extends BinaryCodable {
  ItemVariationData({
    required this.itemCount,
    required this.shortDeltaCount,
    required this.regionIndexCount,
    required this.regionIndexes,
  });

  factory ItemVariationData.fromByteData({required ByteData byteData}) {
    final regionIndexCount = byteData.getUint16(4);

    return ItemVariationData(
      itemCount: byteData.getUint16(0),
      shortDeltaCount: byteData.getUint16(2),
      regionIndexCount: regionIndexCount,
      regionIndexes:
          List.generate(regionIndexCount, (i) => byteData.getUint16(6 + 2 * i)),
    );
  }

  final int itemCount;
  final int shortDeltaCount;
  final int regionIndexCount;
  final List<int> regionIndexes;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, itemCount)
      ..setUint16(2, shortDeltaCount)
      ..setUint16(4, regionIndexCount);

    for (var i = 0; i < regionIndexCount; i++) {
      byteData.setUint16(6 + 2 * i, regionIndexes[i]);
    }
  }

  @override
  int get size => 6 + 2 * regionIndexCount;
}

class VariationRegionList extends BinaryCodable {
  VariationRegionList({
    required this.axisCount,
    required this.regionCount,
    required this.regions,
  });

  factory VariationRegionList.fromByteData({required ByteData byteData}) {
    final axisCount = byteData.getUint16(0);
    final regionCount = byteData.getUint16(2);

    final regions = [
      for (var r = 0; r < regionCount; r++)
        for (var a = 0; a < axisCount; a++)
          RegionAxisCoordinates.fromByteData(
            byteData: byteData.sublistView(
              4 + (a + r * axisCount) * _kRegionAxisCoordinatesSize,
              _kRegionAxisCoordinatesSize,
            ),
          ),
    ];

    return VariationRegionList(
      axisCount: axisCount,
      regionCount: regionCount,
      regions: regions,
    );
  }

  final int axisCount;
  final int regionCount;
  final List<RegionAxisCoordinates> regions;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, axisCount)
      ..setUint16(2, regionCount);

    for (var r = 0; r < regionCount; r++) {
      for (var a = 0; a < axisCount; a++) {
        final index = r * axisCount + a;
        final coords = regions[index];
        final coordsByteData = byteData.sublistView(
          4 + index * _kRegionAxisCoordinatesSize,
          _kRegionAxisCoordinatesSize,
        );
        coords.encodeToBinary(coordsByteData);
      }
    }
  }

  @override
  int get size => 4 + regionCount * axisCount * _kRegionAxisCoordinatesSize;
}

class ItemVariationStore extends BinaryCodable {
  ItemVariationStore({
    required this.format,
    required this.variationRegionListOffset,
    required this.itemVariationDataCount,
    required this.itemVariationDataOffsets,
    required this.variationRegionList,
    required this.itemVariationDataList,
  });

  factory ItemVariationStore.fromByteData({required ByteData byteData}) {
    final variationRegionListOffset = byteData.getUint32(2);
    final itemVariationDataCount = byteData.getUint16(6);
    final itemVariationDataOffsets = List.generate(
      itemVariationDataCount,
      (i) => byteData.getUint32(8 + 4 * i),
    );

    final variationRegionList = VariationRegionList.fromByteData(
      byteData: byteData.sublistView(variationRegionListOffset),
    );
    final itemVariationDataList = itemVariationDataOffsets
        .map(
          (o) =>
              ItemVariationData.fromByteData(byteData: byteData.sublistView(o)),
        )
        .toList();

    return ItemVariationStore(
      format: byteData.getUint16(0),
      variationRegionListOffset: variationRegionListOffset,
      itemVariationDataCount: itemVariationDataCount,
      itemVariationDataOffsets: itemVariationDataOffsets,
      variationRegionList: variationRegionList,
      itemVariationDataList: itemVariationDataList,
    );
  }

  final int format;
  int variationRegionListOffset;
  int itemVariationDataCount;
  List<int> itemVariationDataOffsets;

  final VariationRegionList variationRegionList;
  final List<ItemVariationData> itemVariationDataList;

  @override
  void encodeToBinary(ByteData byteData) {
    final variationRegionListSize = variationRegionList.size;
    itemVariationDataCount = itemVariationDataList.length;
    variationRegionListOffset = 8 + 4 * itemVariationDataCount;
    itemVariationDataOffsets = [];

    var offset = variationRegionListOffset + variationRegionListSize;

    for (var i = 0; i < itemVariationDataCount; i++) {
      final itemVariationData = itemVariationDataList[i];
      final itemSize = itemVariationData.size;
      itemVariationDataOffsets.add(offset);

      byteData.setUint32(8 + 4 * i, offset);
      itemVariationData.encodeToBinary(byteData.sublistView(offset, itemSize));

      offset += itemSize;
    }

    byteData
      ..setUint16(0, format)
      ..setUint32(2, variationRegionListOffset)
      ..setUint16(6, itemVariationDataCount);

    variationRegionList.encodeToBinary(
      byteData.sublistView(
        variationRegionListOffset,
        variationRegionListSize,
      ),
    );
  }

  int get _itemVariationSubtableListSize =>
      itemVariationDataList.fold<int>(0, (p, i) => p + i.size);

  @override
  int get size =>
      8 +
      4 * itemVariationDataCount +
      variationRegionList.size +
      _itemVariationSubtableListSize;
}

class VariationStoreData extends BinaryCodable {
  VariationStoreData({required this.length, required this.store});

  factory VariationStoreData.fromByteData({required ByteData byteData}) {
    return VariationStoreData(
      length: byteData.getUint16(0),
      store: ItemVariationStore.fromByteData(byteData: byteData.sublistView(2)),
    );
  }

  int length;
  final ItemVariationStore store;

  @override
  void encodeToBinary(ByteData byteData) {
    final storeSize = store.size;
    length = storeSize;
    byteData.setUint16(0, length);

    store.encodeToBinary(byteData.sublistView(2, storeSize));
  }

  @override
  int get size => 2 + store.size;
}

part of 'cff.dart';

const _cff2HeaderSize = 5;

class CFF2TableHeader implements BinaryCodable {
  CFF2TableHeader({
    required this.majorVersion,
    required this.minorVersion,
    required this.headerSize,
    required this.topDictLength,
  });

  factory CFF2TableHeader.fromByteData({required ByteData byteData}) {
    return CFF2TableHeader(
      majorVersion: byteData.getUint8(0),
      minorVersion: byteData.getUint8(1),
      headerSize: byteData.getUint8(2),
      topDictLength: byteData.getUint16(3),
    );
  }

  factory CFF2TableHeader.create() => CFF2TableHeader(
    majorVersion: 0x0002,
    minorVersion: 0,
    headerSize: _cff2HeaderSize,
    topDictLength: null,
  );

  final int majorVersion;
  final int minorVersion;
  final int headerSize;
  int? topDictLength;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint8(0, majorVersion)
      ..setUint8(1, minorVersion)
      ..setUint8(2, headerSize)
      ..setUint16(3, topDictLength!);
  }

  @override
  int get size => _cff2HeaderSize;
}

class CFF2Table extends CFFTable implements CalculatableOffsets {
  CFF2Table({
    required TableRecordEntry? entry,
    required this.header,
    required this.topDict,
    required this.globalSubrsData,
    required this.charStringsData,
    required this.vstoreData,
    required this.fontDictList,
    required this.privateDictList,
    required this.localSubrsDataList,
  }) : super.fromTableRecordEntry(entry);

  factory CFF2Table.fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
  }) {
    /// 3 entries with fixed location
    var fixedOffset = entry.offset;

    final header = CFF2TableHeader.fromByteData(
      byteData: byteData.sublistView(fixedOffset, _cff2HeaderSize),
    );
    fixedOffset += _cff2HeaderSize;

    final topDict = CFFDict.fromByteData(
      byteData.sublistView(fixedOffset, header.topDictLength!),
    );
    fixedOffset += header.topDictLength!;

    final globalSubrsData = CFFIndexWithData<Uint8List>.fromByteData(
      byteData: byteData.sublistView(fixedOffset),
      isCFF1: false,
    );
    fixedOffset += globalSubrsData.index!.size;

    /// CharStrings INDEX
    final charStringsIndexEntry = topDict.getEntryForOperator(
      operator: op.charStrings,
    )!;
    final charStringsIndexOffset =
        charStringsIndexEntry.operandList.first.value! as int;
    final charStringsIndexByteData = byteData.sublistView(
      entry.offset + charStringsIndexOffset,
    );

    final charStringsData = CFFIndexWithData<Uint8List>.fromByteData(
      byteData: charStringsIndexByteData,
      isCFF1: false,
    );

    /// VariationStore
    final vstoreEntry = topDict.getEntryForOperator(operator: op.vstore);
    VariationStoreData? vstoreData;

    if (vstoreEntry != null) {
      final vstoreOffset = vstoreEntry.operandList.first.value! as int;
      final vstoreByteData = byteData.sublistView(entry.offset + vstoreOffset);
      vstoreData = VariationStoreData.fromByteData(byteData: vstoreByteData);
    }

    // NOTE: not decoding FDSelect - using single Font DICT only

    /// Font DICT INDEX
    final fdArrayEntry = topDict.getEntryForOperator(operator: op.fdArray)!;
    final fdArrayOffset = fdArrayEntry.operandList.first.value! as int;

    final fontIndexByteData = byteData.sublistView(
      entry.offset + fdArrayOffset,
    );

    /// List of Font DICT
    final fontDictList = CFFIndexWithData<CFFDict>.fromByteData(
      byteData: fontIndexByteData,
      isCFF1: false,
    );

    /// Private DICT list
    final privateDictList = <CFFDict>[];

    /// Local subroutines for each Private DICT
    final localSubrsDataList = <CFFIndexWithData<Uint8List>>[];

    for (var i = 0; i < fontDictList.index!.count; i++) {
      final privateEntry = fontDictList.data[i].getEntryForOperator(
        operator: op.private,
      )!;
      final dictOffset =
          entry.offset + (privateEntry.operandList.last.value! as int);
      final dictLength = privateEntry.operandList.first.value! as int;
      final dictByteData = byteData.sublistView(dictOffset, dictLength);

      final dict = CFFDict.fromByteData(dictByteData);
      privateDictList.add(dict);

      final localSubrEntry = dict.getEntryForOperator(operator: op.subrs);

      if (localSubrEntry != null) {
        /// Offset from the start of the Private DICT
        final localSubrOffset = localSubrEntry.operandList.first.value! as int;

        final localSubrByteData = byteData.sublistView(
          dictOffset + localSubrOffset,
        );
        final localSubrsData = CFFIndexWithData<Uint8List>.fromByteData(
          byteData: localSubrByteData,
          isCFF1: false,
        );

        localSubrsDataList.add(localSubrsData);
      }
    }

    return CFF2Table(
      entry: entry,
      header: header,
      topDict: topDict,
      globalSubrsData: globalSubrsData,
      charStringsData: charStringsData,
      vstoreData: vstoreData,
      fontDictList: fontDictList,
      privateDictList: privateDictList,
      localSubrsDataList: localSubrsDataList,
    );
  }

  final CFF2TableHeader header;
  final CFFDict topDict;
  final CFFIndexWithData<Uint8List> globalSubrsData;
  final CFFIndexWithData<Uint8List> charStringsData;
  final VariationStoreData? vstoreData;
  final CFFIndexWithData<CFFDict> fontDictList;
  final List<CFFDict> privateDictList;
  final List<CFFIndexWithData<Uint8List>> localSubrsDataList;

  void _generateTopDictEntries() {
    final entryList = <CFFDictEntry>[
      CFFDictEntry(
        operandList: [CFFOperand.fromValue(0)],
        operator: op.charStrings,
      ),
      if (vstoreData != null)
        CFFDictEntry(
          operandList: [CFFOperand.fromValue(0)],
          operator: op.vstore,
        ),
      CFFDictEntry(
        operandList: [CFFOperand.fromValue(0)],
        operator: op.fdArray,
      ),
      // NOTE: not encoding FDSelect - using single Font DICT only
    ];

    topDict.entryList = entryList;
  }

  void _recalculateTopDictOffsets() {
    // Generating entries with zero-values
    _generateTopDictEntries();

    var offset = header.size + globalSubrsData.size + topDict.size;

    int? vstoreOffset;
    if (vstoreData != null) {
      vstoreOffset = offset;
      offset += vstoreData!.size;
    }

    final charStringsOffset = offset;
    offset += charStringsData.size;

    final fdArrayOffset = offset;
    offset += fontDictList.size;

    final vstoreEntry = topDict.getEntryForOperator(operator: op.vstore);
    final charStringsEntry = topDict.getEntryForOperator(
      operator: op.charStrings,
    )!;
    final fdArrayEntry = topDict.getEntryForOperator(operator: op.fdArray)!;

    final offsetList = [
      if (vstoreData != null) vstoreOffset!,
      charStringsOffset,
      fdArrayOffset,
    ];

    final entryList = [?vstoreEntry, charStringsEntry, fdArrayEntry];

    _calculateEntryOffsets(
      entryList: entryList,
      offsetList: offsetList,
      operandIndex: 0,
    );
  }

  @override
  void recalculateOffsets() {
    _recalculateTopDictOffsets();

    header.topDictLength = topDict.size;

    globalSubrsData.recalculateOffsets();
    fontDictList.recalculateOffsets();
    charStringsData.recalculateOffsets();

    // Recalculating font DICTs private offsets and SUBRS entries offsets
    final fdArrayEntry = topDict.getEntryForOperator(operator: op.fdArray)!;
    final fdArrayOffset = fdArrayEntry.operandList.first.value! as int;

    var fontDictOffset = fdArrayOffset + fontDictList.index!.size;

    for (var i = 0; i < fontDictList.data.length; i++) {
      final fontDict = fontDictList.data[i];
      final privateDict = privateDictList[i];
      final privateEntry = fontDict.getEntryForOperator(operator: op.private)!;

      final newOperands = [
        CFFOperand.fromValue(privateDict.size),
        CFFOperand.fromValue(0),
      ];
      privateEntry.operandList
        ..clear()
        ..addAll(newOperands);
      fontDictOffset += fontDict.size;

      final subrsEntry = privateDict.getEntryForOperator(operator: op.subrs);
      if (subrsEntry != null) {
        subrsEntry.operandList
          ..clear()
          ..add(CFFOperand.fromValue(0));
        subrsEntry.recalculatePointers(
          operandIndex: 0,
          valueCallback: () => privateDict.size,
        );
      }

      _calculateEntryOffsets(
        entryList: [privateEntry],
        offsetList: [fontDictOffset],
        operandIndex: 1,
      );
    }

    // Recalculating local subrs
    for (final localSubrs in localSubrsDataList) {
      localSubrs.recalculateOffsets();
    }
  }

  @override
  void encodeToBinary(ByteData byteData) {
    var offset = 0;

    header.encodeToBinary(byteData.sublistView(offset, header.size));
    offset += header.size;

    final topDictSize = topDict.size;
    topDict.encodeToBinary(byteData.sublistView(offset, topDictSize));
    offset += topDictSize;

    final globalSubrsSize = globalSubrsData.size;
    globalSubrsData.encodeToBinary(
      byteData.sublistView(offset, globalSubrsSize),
    );
    offset += globalSubrsSize;

    if (vstoreData != null) {
      final vstoreSize = vstoreData!.size;
      vstoreData!.encodeToBinary(byteData.sublistView(offset, vstoreSize));
      offset += vstoreSize;
    }

    final charStringsSize = charStringsData.size;
    charStringsData.encodeToBinary(
      byteData.sublistView(offset, charStringsSize),
    );
    offset += charStringsSize;

    final fontDictListSize = fontDictList.size;
    fontDictList.encodeToBinary(byteData.sublistView(offset, fontDictListSize));
    offset += fontDictListSize;

    for (var i = 0; i < fontDictList.data.length; i++) {
      final privateDict = privateDictList[i];
      final privateDictSize = privateDict.size;

      privateDict.encodeToBinary(byteData.sublistView(offset, privateDictSize));
      offset += privateDictSize;
    }

    for (final localSubrs in localSubrsDataList) {
      final localSubrsSize = localSubrs.size;
      localSubrs.encodeToBinary(byteData.sublistView(offset, localSubrsSize));
      offset += localSubrsSize;
    }
  }

  int get _privateDictListSize => privateDictList.fold(0, (p, d) => p + d.size);

  int get _localSubrsListSize =>
      localSubrsDataList.fold(0, (p, d) => p + d.size);

  @override
  int get size =>
      header.size +
      topDict.size +
      globalSubrsData.size +
      (vstoreData?.size ?? 0) +
      charStringsData.size +
      fontDictList.size +
      _privateDictListSize +
      _localSubrsListSize;
}

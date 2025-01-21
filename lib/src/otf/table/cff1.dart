part of 'cff.dart';

// NOTE: local subrs, encodings are omitted

class CFF1TableHeader implements BinaryCodable {
  CFF1TableHeader({
    required this.majorVersion,
    required this.minorVersion,
    required this.headerSize,
    required this.offSize,
  });

  factory CFF1TableHeader.fromByteData(ByteData byteData) {
    return CFF1TableHeader(
      majorVersion: byteData.getUint8(0),
      minorVersion: byteData.getUint8(1),
      headerSize: byteData.getUint8(2),
      offSize: byteData.getUint8(3),
    );
  }

  factory CFF1TableHeader.create() {
    return CFF1TableHeader(
      majorVersion: 1,
      minorVersion: 0,
      headerSize: 4,
      offSize: null,
    );
  }

  final int majorVersion;
  final int minorVersion;
  final int headerSize;
  int? offSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint8(0, majorVersion)
      ..setUint8(1, minorVersion)
      ..setUint8(2, headerSize)
      ..setUint8(3, offSize!);
  }

  @override
  int get size => 4;
}

class CFF1Table extends CFFTable implements CalculatableOffsets {
  CFF1Table({
    required TableRecordEntry? entry,
    required this.header,
    required this.nameIndex,
    required this.topDicts,
    required this.stringIndex,
    required this.globalSubrsData,
    required this.charsets,
    required this.charStringsData,
    required this.fontDictList,
    required this.privateDictList,
    required this.localSubrsDataList,
  }) : super.fromTableRecordEntry(entry);

  factory CFF1Table.fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
  }) {
    /// 3 entries with fixed location
    var fixedOffset = entry.offset;

    final header = CFF1TableHeader.fromByteData(
      byteData.sublistView(fixedOffset, _kCFF2HeaderSize),
    );
    fixedOffset += header.size;

    final nameIndex = CFFIndexWithData<Uint8List>.fromByteData(
      byteData: byteData.sublistView(fixedOffset),
      isCFF1: true,
    );
    fixedOffset += nameIndex.size;

    final topDicts = CFFIndexWithData<CFFDict>.fromByteData(
      byteData: byteData.sublistView(fixedOffset),
      isCFF1: true,
    );
    fixedOffset += topDicts.size;

    // NOTE: Using only first Top DICT
    final topDict = topDicts.data.first;

    /// String INDEX
    final stringIndex = CFFIndexWithData<Uint8List>.fromByteData(
      byteData: byteData.sublistView(fixedOffset),
      isCFF1: true,
    );
    fixedOffset += stringIndex.size;

    final globalSubrsData = CFFIndexWithData<Uint8List>.fromByteData(
      byteData: byteData.sublistView(fixedOffset),
      isCFF1: true,
    );
    fixedOffset += globalSubrsData.index!.size;

    /// CharStrings INDEX
    final charStringsIndexEntry =
        topDict.getEntryForOperator(operator: op.charStrings)!;
    final charStringsIndexOffset =
        charStringsIndexEntry.operandList.first.value! as int;
    final charStringsIndexByteData =
        byteData.sublistView(entry.offset + charStringsIndexOffset);

    final charStringsData = CFFIndexWithData<Uint8List>.fromByteData(
      byteData: charStringsIndexByteData,
      isCFF1: true,
    );

    /// Charsets
    final charsetsOffset = topDict
        .getEntryForOperator(operator: op.charset)!
        .operandList
        .first
        .value! as int;
    final charsetsByteData =
        byteData.sublistView(entry.offset + charsetsOffset);

    final charsetEntry = CharsetEntry.fromByteData(
      byteData: charsetsByteData,
      glyphCount: charStringsData.index!.count,
    )!;

    final privateEntry = topDict.getEntryForOperator(operator: op.private)!;
    final dictOffset =
        entry.offset + (privateEntry.operandList.last.value! as int);
    final dictLength = privateEntry.operandList.first.value! as int;
    final dictByteData = byteData.sublistView(dictOffset, dictLength);
    final privateDict = CFFDict.fromByteData(dictByteData);

    /// Private DICT list
    final privateDictList = <CFFDict>[privateDict];

    /// Local subroutines for each Private DICT
    final localSubrsDataList = <CFFIndexWithData<Uint8List>>[];

    // NOTE: reading only first local subrs
    final localSubrEntry = privateDict.getEntryForOperator(operator: op.subrs);
    if (localSubrEntry != null) {
      /// Offset from the start of the Private DICT
      final localSubrOffset = localSubrEntry.operandList.first.value! as int;

      final localSubrByteData =
          byteData.sublistView(dictOffset + localSubrOffset);
      final localSubrsData = CFFIndexWithData<Uint8List>.fromByteData(
        byteData: localSubrByteData,
        isCFF1: true,
      );

      localSubrsDataList.add(localSubrsData);
    }

    return CFF1Table(
      entry: entry,
      header: header,
      nameIndex: nameIndex,
      topDicts: topDicts,
      stringIndex: stringIndex,
      globalSubrsData: globalSubrsData,
      charsets: charsetEntry,
      charStringsData: charStringsData,
      fontDictList: CFFIndexWithData<CFFDict>.create(data: [], isCFF1: true),
      privateDictList: privateDictList,
      localSubrsDataList: localSubrsDataList,
    );
  }

  factory CFF1Table.create({
    required List<GenericGlyph> glyphList,
    required HeaderTable head,
    required HorizontalMetricsTable hmtx,
    required NamingTable name,
  }) {
    final header = CFF1TableHeader.create();
    var sidIndex = 391;
    final sidList = <int>[];
    final stringIndexDataList = <Uint8List>[];
    final ascii = RegExp(r'^[\x00-\x7F]+$');

    int putStringInIndex(String string) {
      var finalString = string;
      if (!ascii.hasMatch(finalString)) {
        finalString = 'Non-ascii character';
      }
      stringIndexDataList.add(Uint8List.fromList(finalString.codeUnits));
      sidList.add(sidIndex);
      return sidIndex++;
    }

    // excluding .notdef
    for (final g in glyphList.sublist(1)) {
      g.metadata.charCode == kUnicodeSpaceCharCode
          ? sidList.add(1)
          : putStringInIndex(g.metadata.name!);
    }

    final glyphSidList = [...sidList];

    final fontName = name.getStringByNameId(NameID.fullFontName)!;

    final topDictStringEntryMap = {
      op.version: name.getStringByNameId(NameID.version),
      op.fullName: fontName,
      op.weight: name.getStringByNameId(NameID.fontSubfamily),
    };

    final entryList = [
      for (final e in topDictStringEntryMap.entries)
        if (e.value != null)
          CFFDictEntry(
            operandList: [
              CFFOperand.fromValue(putStringInIndex(e.value!)),
            ],
            operator: e.key,
          ),
      CFFDictEntry(
        operandList: [
          CFFOperand.fromValue(head.xMin),
          CFFOperand.fromValue(head.yMin),
          CFFOperand.fromValue(head.xMax),
          CFFOperand.fromValue(head.yMax),
        ],
        operator: op.fontBBox,
      ),
    ];
    final topDicts = CFFIndexWithData.create(
      data: [CFFDict(entryList: entryList)],
      isCFF1: true,
    );
    final globalSubrsData = CFFIndexWithData<Uint8List>.create(
      data: [],
      isCFF1: true,
    );

    final charStringRawList = <Uint8List>[];

    for (var i = 0; i < glyphList.length; i++) {
      final glyph = glyphList[i].copy();

      for (final o in glyph.outlines) {
        o
          ..decompactImplicitPoints()
          ..quadToCubic();
      }

      final commandList = [
        ...glyph.toCharStringCommands(
          optimizer: CharStringOptimizer(isCFF1: true),
        ),
        CharStringCommand(operator: cs_op.endchar, operandList: []),
      ];
      final byteData = CharStringInterpreter(isCFF1: true).writeCommands(
        commandList: commandList,
        glyphWidth: hmtx.hMetrics[i].advanceWidth,
      );

      charStringRawList.add(byteData.buffer.asUint8List());
    }

    final charStringsData = CFFIndexWithData<Uint8List>.create(
      data: charStringRawList,
      isCFF1: true,
    );

    final fontDict = CFFDict.empty();

    final privateDict = CFFDict(
      entryList: [
        CFFDictEntry(
          operandList: [CFFOperand.fromValue(0)],
          operator: op.nominalWidthX,
        ),
      ],
    );

    final fontDictList = CFFIndexWithData<CFFDict>.create(
      data: [fontDict],
      isCFF1: true,
    );
    final privateDictList = [privateDict];
    final localSubrsDataList = <CFFIndexWithData<Uint8List>>[];

    final nameIndex = CFFIndexWithData<Uint8List>.create(
      data: [
        Uint8List.fromList(fontName.getPostScriptString().codeUnits),
      ],
      isCFF1: true,
    );
    final stringIndex = CFFIndexWithData<Uint8List>.create(
      data: stringIndexDataList,
      isCFF1: true,
    );

    final charsets = CharsetEntryFormat1.create(sIdList: glyphSidList);

    final table = CFF1Table(
      entry: null,
      header: header,
      nameIndex: nameIndex,
      topDicts: topDicts,
      stringIndex: stringIndex,
      globalSubrsData: globalSubrsData,
      charsets: charsets,
      charStringsData: charStringsData,
      fontDictList: fontDictList,
      privateDictList: privateDictList,
      localSubrsDataList: localSubrsDataList,
    )..recalculateOffsets();

    return table;
  }

  final CFF1TableHeader header;
  final CFFIndexWithData<Uint8List> nameIndex;
  final CFFIndexWithData<CFFDict> topDicts;
  final CFFIndexWithData<Uint8List> stringIndex;
  final CFFIndexWithData<Uint8List> globalSubrsData;
  final CharsetEntry charsets;
  final CFFIndexWithData<Uint8List> charStringsData;
  final CFFIndexWithData<CFFDict> fontDictList;
  final List<CFFDict> privateDictList;
  final List<CFFIndexWithData<Uint8List>> localSubrsDataList;

  CFFDict get topDict => topDicts.data.first;

  void _generateTopDictEntries() {
    final entryList = <CFFDictEntry>[
      CFFDictEntry(
        operandList: [CFFOperand.fromValue(0)],
        operator: op.charset,
      ),
      CFFDictEntry(
        operandList: [CFFOperand.fromValue(0)],
        operator: op.charStrings,
      ),
      CFFDictEntry(
        operandList: [
          CFFOperand.fromValue(privateDictList.first.size),
          CFFOperand.fromValue(0),
        ],
        operator: op.private,
      ),
    ];

    final operatorList = entryList.map((e) => e.operator).toList();

    topDict.entryList
      ..removeWhere((e) => operatorList.contains(e.operator))
      ..addAll(entryList);
  }

  void _recalculateTopDictOffsets() {
    // Generating entries with zero-values
    _generateTopDictEntries();

    var offset = _fixedSize;

    final charsetOffset = offset;
    offset += charsets.size;

    final charStringsOffset = offset;
    offset += charStringsData.size;

    // NOTE: Using only first private dict
    final privateDict = privateDictList.first;
    final privateDictOffset = offset;
    offset += privateDict.size;

    final charsetEntry = topDict.getEntryForOperator(operator: op.charset)!;
    final charStringsEntry =
        topDict.getEntryForOperator(operator: op.charStrings)!;
    final privateEntry = topDict.getEntryForOperator(operator: op.private)!;

    final offsetList = [
      charsetOffset,
      charStringsOffset,
      privateDictOffset,
    ];

    final entryList = [
      charsetEntry,
      charStringsEntry,
      privateEntry,
    ];

    _calculateEntryOffsets(
      entryList: entryList,
      offsetList: offsetList,
      operandIndexList: [0, 0, 1],
    );
  }

  @override
  void recalculateOffsets() {
    _recalculateTopDictOffsets();

    // Recalculating INDEXex
    nameIndex.recalculateOffsets();
    topDicts.recalculateOffsets();
    stringIndex.recalculateOffsets();
    globalSubrsData.recalculateOffsets();
    charStringsData.recalculateOffsets();
    fontDictList.recalculateOffsets();
    for (final e in localSubrsDataList) {
      e.recalculateOffsets();
    }

    // Last data offset
    final lastDataEntry = topDict.getEntryForOperator(operator: op.private)!;
    final lastDataOffset = lastDataEntry.operandList.last.value! as int;
    header.offSize = (lastDataOffset.bitLength / 8).ceil();
  }

  @override
  void encodeToBinary(ByteData byteData) {
    var offset = 0;

    header.encodeToBinary(byteData.sublistView(offset, header.size));
    offset += header.size;

    final nameIndexSize = nameIndex.size;
    nameIndex.encodeToBinary(byteData.sublistView(offset, nameIndexSize));
    offset += nameIndexSize;

    final topDictsSize = topDicts.size;
    topDicts.encodeToBinary(byteData.sublistView(offset, topDictsSize));
    offset += topDictsSize;

    final stringIndexSize = stringIndex.size;
    stringIndex.encodeToBinary(byteData.sublistView(offset, stringIndexSize));
    offset += stringIndexSize;

    final globalSubrsSize = globalSubrsData.size;
    globalSubrsData
        .encodeToBinary(byteData.sublistView(offset, globalSubrsSize));
    offset += globalSubrsSize;

    final charsetsSize = charsets.size;
    charsets.encodeToBinary(byteData.sublistView(offset, charsetsSize));
    offset += charsetsSize;

    final charStringsSize = charStringsData.size;
    charStringsData
        .encodeToBinary(byteData.sublistView(offset, charStringsSize));
    offset += charStringsSize;

    // NOTE: Using only first private dict
    final privateDict = privateDictList.first;
    final privateDictSize = privateDict.size;

    privateDict.encodeToBinary(byteData.sublistView(offset, privateDictSize));
    offset += privateDictSize;
  }

  int get _privateDictListSize => privateDictList.fold(0, (p, d) => p + d.size);

  int get _fixedSize =>
      header.size +
      nameIndex.size +
      topDicts.size +
      stringIndex.size +
      globalSubrsData.size;

  @override
  int get size =>
      _fixedSize + charsets.size + charStringsData.size + _privateDictListSize;
}

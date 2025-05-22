import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/otf/table/abstract.dart';
import 'package:icon_font/src/otf/table/table_record_entry.dart';
import 'package:icon_font/src/utils/extensions.dart';
import 'package:icon_font/src/utils/logger.dart';
import 'package:icon_font/src/utils/otf_utils.dart';

const _nameRecordSize = 12;

const _format0 = 0x0;

enum NameID {
  fontFamily,
  fontSubfamily,
  uniqueID,
  fullFontName,
  version,
  postScriptName,
  manufacturer,
  description,
}

/// List of name record templates, sorted by platform and encoding ID
const _nameRecordTemplateList = [
  /// Macintosh English with Roman encoding
  NameRecord.template(
    platformID: kPlatformMacintosh,
    encodingID: 0,
    languageID: 0,
  ),

  /// Windows English (US) with UTF-16BE encoding
  NameRecord.template(
    platformID: kPlatformWindows,
    encodingID: 1,
    languageID: 0x0409,
  ),
];

/// Returns an encoding function for given platform and encoding IDs
///
/// NOTE: There are more cases than this, but it will do for now.
List<int> Function(String) _getEncoder({required NameRecord record}) {
  return switch (record.platformID) {
    kPlatformWindows => (string) => [
      for (final code in string.codeUnits) ...[code >> 8, code & 0xFF],
    ],
    _ => (string) => string.codeUnits,
  };
}

/// Returns a decoding function for given platform and encoding IDs
///
/// NOTE: There are more cases than this, but it will do for now.
String Function(List<int>) _getDecoder({required NameRecord record}) {
  return switch (record.platformID) {
    kPlatformWindows => (byteList) => String.fromCharCodes([
      for (var i = 0; i < byteList.length; i += 2)
        byteList[i] << 8 | byteList[i + 1],
    ]),
    _ => String.fromCharCodes,
  };
}

class NameRecord implements BinaryCodable {
  NameRecord({
    required this.platformID,
    required this.encodingID,
    required this.languageID,
    required this.nameID,
    required this.length,
    required this.offset,
  });

  const NameRecord.template({
    required this.platformID,
    required this.encodingID,
    required this.languageID,
  }) : nameID = -1,
       length = -1,
       offset = -1;

  factory NameRecord.fromByteData({
    required ByteData byteData,
    required int offset,
  }) {
    final length = byteData.getUint16(offset + 8);
    final stringOffset = byteData.getUint16(offset + 10);

    return NameRecord(
      platformID: byteData.getUint16(offset),
      encodingID: byteData.getUint16(offset + 2),
      languageID: byteData.getUint16(offset + 4),
      nameID: byteData.getUint16(offset + 6),
      length: length,
      offset: stringOffset,
    );
  }

  final int platformID;
  final int encodingID;
  final int languageID;
  final int nameID;
  final int length;
  final int offset;

  NameRecord copyWith({
    int? platformID,
    int? encodingID,
    int? languageID,
    int? nameID,
    int? length,
    int? offset,
  }) {
    return NameRecord(
      platformID: platformID ?? this.platformID,
      encodingID: encodingID ?? this.encodingID,
      languageID: languageID ?? this.languageID,
      nameID: nameID ?? this.nameID,
      length: length ?? this.length,
      offset: offset ?? this.offset,
    );
  }

  @override
  int get size => _nameRecordSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, platformID)
      ..setUint16(2, encodingID)
      ..setUint16(4, languageID)
      ..setUint16(6, nameID)
      ..setUint16(8, length)
      ..setUint16(10, offset);
  }
}

class NamingTableFormat0Header implements BinaryCodable {
  NamingTableFormat0Header({
    required this.format,
    required this.count,
    required this.stringOffset,
    required this.nameRecordList,
  });

  factory NamingTableFormat0Header.create({
    required List<NameRecord> nameRecordList,
  }) {
    return NamingTableFormat0Header(
      format: _format0,
      count: nameRecordList.length,
      stringOffset: 6 + nameRecordList.length * _nameRecordSize,
      nameRecordList: nameRecordList,
    );
  }

  static NamingTableFormat0Header? fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
  }) {
    final format = byteData.getUint16(entry.offset);

    if (format != _format0) {
      Log.unsupportedTableFormat(entry.tag, format);
      return null;
    }

    final count = byteData.getUint16(entry.offset + 2);
    final stringOffset = byteData.getUint16(entry.offset + 4);
    final nameRecord = List.generate(
      count,
      (i) => NameRecord.fromByteData(
        byteData: byteData,
        offset: entry.offset + 6 + i * _nameRecordSize,
      ),
    );

    return NamingTableFormat0Header(
      format: format,
      count: count,
      stringOffset: stringOffset,
      nameRecordList: nameRecord,
    );
  }

  final int format;
  final int count;
  final int stringOffset;
  final List<NameRecord> nameRecordList;

  @override
  int get size => 6 + nameRecordList.length * _nameRecordSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, format)
      ..setUint16(2, count)
      ..setUint16(4, stringOffset);

    var recordOffset = 6;

    for (final record in nameRecordList) {
      record.encodeToBinary(byteData.sublistView(recordOffset, record.size));
      recordOffset += record.size;
    }
  }
}

abstract class NamingTable extends FontTable {
  NamingTable.fromTableRecordEntry({required TableRecordEntry? entry})
    : super.fromTableRecordEntry(entry);

  static NamingTable? fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
  }) {
    final format = byteData.getUint16(entry.offset);

    switch (format) {
      case _format0:
        return NamingTableFormat0.fromByteData(
          byteData: byteData,
          entry: entry,
        );
      default:
        Log.unsupportedTableFormat(kNameTag, format);
        return null;
    }
  }

  static NamingTable? create({
    required String fontName,
    required String? description,
    required Revision revision,
    int format = _format0,
  }) {
    switch (format) {
      case _format0:
        return NamingTableFormat0.create(
          fontName: fontName,
          description: description,
          revision: revision,
        );
      default:
        Log.unsupportedTableFormat(kNameTag, format);
        return null;
    }
  }

  String get familyName;

  String? getStringByNameId(NameID nameId);
}

class NamingTableFormat0 extends NamingTable {
  NamingTableFormat0({
    required this.header,
    required this.stringList,
    super.entry,
  }) : super.fromTableRecordEntry();

  factory NamingTableFormat0.create({
    required String fontName,
    required String? description,
    required Revision revision,
  }) {
    final stringForNameMap = <NameID, String>{
      NameID.fontFamily: fontName,
      NameID.fontSubfamily: 'Regular',
      NameID.uniqueID: fontName,
      NameID.fullFontName: fontName,
      NameID.version: 'Version ${revision.major}.${revision.minor}',
      NameID.postScriptName: fontName.getPostScriptString(),
      NameID.description: description ?? '',
    };

    final stringList = [
      for (var i = 0; i < _nameRecordTemplateList.length; i++)
        ...stringForNameMap.values,
    ];

    final recordList = <NameRecord>[];

    var stringOffset = 0;

    for (final recordTemplate in _nameRecordTemplateList) {
      for (final entry in stringForNameMap.entries) {
        final encoder = _getEncoder(record: recordTemplate);
        final units = encoder(entry.value);

        final record = recordTemplate.copyWith(
          nameID: NameID.values.indexOf(entry.key),
          length: units.length,
          offset: stringOffset,
        );

        recordList.add(record);
        stringOffset += units.length;
      }
    }

    final header = NamingTableFormat0Header.create(nameRecordList: recordList);

    return NamingTableFormat0(header: header, stringList: stringList);
  }

  static NamingTableFormat0? fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
  }) {
    final header = NamingTableFormat0Header.fromByteData(
      byteData: byteData,
      entry: entry,
    );

    if (header == null) {
      return null;
    }

    final storageAreaOffset = entry.offset + header.size;

    final stringList = [
      for (final record in header.nameRecordList)
        _getDecoder(record: record)(
          List.generate(
            record.length,
            (i) => byteData.getUint8(storageAreaOffset + record.offset + i),
          ),
        ),
    ];

    return NamingTableFormat0(
      entry: entry,
      header: header,
      stringList: stringList,
    );
  }

  final NamingTableFormat0Header header;
  final List<String> stringList;

  @override
  int get size =>
      header.size + header.nameRecordList.fold<int>(0, (p, r) => p + r.length);

  @override
  void encodeToBinary(ByteData byteData) {
    header.encodeToBinary(byteData.sublistView(0, header.size));

    final storageAreaOffset = header.size;

    for (var i = 0; i < header.nameRecordList.length; i++) {
      final record = header.nameRecordList[i];
      final string = stringList[i];

      var charOffset = storageAreaOffset + record.offset;
      final encoder = _getEncoder(record: record);
      final units = encoder(string);

      for (final charCode in units) {
        byteData.setUint8(charOffset++, charCode);
      }
    }
  }

  @override
  String get familyName => getStringByNameId(NameID.fontFamily)!;

  @override
  String? getStringByNameId(NameID nameId) {
    final nameID = NameID.values.indexOf(nameId);
    final familyIndex = header.nameRecordList.indexWhere(
      (e) => e.nameID == nameID,
    );

    if (familyIndex == -1) {
      return null;
    }

    return stringList[familyIndex];
  }
}

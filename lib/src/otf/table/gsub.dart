import 'dart:typed_data';

import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/otf/table/abstract.dart';
import 'package:icon_font/src/otf/table/feature_list.dart';
import 'package:icon_font/src/otf/table/lookup.dart';
import 'package:icon_font/src/otf/table/script_list.dart';
import 'package:icon_font/src/otf/table/table_record_entry.dart';
import 'package:icon_font/src/utils/extensions.dart';
import 'package:icon_font/src/utils/logger.dart';
import 'package:icon_font/src/utils/otf_utils.dart';

class GlyphSubstitutionTableHeader implements BinaryCodable {
  GlyphSubstitutionTableHeader({
    required this.majorVersion,
    required this.minorVersion,
    required this.scriptListOffset,
    required this.featureListOffset,
    required this.lookupListOffset,
    required this.featureVariationsOffset,
  });

  factory GlyphSubstitutionTableHeader.fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
  }) {
    final major = byteData.getUint16(entry.offset);
    final minor = byteData.getUint16(entry.offset + 2);
    final version = Revision(major, minor);

    final isV10 = version == const Revision(1, 0);

    if (!isV10) {
      Log.unsupportedTableVersion(kGSUBTag, version.int32value);
    }

    return GlyphSubstitutionTableHeader(
      majorVersion: major,
      minorVersion: minor,
      scriptListOffset: byteData.getUint16(entry.offset + 4),
      featureListOffset: byteData.getUint16(entry.offset + 6),
      lookupListOffset: byteData.getUint16(entry.offset + 8),
      featureVariationsOffset: isV10
          ? null
          : byteData.getUint32(entry.offset + 10),
    );
  }

  factory GlyphSubstitutionTableHeader.create() {
    return GlyphSubstitutionTableHeader(
      majorVersion: 1,
      minorVersion: 0,
      scriptListOffset: null,
      featureListOffset: null,
      lookupListOffset: null,
      featureVariationsOffset: null,
    );
  }

  final int majorVersion;
  final int minorVersion;
  int? scriptListOffset;
  int? featureListOffset;
  int? lookupListOffset;
  int? featureVariationsOffset;

  bool get isV10 => majorVersion == 1 && minorVersion == 0;

  @override
  int get size => isV10 ? 10 : 12;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, majorVersion)
      ..setUint16(2, minorVersion)
      ..setUint16(4, scriptListOffset!)
      ..setUint16(6, featureListOffset!)
      ..setUint16(8, lookupListOffset!);

    if (!isV10) {
      byteData.getUint32(10);
    }
  }
}

class GlyphSubstitutionTable extends FontTable {
  GlyphSubstitutionTable({
    required TableRecordEntry? entry,
    required this.header,
    required this.scriptListTable,
    required this.featureListTable,
    required this.lookupListTable,
  }) : super.fromTableRecordEntry(entry);

  factory GlyphSubstitutionTable.fromByteData({
    required ByteData byteData,
    required TableRecordEntry entry,
  }) {
    final header = GlyphSubstitutionTableHeader.fromByteData(
      byteData: byteData,
      entry: entry,
    );

    final scriptListTable = ScriptListTable.fromByteData(
      byteData: byteData,
      offset: entry.offset + header.scriptListOffset!,
    );
    final featureListTable = FeatureListTable.fromByteData(
      byteData: byteData,
      offset: entry.offset + header.featureListOffset!,
    );
    final lookupListTable = LookupListTable.fromByteData(
      byteData: byteData,
      offset: entry.offset + header.lookupListOffset!,
    );

    return GlyphSubstitutionTable(
      entry: entry,
      header: header,
      scriptListTable: scriptListTable,
      featureListTable: featureListTable,
      lookupListTable: lookupListTable,
    );
  }

  factory GlyphSubstitutionTable.create() {
    final header = GlyphSubstitutionTableHeader.create();

    final scriptListTable = ScriptListTable.create();
    final featureListTable = FeatureListTable.create();
    final lookupListTable = LookupListTable.create();

    return GlyphSubstitutionTable(
      entry: null,
      header: header,
      scriptListTable: scriptListTable,
      featureListTable: featureListTable,
      lookupListTable: lookupListTable,
    );
  }

  final GlyphSubstitutionTableHeader header;

  final ScriptListTable scriptListTable;
  final FeatureListTable featureListTable;
  final LookupListTable lookupListTable;

  @override
  void encodeToBinary(ByteData byteData) {
    var relativeOffset = header.size;

    scriptListTable.encodeToBinary(
      byteData.sublistView(relativeOffset, scriptListTable.size),
    );
    header.scriptListOffset = relativeOffset;
    relativeOffset += scriptListTable.size;

    featureListTable.encodeToBinary(
      byteData.sublistView(relativeOffset, featureListTable.size),
    );
    header.featureListOffset = relativeOffset;
    relativeOffset += featureListTable.size;

    lookupListTable.encodeToBinary(
      byteData.sublistView(relativeOffset, lookupListTable.size),
    );
    header.lookupListOffset = relativeOffset;
    relativeOffset += lookupListTable.size;

    header.encodeToBinary(byteData.sublistView(0, header.size));
  }

  @override
  int get size =>
      header.size +
      scriptListTable.size +
      featureListTable.size +
      lookupListTable.size;
}

import 'dart:typed_data';

import 'package:meta/meta.dart';

const String kHeadTag = 'head';
const String kGSUBTag = 'GSUB';
const String kOS2Tag = 'OS/2';
const String kCmapTag = 'cmap';
const String kGlyfTag = 'glyf';
const String kHheaTag = 'hhea';
const String kHmtxTag = 'hmtx';
const String kLocaTag = 'loca';
const String kMaxpTag = 'maxp';
const String kNameTag = 'name';
const String kPostTag = 'post';
const String kCFFTag = 'CFF ';
const String kCFF2Tag = 'CFF2';

const kPlatformUnicode = 0;
const kPlatformMacintosh = 1;
const kPlatformWindows = 3;

class OtfUtils {
  const OtfUtils._();

  static Uint8List convertStringToTag(String string) {
    assert(string.length == 4, "Tag's length must be equal 4");
    return Uint8List.fromList(string.codeUnits);
  }

  static bool checkBitMask({required int value, required int mask}) =>
      (value & mask) == mask;

  static int calculateTableChecksum({required ByteData encodedTable}) {
    final length = (encodedTable.lengthInBytes / 4).floor();

    var sum = 0;

    for (var i = 0; i < length; i++) {
      sum = (sum + encodedTable.getUint32(4 * i)).toUnsigned(32);
    }

    final notAlignedBytesLength = encodedTable.lengthInBytes % 4;

    if (notAlignedBytesLength > 0) {
      final endBytes = [
        // Reading remaining bytes
        for (var i = 4 * length; i < encodedTable.lengthInBytes; i++)
          encodedTable.getUint8(i),

        // Filling with zeroes
        for (var i = 0; i < 4 - notAlignedBytesLength; i++) 0,
      ];

      var endValue = 0;

      for (final byte in endBytes) {
        endValue <<= 8;
        endValue += byte;
      }

      sum = (sum + endValue).toUnsigned(32);
    }

    return sum;
  }

  static int calculateFontChecksum({required ByteData byteData}) {
    final checkSumMagicNumber = 0xB1B0AFBA;
    return (checkSumMagicNumber -
            calculateTableChecksum(encodedTable: byteData))
        .toUnsigned(32);
  }

  static int getPaddedTableSize({required int actualSize}) =>
      (actualSize / 4).ceil() * 4;

  /// Tells if integer is 1 byte long
  static bool isShortInteger(int number) => number >= -0xFF && number <= 0xFF;

  /// Converts relative coordinates to absolute ones
  static List<int> relToAbsCoordinates({required List<int> relCoordinates}) {
    if (relCoordinates.isEmpty) {
      return [];
    }

    final absCoordinates = List.filled(relCoordinates.length, 0);
    var currentValue = 0;

    for (var i = 0; i < relCoordinates.length; i++) {
      currentValue += relCoordinates[i];
      absCoordinates[i] = currentValue;
    }

    return absCoordinates;
  }

  /// Converts absolute coordinates to relative ones
  static List<int> absToRelCoordinates({required List<int> absCoordinates}) {
    if (absCoordinates.isEmpty) {
      return [];
    }

    final relCoordinates = List.filled(absCoordinates.length, 0);
    var prevValue = 0;

    for (var i = 0; i < absCoordinates.length; i++) {
      relCoordinates[i] = absCoordinates[i] - prevValue;
      prevValue = absCoordinates[i];
    }

    return relCoordinates;
  }
}

@immutable
class Revision {
  const Revision(int? major, int? minor)
      : major = major ?? 0,
        minor = minor ?? 0;

  const Revision.fromInt32(int revision)
      : major = (revision >> 16) & 0xFFFF,
        minor = revision & 0xFFFF;

  final int major;
  final int minor;

  int get int32value => major * 0x10000 + minor;

  @override
  int get hashCode {
    var hash = 17;
    hash = hash * 31 + major.hashCode;
    hash = hash * 31 + minor.hashCode;
    return hash;
  }

  @override
  bool operator ==(Object other) {
    if (other is Revision) {
      return major == other.major && minor == other.minor;
    }

    return false;
  }
}

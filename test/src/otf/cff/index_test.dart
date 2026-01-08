import 'dart:typed_data';
import 'package:icon_font/src/otf/cff/index.dart';
import 'package:test/test.dart';

void main() {
  group('CFFIndexWithData', () {
    test('empty INDEX encoding (CFF1)', () {
      final cffIndex = CFFIndexWithData<Uint8List>.create(
        data: [],
        isCFF1: true,
      );

      // CFF1 empty index is just 2 bytes of count
      expect(cffIndex.size, equals(2));

      final bytes = ByteData(cffIndex.size);
      cffIndex.encodeToBinary(bytes);

      expect(bytes.getUint16(0), equals(0));
    });

    test('single item encoding (CFF1)', () {
      final cffIndex = CFFIndexWithData<Uint8List>.create(
        data: [
          Uint8List.fromList([0xAA, 0xBB]),
        ],
        isCFF1: true,
      );

      // Structure: Count(2) + OffSize(1) + Offsets(1*2) + Data(2) = 7 bytes
      // Offset list should be [1, 3]
      expect(cffIndex.size, equals(7));

      final bytes = ByteData(cffIndex.size);
      cffIndex.encodeToBinary(bytes);

      expect(bytes.getUint16(0), equals(1)); // Count
      expect(bytes.getUint8(2), equals(1)); // OffSize
      expect(bytes.getUint8(3), equals(1)); // Offset 1
      expect(bytes.getUint8(4), equals(3)); // Offset 2
      expect(bytes.getUint8(5), equals(0xAA)); // Data
      expect(bytes.getUint8(6), equals(0xBB));
    });

    test('memoization: size and encodeToBinary reuse cached index', () {
      final list = Uint8List.fromList([0x01]);
      final data = [list];
      final cffIndex = CFFIndexWithData<Uint8List>.create(
        data: data,
        isCFF1: true,
      );

      final firstSize = cffIndex.size;

      data[0] = Uint8List.fromList([0x01, 0x02]);

      final secondSize = cffIndex.size;
      expect(firstSize, equals(secondSize), reason: 'Size should be memoized');

      cffIndex.recalculateOffsets();
      expect(
        cffIndex.size,
        isNot(equals(firstSize)),
        reason: 'Cache should be cleared',
      );
    });

    test('offSize increases correctly with large data', () {
      // Create data larger than 255 bytes to force offSize 2
      final largeData = Uint8List(300);
      final cffIndex = CFFIndexWithData<Uint8List>.create(
        data: [largeData],
        isCFF1: true,
      );

      // Count(2) + OffSize(1) + Offsets(2*2) + Data(300) = 307
      expect(cffIndex.size, equals(307));

      final bytes = ByteData(cffIndex.size);
      cffIndex.encodeToBinary(bytes);

      expect(
        bytes.getUint8(2),
        equals(2),
        reason: 'OffSize should be 2 for 301 offset',
      );
      expect(bytes.getUint16(3), equals(1)); // First offset (1) in 2 bytes
      expect(bytes.getUint16(5), equals(301)); // Second offset (301) in 2 bytes
    });

    test('CFF2 Header size (4-byte count)', () {
      final cffIndex = CFFIndexWithData<Uint8List>.create(
        data: [],
        isCFF1: false,
      );

      expect(cffIndex.size, 4);

      final bytes = ByteData(4);
      cffIndex.encodeToBinary(bytes);
      expect(bytes.getUint32(0), equals(0));
    });

    test('fromByteData roundtrip', () {
      final originalData = [
        Uint8List.fromList([0x12, 0x34]),
        Uint8List.fromList([0x56]),
      ];
      final original = CFFIndexWithData<Uint8List>.create(
        data: originalData,
        isCFF1: true,
      );
      original.recalculateOffsets();

      final buffer = ByteData(original.size);
      original.encodeToBinary(buffer);

      final decoded = CFFIndexWithData<Uint8List>.fromByteData(
        byteData: buffer,
        isCFF1: true,
      );

      expect(decoded.data.length, equals(2));
      expect(decoded.data[0], equals(originalData[0]));
      expect(decoded.data[1], equals(originalData[1]));
    });
  });
}

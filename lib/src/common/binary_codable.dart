import 'dart:typed_data';

/// A class that supports both encoding and decoding to/from binary representation
///
/// Implementations should have factory `.fromByteData`.
abstract class BinaryCodable {
  /// Calculates and returns size of the object (in bytes)
  int get size;

  /// Encodes the object to binary data
  void encodeToBinary(ByteData byteData);
}

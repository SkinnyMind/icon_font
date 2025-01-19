import 'dart:typed_data';

import 'package:icon_font_generator/src/otf/otf.dart';

/// A helper for writing an OpenType font as a binary data.
class OTFWriter {
  /// Writes OpenType font as a binary data.
  ByteData write({required OpenTypeFont font}) {
    final byteData = ByteData(font.size);
    font.encodeToBinary(byteData);

    return byteData;
  }
}

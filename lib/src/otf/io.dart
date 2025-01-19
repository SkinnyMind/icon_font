import 'dart:io';
import 'dart:typed_data';

import 'package:icon_font/src/otf/otf.dart';
import 'package:icon_font/src/otf/reader.dart';
import 'package:icon_font/src/otf/writer.dart';
import 'package:icon_font/src/utils/logger.dart';
import 'package:path/path.dart' as p;

/// Reads OpenType font from a file.
OpenTypeFont readFromFile({required String path}) =>
    OTFReader.fromByteData(ByteData.sublistView(File(path).readAsBytesSync()))
        .read();

/// Writes OpenType font to a file.
void writeToFile({required String path, required OpenTypeFont font}) {
  final file = File(path);
  file.createSync(recursive: true);
  final byteData = OTFWriter().write(font: font);
  final extension = p.extension(file.path).toLowerCase();

  if (extension != '.otf' && font.isOpenType) {
    logger.w('A font that contains only CFF outline data should have an '
        '.OTF extension.');
  }

  file.writeAsBytesSync(byteData.buffer.asUint8List());
}

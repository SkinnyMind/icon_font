import 'package:icon_font_generator/src/common/codable/binary.dart';
import 'package:icon_font_generator/src/otf/table/table_record_entry.dart';

abstract class FontTable implements BinaryCodable {
  FontTable.fromTableRecordEntry(this.entry);

  TableRecordEntry? entry;
}

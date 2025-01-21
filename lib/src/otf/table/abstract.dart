import 'package:icon_font/src/common/binary_codable.dart';
import 'package:icon_font/src/otf/table/table_record_entry.dart';

abstract class FontTable implements BinaryCodable {
  FontTable.fromTableRecordEntry(this.entry);

  TableRecordEntry? entry;
}

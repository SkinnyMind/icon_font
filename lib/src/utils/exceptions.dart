class TableDataFormatException implements Exception {
  TableDataFormatException(this.message);

  final String message;

  @override
  String toString() => 'Table data format exception: $message';
}

class ChecksumException implements Exception {
  ChecksumException.font() : entityName = 'font';
  ChecksumException.table({required String tableName})
    : entityName = '$tableName table';

  final String entityName;

  @override
  String toString() => 'Wrong checksum for $entityName';
}

class SvgParserException implements Exception {
  SvgParserException({required this.message});

  final String message;

  @override
  String toString() => 'SvgParserException($message)';
}

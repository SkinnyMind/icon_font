class TableDataFormatException(final String message) implements Exception {
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

class SvgParserException({required final String message}) implements Exception {
  @override
  String toString() => 'SvgParserException($message)';
}

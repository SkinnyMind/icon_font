import 'package:logger/logger.dart';

class Log {
  const Log._();

  static final Logger logger = Logger(
    filter: ProductionFilter(),
    printer: SimplePrinter(),
    level: Level.info,
  );
  static final Set<int> _loggedOnce = {};

  static void once(Level level, Object message) {
    final hashCode = message.hashCode;

    if (_loggedOnce.contains(hashCode)) {
      return;
    }

    logger.log(level, message);
    _loggedOnce.add(hashCode);
  }

  static void unsupportedTableVersion(String tableName, int version) =>
      logger.w('Unsupported $tableName table version: $version');

  static void unsupportedTableFormat(String tableName, int format) =>
      logger.w('Unsupported $tableName table format: $format');
}

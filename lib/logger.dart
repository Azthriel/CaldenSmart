// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

var printLog = Logger(
  printer: PrettyPrinter(
    methodCount: 4,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

class FileOutput extends LogOutput {
  FileOutput({
    required File file,
    bool overrideExisting = false,
    Encoding encoding = utf8,
  }) {
    throw UnsupportedError("Not supported on this platform.");
  }

  @override
  void output(OutputEvent event) {
    throw UnsupportedError("Not supported on this platform.");
  }
}

/// Accumulates logs in a buffer to reduce frequent disk, writes while optionally
/// switching to a new log file if it reaches a certain size.
///
/// [AdvancedFileOutput] offer various improvements over the original
/// [FileOutput]:
/// * Managing an internal buffer which collects the logs and only writes
/// them after a certain period of time to the disk.
/// * Dynamically switching log files instead of using a single one specified
/// by the user, when the current file reaches a specified size limit (optionally).
///
/// The buffered output can significantly reduce the
/// frequency of file writes, which can be beneficial for (micro-)SD storage
/// and other types of low-cost storage (e.g. on IoT devices). Specific log
/// levels can trigger an immediate flush, without waiting for the next timer
/// tick.
///
/// New log files are created when the current file reaches the specified size
/// limit. This is useful for writing "archives" of telemetry data and logs
/// while keeping them structured.
class AdvancedFileOutput extends LogOutput {
  /// Creates a buffered file output.
  ///
  /// By default, the log is buffered until either the [maxBufferSize] has been
  /// reached, the timer controlled by [maxDelay] has been triggered or an
  /// [OutputEvent] contains a [writeImmediately] log level.
  ///
  /// [maxFileSizeKB] controls the log file rotation. The output automatically
  /// switches to a new log file as soon as the current file exceeds it.
  /// Use -1 to disable log rotation.
  ///
  /// [maxDelay] describes the maximum amount of time before the buffer has to be
  /// written to the file.
  ///
  /// Any log levels that are specified in [writeImmediately] trigger an immediate
  /// flush to the disk ([Level.warning], [Level.error] and [Level.fatal] by default).
  ///
  /// [path] is either treated as directory for rotating or as target file name,
  /// depending on [maxFileSizeKB].
  ///
  /// [maxRotatedFilesCount] controls the number of rotated files to keep. By default
  /// is null, which means no limit.
  /// If set to a positive number, the output will keep the last
  /// [maxRotatedFilesCount] files. The deletion step will be executed by sorting
  /// files following the [fileSorter] ascending strategy and keeping the last files.
  /// The [latestFileName] will not be counted. The default [fileSorter] strategy is
  /// sorting by last modified date, beware that could be not reliable in some
  /// platforms and/or filesystems.
  AdvancedFileOutput({
    required String path,
    bool overrideExisting = false,
    Encoding encoding = utf8,
    List<Level>? writeImmediately,
    Duration maxDelay = const Duration(seconds: 2),
    int maxBufferSize = 2000,
    int maxFileSizeKB = 1024,
    String latestFileName = 'latest.log',
    String Function(DateTime timestamp)? fileNameFormatter,
    int? maxRotatedFilesCount,
    Comparator<File>? fileSorter,
    Duration fileUpdateDuration = const Duration(minutes: 1),
  }) {
    throw UnsupportedError("Not supported on this platform.");
  }

  @override
  void output(OutputEvent event) {
    throw UnsupportedError("Not supported on this platform.");
  }
}

class AnsiColor {
  /// ANSI Control Sequence Introducer, signals the terminal for new settings.
  static const ansiEsc = '\x1B[';

  /// Reset all colors and options for current SGRs to terminal defaults.
  static const ansiDefault = '${ansiEsc}0m';

  final int? fg;
  final int? bg;
  final bool color;

  const AnsiColor.none()
      : fg = null,
        bg = null,
        color = false;

  const AnsiColor.fg(this.fg)
      : bg = null,
        color = true;

  const AnsiColor.bg(this.bg)
      : fg = null,
        color = true;

  @override
  String toString() {
    if (fg != null) {
      return '${ansiEsc}38;5;${fg}m';
    } else if (bg != null) {
      return '${ansiEsc}48;5;${bg}m';
    } else {
      return '';
    }
  }

  String call(String msg) {
    if (color) {
      // ignore: unnecessary_brace_in_string_interps
      return '${this}$msg$ansiDefault';
    } else {
      return msg;
    }
  }

  AnsiColor toFg() => AnsiColor.fg(bg);

  AnsiColor toBg() => AnsiColor.bg(fg);

  /// Defaults the terminal's foreground color without altering the background.
  String get resetForeground => color ? '${ansiEsc}39m' : '';

  /// Defaults the terminal's background color without altering the foreground.
  String get resetBackground => color ? '${ansiEsc}49m' : '';

  static int grey(double level) => 232 + (level.clamp(0.0, 1.0) * 23).round();
}

typedef DateTimeFormatter = String Function(DateTime time);

class DateTimeFormat {
  /// Omits the date and time completely.
  static const DateTimeFormatter none = _none;

  /// Prints only the time.
  ///
  /// Example:
  /// * `12:30:40.550`
  static const DateTimeFormatter onlyTime = _onlyTime;

  /// Prints only the time including the difference since [PrettyPrinter.startTime].
  ///
  /// Example:
  /// * `12:30:40.550 (+0:00:00.060700)`
  static const DateTimeFormatter onlyTimeAndSinceStart = _onlyTimeAndSinceStart;

  /// Prints only the date.
  ///
  /// Example:
  /// * `2019-06-04`
  static const DateTimeFormatter onlyDate = _onlyDate;

  /// Prints date and time (combines [onlyDate] and [onlyTime]).
  ///
  /// Example:
  /// * `2019-06-04 12:30:40.550`
  static const DateTimeFormatter dateAndTime = _dateAndTime;

  DateTimeFormat._();

  static String _none(DateTime t) => throw UnimplementedError();

  static String _onlyTime(DateTime t) {
    String threeDigits(int n) {
      if (n >= 100) return '$n';
      if (n >= 10) return '0$n';
      return '00$n';
    }

    String twoDigits(int n) {
      if (n >= 10) return '$n';
      return '0$n';
    }

    var now = t;
    var h = twoDigits(now.hour);
    var min = twoDigits(now.minute);
    var sec = twoDigits(now.second);
    var ms = threeDigits(now.millisecond);
    return '$h:$min:$sec.$ms';
  }

  static String _onlyTimeAndSinceStart(DateTime t) {
    var timeSinceStart = t.difference(PrettyPrinter.startTime!).toString();
    return '${onlyTime(t)} (+$timeSinceStart)';
  }

  static String _onlyDate(DateTime t) {
    String isoDate = t.toIso8601String();
    return isoDate.substring(0, isoDate.indexOf("T"));
  }

  static String _dateAndTime(DateTime t) {
    return "${_onlyDate(t)} ${_onlyTime(t)}";
  }
}

/// Prints all logs with `level >= Logger.level` while in development mode (eg
/// when `assert`s are evaluated, Flutter calls this debug mode).
///
/// In release mode ALL logs are omitted.
class DevelopmentFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    var shouldLog = false;
    assert(() {
      if (event.level.value >= level!.value) {
        shouldLog = true;
      }
      return true;
    }());
    return shouldLog;
  }
}

/// Prints all logs with `level >= Logger.level` even in production.
class ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return event.level.value >= level!.value;
  }
}

class LogEvent {
  final Level level;
  final dynamic message;
  final Object? error;
  final StackTrace? stackTrace;
  final DateTime time;
  String? customColor; // <-- Nuevo campo

  LogEvent(
    this.level,
    this.message, {
    DateTime? time,
    this.error,
    this.stackTrace,
  }) : time = time ?? DateTime.now();
}

/// An abstract filter of log messages.
///
/// You can implement your own `LogFilter` or use [DevelopmentFilter].
/// Every implementation should consider [Logger.level].
abstract class LogFilter {
  Level? _level;

  // Still nullable for backwards compatibility.
  Level? get level => _level ?? Logger.level;

  set level(Level? value) => _level = value;

  Future<void> init() async {}

  /// Is called every time a new log message is sent and decides if
  /// it will be printed or canceled.
  ///
  /// Returns `true` if the message should be logged.
  bool shouldLog(LogEvent event);

  Future<void> destroy() async {}
}

/// [Level]s to control logging output. Logging can be enabled to include all
/// levels above certain [Level].
enum Level {
  all(0),
  trace(1000),
  info(3000),
  error(5000),
  off(10000),
  ;

  final int value;

  const Level(this.value);
}

/// Log output receives a [OutputEvent] from [LogPrinter] and sends it to the
/// desired destination.
///
/// This can be an output stream, a file or a network target. [LogOutput] may
/// cache multiple log messages.
abstract class LogOutput {
  Future<void> init() async {}

  void output(OutputEvent event);

  Future<void> destroy() async {}
}

/// An abstract handler of log events.
///
/// A log printer creates and formats the output, which is then sent to
/// [LogOutput]. Every implementation has to use the [LogPrinter.log]
/// method to send the output.
///
/// You can implement a `LogPrinter` from scratch or extend [PrettyPrinter].
abstract class LogPrinter {
  Future<void> init() async {}

  /// Is called every time a new [LogEvent] is sent and handles printing or
  /// storing the message.
  List<String> log(LogEvent event);

  Future<void> destroy() async {}
}

typedef LogCallback = void Function(LogEvent event);

typedef OutputCallback = void Function(OutputEvent event);

/// Use instances of logger to send log messages to the [LogPrinter].
class Logger {
  /// The current logging level of the app.
  ///
  /// All logs with levels below this level will be omitted.
  static Level level = Level.trace;

  /// The current default implementation of log filter.
  static LogFilter Function() defaultFilter = () => DevelopmentFilter();

  /// The current default implementation of log printer.
  static LogPrinter Function() defaultPrinter = () => PrettyPrinter();

  /// The current default implementation of log output.
  static LogOutput Function() defaultOutput = () => ConsoleOutput();

  static final Set<LogCallback> _logCallbacks = {};

  static final Set<OutputCallback> _outputCallbacks = {};

  late final Future<void> _initialization;
  final LogFilter _filter;
  final LogPrinter _printer;
  final LogOutput _output;
  bool _active = true;

  /// Create a new instance of Logger.
  ///
  /// You can provide a custom [printer], [filter] and [output]. Otherwise the
  /// defaults: [PrettyPrinter], [DevelopmentFilter] and [ConsoleOutput] will be
  /// used.
  Logger({
    LogFilter? filter,
    LogPrinter? printer,
    LogOutput? output,
    Level? level,
  })  : _filter = filter ?? defaultFilter(),
        _printer = printer ?? defaultPrinter(),
        _output = output ?? defaultOutput() {
    var filterInit = _filter.init();
    if (level != null) {
      _filter.level = level;
    }
    var printerInit = _printer.init();
    var outputInit = _output.init();
    _initialization = Future.wait([filterInit, printerInit, outputInit]);
  }

  /// Future indicating if the initialization of the
  /// logger components (filter, printer and output) has been finished.
  ///
  /// This is only necessary if your [LogFilter]/[LogPrinter]/[LogOutput]
  /// uses `async` in their `init` method.
  Future<void> get init => _initialization;

  /// Log a message at level [Level.trace].
  ///
  /// [color] puede ser: 'rojo', 'verde', 'azul', 'amarillo', 'naranja', 'violeta', 'cyan', 'gris', 'blanco', 'negro', 'rosa', 'lima', 'marron'
  void t(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    String? color,
  }) {
    log(Level.trace, message,
        time: time, error: error, stackTrace: stackTrace, color: color);
  }

  /// Log a message at level [Level.info].
  ///
  /// [color] puede ser: 'rojo', 'verde', 'azul', 'amarillo', 'naranja', 'violeta', 'cyan', 'gris', 'blanco', 'negro', 'rosa', 'lima', 'marron'
  void i(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    String? color,
  }) {
    log(Level.info, message,
        time: time, error: error, stackTrace: stackTrace, color: color);
  }

  /// Log a message at level [Level.error].
  ///
  /// [color] puede ser: 'rojo', 'verde', 'azul', 'amarillo', 'naranja', 'violeta', 'cyan', 'gris', 'blanco', 'negro', 'rosa', 'lima', 'marron'
  void e(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    String? color,
  }) {
    log(Level.error, message,
        time: time, error: error, stackTrace: stackTrace, color: color);
  }

  /// Log a message with [level].
  void log(
    Level level,
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
    String? color,
  }) {
    if (!_active) {
      throw ArgumentError('Logger has already been closed.');
    } else if (error != null && error is StackTrace) {
      throw ArgumentError('Error parameter cannot take a StackTrace!');
    } else if (level == Level.all) {
      throw ArgumentError('Log events cannot have Level.all');
    }

    var logEvent = LogEvent(
      level,
      message,
      time: time,
      error: error,
      stackTrace: stackTrace,
    );
    logEvent.customColor = color;
    for (var callback in _logCallbacks) {
      callback(logEvent);
    }

    if (_filter.shouldLog(logEvent)) {
      var output = _printer.log(logEvent);

      if (output.isNotEmpty) {
        var outputEvent = OutputEvent(logEvent, output);
        // Issues with log output should NOT influence
        // the main software behavior.
        try {
          for (var callback in _outputCallbacks) {
            callback(outputEvent);
          }
          _output.output(outputEvent);
        } catch (e, s) {
          print(e);
          print(s);
        }
      }
    }
  }

  bool isClosed() {
    return !_active;
  }

  /// Closes the logger and releases all resources.
  Future<void> close() async {
    _active = false;
    await _filter.destroy();
    await _printer.destroy();
    await _output.destroy();
  }

  /// Register a [LogCallback] which is called for each new [LogEvent].
  static void addLogListener(LogCallback callback) {
    _logCallbacks.add(callback);
  }

  /// Removes a [LogCallback] which was previously registered.
  ///
  /// Returns whether the callback was successfully removed.
  static bool removeLogListener(LogCallback callback) {
    return _logCallbacks.remove(callback);
  }

  /// Register an [OutputCallback] which is called for each new [OutputEvent].
  static void addOutputListener(OutputCallback callback) {
    _outputCallbacks.add(callback);
  }

  /// Removes a [OutputCallback] which was previously registered.
  ///
  /// Returns whether the callback was successfully removed.
  static void removeOutputListener(OutputCallback callback) {
    _outputCallbacks.remove(callback);
  }
}

class OutputEvent {
  final List<String> lines;
  final LogEvent origin;

  Level get level => origin.level;

  OutputEvent(this.origin, this.lines);
}

/// Default implementation of [LogOutput].
///
/// It sends everything to the system console.
class ConsoleOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    event.lines.forEach(print);
  }
}

/// Buffers [OutputEvent]s.
class MemoryOutput extends LogOutput {
  /// Maximum events in [buffer].
  final int bufferSize;

  /// A secondary [LogOutput] to also received events.
  final LogOutput? secondOutput;

  /// The buffer of events.
  final ListQueue<OutputEvent> buffer;

  MemoryOutput({this.bufferSize = 20, this.secondOutput})
      : buffer = ListQueue(bufferSize);

  @override
  void output(OutputEvent event) {
    if (buffer.length == bufferSize) {
      buffer.removeFirst();
    }

    buffer.add(event);

    secondOutput?.output(event);
  }
}

/// Logs simultaneously to multiple [LogOutput] outputs.
class MultiOutput extends LogOutput {
  late List<LogOutput> _outputs;

  MultiOutput(List<LogOutput?>? outputs) {
    _outputs = _normalizeOutputs(outputs);
  }

  List<LogOutput> _normalizeOutputs(List<LogOutput?>? outputs) {
    final normalizedOutputs = <LogOutput>[];

    if (outputs != null) {
      for (final output in outputs) {
        if (output != null) {
          normalizedOutputs.add(output);
        }
      }
    }

    return normalizedOutputs;
  }

  @override
  Future<void> init() async {
    await Future.wait(_outputs.map((e) => e.init()));
  }

  @override
  void output(OutputEvent event) {
    for (var o in _outputs) {
      o.output(event);
    }
  }

  @override
  Future<void> destroy() async {
    await Future.wait(_outputs.map((e) => e.destroy()));
  }
}

class StreamOutput extends LogOutput {
  late StreamController<List<String>> _controller;
  bool _shouldForward = false;

  StreamOutput() {
    _controller = StreamController<List<String>>(
      onListen: () => _shouldForward = true,
      onPause: () => _shouldForward = false,
      onResume: () => _shouldForward = true,
      onCancel: () => _shouldForward = false,
    );
  }

  Stream<List<String>> get stream => _controller.stream;

  @override
  void output(OutputEvent event) {
    if (!_shouldForward) {
      return;
    }

    _controller.add(event.lines);
  }

  @override
  Future<void> destroy() {
    return _controller.close();
  }
}

/// A decorator for a [LogPrinter] that allows for the composition of
/// different printers to handle different log messages. Provide it's
/// constructor with a base printer, but include named parameters for
/// any levels that have a different printer:
///
/// ```
/// HybridPrinter(PrettyPrinter(), debug: SimplePrinter());
/// ```
///
/// Will use the pretty printer for all logs except Level.debug
/// logs, which will use SimplePrinter().
class HybridPrinter extends LogPrinter {
  final Map<Level, LogPrinter> _printerMap;

  HybridPrinter(
    LogPrinter realPrinter, {
    LogPrinter? trace,
    LogPrinter? info,
    LogPrinter? error,
  }) : _printerMap = {
          Level.trace: trace ?? realPrinter,
          Level.info: info ?? realPrinter,
          Level.error: error ?? realPrinter,
        };

  @override
  List<String> log(LogEvent event) =>
      _printerMap[event.level]?.log(event) ?? [];
}

/// Outputs a logfmt message:
/// ```
/// level=debug msg="hi there" time="2015-03-26T01:27:38-04:00" animal=walrus number=8 tag=usum
/// ```
class LogfmtPrinter extends LogPrinter {
  static final levelPrefixes = {
    Level.trace: 'trace',
    Level.info: 'info',
    Level.error: 'error',
  };

  @override
  List<String> log(LogEvent event) {
    var output = StringBuffer('level=${levelPrefixes[event.level]}');
    if (event.message is String) {
      output.write(' msg="${event.message}"');
    } else if (event.message is Map) {
      event.message.entries.forEach((entry) {
        if (entry.value is num) {
          output.write(' ${entry.key}=${entry.value}');
        } else {
          output.write(' ${entry.key}="${entry.value}"');
        }
      });
    }
    if (event.error != null) {
      output.write(' error="${event.error}"');
    }

    return [output.toString()];
  }
}

/// A decorator for a [LogPrinter] that allows for the prepending of every
/// line in the log output with a string for the level of that log. For
/// example:
///
/// ```
/// PrefixPrinter(PrettyPrinter());
/// ```
///
/// Would prepend "DEBUG" to every line in a debug log. You can supply
/// parameters for a custom message for a specific log level.
class PrefixPrinter extends LogPrinter {
  final LogPrinter _realPrinter;
  late Map<Level, String> _prefixMap;

  PrefixPrinter(
    this._realPrinter, {
    String? trace,
    String? info,
    String? error,
  }) {
    _prefixMap = {
      Level.trace: trace ?? 'TRACE',
      Level.info: info ?? 'INFO',
      Level.error: error ?? 'ERROR',
    };

    var len = _longestPrefixLength();
    _prefixMap.forEach((k, v) => _prefixMap[k] = '${v.padLeft(len)} ');
  }

  @override
  List<String> log(LogEvent event) {
    var realLogs = _realPrinter.log(event);
    return realLogs.map((s) => '${_prefixMap[event.level]}$s').toList();
  }

  int _longestPrefixLength() {
    compFunc(String a, String b) => a.length > b.length ? a : b;
    return _prefixMap.values.reduce(compFunc).length;
  }
}

/// Default implementation of [LogPrinter].
///
/// Output looks like this:
/// ```
/// ┌──────────────────────────
/// │ Error info
/// ├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
/// │ Method stack history
/// ├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
/// │ Log message
/// └──────────────────────────
/// ```
class PrettyPrinter extends LogPrinter {
  static const topLeftCorner = '┌';
  static const bottomLeftCorner = '└';
  static const middleCorner = '├';
  static const verticalLine = '│';
  static const doubleDivider = '─';
  static const singleDivider = '┄';

  static final Map<Level, AnsiColor> defaultLevelColors = {
    Level.trace: const AnsiColor.fg(12),
    Level.info: const AnsiColor.fg(12),
    Level.error: const AnsiColor.fg(12),
  };

  static final Map<Level, String> defaultLevelEmojis = {
    Level.trace: '',
    Level.info: '💡',
    Level.error: '⛔',
  };

  /// Matches a stacktrace line as generated on Android/iOS devices.
  ///
  /// For example:
  /// * #1      Logger.log (package:logger/src/logger.dart:115:29)
  static final _deviceStackTraceRegex = RegExp(r'#[0-9]+\s+(.+) \((\S+)\)');

  /// Matches a stacktrace line as generated by Flutter web.
  ///
  /// For example:
  /// * packages/logger/src/printers/pretty_printer.dart 91:37
  static final _webStackTraceRegex = RegExp(r'^((packages|dart-sdk)/\S+/)');

  /// Matches a stacktrace line as generated by browser Dart.
  ///
  /// For example:
  /// * dart:sdk_internal
  /// * package:logger/src/logger.dart
  static final _browserStackTraceRegex =
      RegExp(r'^(?:package:)?(dart:\S+|\S+)');

  static DateTime? startTime;

  /// The index at which the stack trace should start.
  ///
  /// This can be useful if, for instance, Logger is wrapped in another class and
  /// you wish to remove these wrapped calls from stack trace
  ///
  /// See also:
  /// * [excludePaths]
  final int stackTraceBeginIndex;

  /// Controls the method count in stack traces
  /// when no [LogEvent.error] was provided.
  ///
  /// In case no [LogEvent.stackTrace] was provided,
  /// [StackTrace.current] will be used to create one.
  ///
  /// * Set to `0` in order to disable printing a stack trace
  /// without an error parameter.
  /// * Set to `null` to remove the method count limit all together.
  ///
  /// See also:
  /// * [errorMethodCount]
  final int? methodCount;

  /// Controls the method count in stack traces
  /// when [LogEvent.error] was provided.
  ///
  /// In case no [LogEvent.stackTrace] was provided,
  /// [StackTrace.current] will be used to create one.
  ///
  /// * Set to `0` in order to disable printing a stack trace
  /// in case of an error parameter.
  /// * Set to `null` to remove the method count limit all together.
  ///
  /// See also:
  /// * [methodCount]
  final int? errorMethodCount;

  /// Controls the length of the divider lines.
  final int lineLength;

  /// Whether ansi colors are used to color the output.
  final bool colors;

  /// Whether emojis are prefixed to the log line.
  final bool printEmojis;

  /// Controls the format of [LogEvent.time].
  final DateTimeFormatter dateTimeFormat;

  /// Controls the ascii 'boxing' of different [Level]s.
  ///
  /// By default all levels are 'boxed',
  /// to prevent 'boxing' of a specific level,
  /// include it with `true` in the map.
  ///
  /// Example to prevent boxing of [Level.trace] and [Level.info]:
  /// ```dart
  /// excludeBox: {
  ///   Level.trace: true,
  ///   Level.info: true,
  /// },
  /// ```
  ///
  /// See also:
  /// * [noBoxingByDefault]
  final Map<Level, bool> excludeBox;

  /// Whether the implicit `bool`s in [excludeBox] are `true` or `false` by default.
  ///
  /// By default all levels are 'boxed',
  /// this flips the default to no boxing for all levels.
  /// Individual boxing can still be turned on for specific
  /// levels by setting them manually to `false` in [excludeBox].
  ///
  /// Example to specifically activate 'boxing' of [Level.error]:
  /// ```dart
  /// noBoxingByDefault: true,
  /// excludeBox: {
  ///   Level.error: false,
  /// },
  /// ```
  ///
  /// See also:
  /// * [excludeBox]
  final bool noBoxingByDefault;

  /// A list of custom paths that are excluded from the stack trace.
  ///
  /// For example, to exclude your `MyLog` util that redirects to this logger:
  /// ```dart
  /// excludePaths: [
  ///   // To exclude a whole package
  ///   "package:test",
  ///   // To exclude a single file
  ///   "package:test/util/my_log.dart",
  /// ],
  /// ```
  ///
  /// See also:
  /// * [stackTraceBeginIndex]
  final List<String> excludePaths;

  /// Contains the parsed rules resulting from [excludeBox] and [noBoxingByDefault].
  late final Map<Level, bool> _includeBox;
  String _topBorder = '';
  String _middleBorder = '';
  String _bottomBorder = '';

  /// Controls the colors used for the different log levels.
  ///
  /// Default fallbacks are modifiable via [defaultLevelColors].
  final Map<Level, AnsiColor>? levelColors;

  /// Controls the emojis used for the different log levels.
  ///
  /// Default fallbacks are modifiable via [defaultLevelEmojis].
  final Map<Level, String>? levelEmojis;

  PrettyPrinter({
    this.stackTraceBeginIndex = 0,
    this.methodCount = 2,
    this.errorMethodCount = 8,
    this.lineLength = 120,
    this.colors = true,
    this.printEmojis = true,
    bool? printTime,
    DateTimeFormatter dateTimeFormat = DateTimeFormat.none,
    this.excludeBox = const {},
    this.noBoxingByDefault = false,
    this.excludePaths = const [],
    this.levelColors,
    this.levelEmojis,
  })  : assert(
            (printTime != null && dateTimeFormat == DateTimeFormat.none) ||
                printTime == null,
            "Don't set printTime when using dateTimeFormat"),
        dateTimeFormat = printTime == null
            ? dateTimeFormat
            : (printTime
                ? DateTimeFormat.onlyTimeAndSinceStart
                : DateTimeFormat.none) {
    startTime ??= DateTime.now();

    var doubleDividerLine = StringBuffer();
    var singleDividerLine = StringBuffer();
    for (var i = 0; i < lineLength - 1; i++) {
      doubleDividerLine.write(doubleDivider);
      singleDividerLine.write(singleDivider);
    }

    _topBorder = '$topLeftCorner$doubleDividerLine';
    _middleBorder = '$middleCorner$singleDividerLine';
    _bottomBorder = '$bottomLeftCorner$doubleDividerLine';

    // Translate excludeBox map (constant if default) to includeBox map with all Level enum possibilities
    _includeBox = {};
    for (var l in Level.values) {
      _includeBox[l] = !noBoxingByDefault;
    }
    excludeBox.forEach((k, v) => _includeBox[k] = !v);
  }

  @override
  List<String> log(LogEvent event) {
    var messageStr = stringifyMessage(event.message);

    String? stackTraceStr;
    if (event.error != null) {
      if ((errorMethodCount == null || errorMethodCount! > 0)) {
        stackTraceStr = formatStackTrace(
          event.stackTrace ?? StackTrace.current,
          errorMethodCount,
        );
      }
    } else if (methodCount == null || methodCount! > 0) {
      stackTraceStr = formatStackTrace(
        event.stackTrace ?? StackTrace.current,
        methodCount,
      );
    }

    var errorStr = event.error?.toString();

    String? timeStr;

    return _formatAndPrint(
      event.level,
      messageStr,
      timeStr,
      errorStr,
      stackTraceStr,
      event.customColor,
    );
  }

  String? formatStackTrace(StackTrace? stackTrace, int? methodCount) {
    List<String> lines = stackTrace
        .toString()
        .split('\n')
        .where(
          (line) =>
              !_discardDeviceStacktraceLine(line) &&
              !_discardWebStacktraceLine(line) &&
              !_discardBrowserStacktraceLine(line) &&
              line.isNotEmpty,
        )
        .toList();
    List<String> formatted = [];
    int startIndex = stackTraceBeginIndex + 3;
    int stackTraceLength = (methodCount != null
        ? min(lines.length - startIndex, methodCount)
        : lines.length - startIndex);
    for (int count = 0; count < stackTraceLength; count++) {
      var lineIndex = count + startIndex;
      if (lineIndex >= lines.length) break;
      var line = lines[lineIndex];
      formatted.add('#$count   ${line.replaceFirst(RegExp(r'#\d+\s+'), '')}');
    }

    if (formatted.isEmpty) {
      return null;
    } else {
      return formatted.join('\n');
    }
  }

  bool _isInExcludePaths(String segment) {
    for (var element in excludePaths) {
      if (segment.startsWith(element)) {
        return true;
      }
    }
    return false;
  }

  bool _discardDeviceStacktraceLine(String line) {
    var match = _deviceStackTraceRegex.matchAsPrefix(line);
    if (match == null) {
      return false;
    }
    final segment = match.group(2)!;
    if (segment.startsWith('package:logger')) {
      return true;
    }
    return _isInExcludePaths(segment);
  }

  bool _discardWebStacktraceLine(String line) {
    var match = _webStackTraceRegex.matchAsPrefix(line);
    if (match == null) {
      return false;
    }
    final segment = match.group(1)!;
    if (segment.startsWith('packages/logger') ||
        segment.startsWith('dart-sdk/lib')) {
      return true;
    }
    return _isInExcludePaths(segment);
  }

  bool _discardBrowserStacktraceLine(String line) {
    var match = _browserStackTraceRegex.matchAsPrefix(line);
    if (match == null) {
      return false;
    }
    final segment = match.group(1)!;
    if (segment.startsWith('package:logger') || segment.startsWith('dart:')) {
      return true;
    }
    return _isInExcludePaths(segment);
  }

  String getTime(DateTime time) {
    return dateTimeFormat(time);
  }

  // Handles any object that is causing JsonEncoder() problems
  Object toEncodableFallback(dynamic object) {
    return object.toString();
  }

  String stringifyMessage(dynamic message) {
    final finalMessage = message is Function ? message() : message;
    if (finalMessage is Map || finalMessage is Iterable) {
      var encoder = JsonEncoder.withIndent('  ', toEncodableFallback);
      return encoder.convert(finalMessage);
    } else {
      return finalMessage.toString();
    }
  }

  AnsiColor _getLevelColor(Level level, [String? customColor]) {
    if (customColor != null) {
      switch (customColor.toLowerCase()) {
        case 'rojo':
          return const AnsiColor.fg(196);
        case 'verde':
          return const AnsiColor.fg(46);
        case 'azul':
          return const AnsiColor.fg(21);
        case 'amarillo':
          return const AnsiColor.fg(226);
        case 'naranja':
          return const AnsiColor.fg(208);
        case 'violeta':
          return const AnsiColor.fg(93);
        case 'cyan':
          return const AnsiColor.fg(51);
        case 'gris':
          return const AnsiColor.fg(244);
        case 'blanco':
          return const AnsiColor.fg(15);
        case 'negro':
          return const AnsiColor.fg(0);
        case 'rosa':
          return const AnsiColor.fg(205);
        case 'lima':
          return const AnsiColor.fg(118);
        case 'marron':
          return const AnsiColor.fg(94);
      }
    }

    AnsiColor? color;
    if (colors) {
      color = levelColors?[level] ?? defaultLevelColors[level];
    }
    return color ?? const AnsiColor.fg(12);
  }

  String _getEmoji(Level level) {
    if (printEmojis) {
      final String? emoji = levelEmojis?[level] ?? defaultLevelEmojis[level];
      if (emoji != null) {
        return '$emoji ';
      }
    }
    return '';
  }

  List<String> _formatAndPrint(Level level, String message, String? time,
      String? error, String? stacktrace,
      [String? customColor]) {
    List<String> buffer = [];
    var verticalLineAtLevel = (_includeBox[level]!) ? ('$verticalLine ') : '';
    var color = _getLevelColor(level, customColor);
    if (_includeBox[level]!) buffer.add(color(_topBorder));

    if (error != null) {
      for (var line in error.split('\n')) {
        buffer.add(color('$verticalLineAtLevel$line'));
      }
      if (_includeBox[level]!) buffer.add(color(_middleBorder));
    }

    if (stacktrace != null) {
      for (var line in stacktrace.split('\n')) {
        buffer.add(color('$verticalLineAtLevel$line'));
      }
      if (_includeBox[level]!) buffer.add(color(_middleBorder));
    }

    if (time != null) {
      buffer.add(color('$verticalLineAtLevel$time'));
      if (_includeBox[level]!) buffer.add(color(_middleBorder));
    }

    var emoji = _getEmoji(level);
    for (var line in message.split('\n')) {
      buffer.add(color('$verticalLineAtLevel$emoji$line'));
    }
    if (_includeBox[level]!) buffer.add(color(_bottomBorder));

    return buffer;
  }
}

/// Outputs simple log messages:
/// ```
/// [E] Log message  ERROR: Error info
/// ```
class SimplePrinter extends LogPrinter {
  static final levelPrefixes = {
    Level.trace: '[T]',
    Level.info: '[I]',
    Level.error: '[E]',
  };

  static final levelColors = {
    Level.trace: const AnsiColor.fg(12),
    Level.info: const AnsiColor.fg(12),
    Level.error: const AnsiColor.fg(12),
  };

  final bool printTime;
  final bool colors;

  SimplePrinter({this.printTime = false, this.colors = true});

  @override
  List<String> log(LogEvent event) {
    var messageStr = _stringifyMessage(event.message);
    var errorStr = event.error != null ? '  ERROR: ${event.error}' : '';
    var timeStr = printTime ? 'TIME: ${event.time.toIso8601String()}' : '';
    return ['${_labelFor(event.level)} $timeStr $messageStr$errorStr'];
  }

  String _labelFor(Level level) {
    var prefix = levelPrefixes[level]!;
    var color = levelColors[level]!;

    return colors ? color(prefix) : prefix;
  }

  String _stringifyMessage(dynamic message) {
    final finalMessage = message is Function ? message() : message;
    if (finalMessage is Map || finalMessage is Iterable) {
      var encoder = const JsonEncoder.withIndent(null);
      return encoder.convert(finalMessage);
    } else {
      return finalMessage.toString();
    }
  }
}

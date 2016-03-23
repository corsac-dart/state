library corsac_state;

import 'dart:mirrors';

part 'src/type_handlers.dart';

class State {
  /// If annotated field has non-null `view` it will only be included in
  /// snapshots generated for that view.
  final dynamic view;

  /// If set to `true` then field will be excluded from all snapshots,
  /// regardless of view setting.
  final bool exclude;

  const State({this.view, this.exclude: false});

  /// Takes a "state snapshot" of [object].
  ///
  /// If [view] parameter is not null then resulting snapshot will include
  /// fields without associated `view` plus those which are associated with this
  /// view.
  ///
  /// If [formatter] parameter is provided it will be used to format all values.
  /// If snapshot has been created with a formatter it will not be possible to use
  /// it for restoring, since original type information is lost.
  static Map<String, dynamic> snapshot(object,
      {dynamic view, StateFormatter formatter}) {
    var tm = reflect(object).type;
    var handler = TypeHandler.getHandlerFor(tm.reflectedType);
    return handler.extract(tm.reflectedType, object,
        view: view, formatter: formatter);
  }

  /// Restores object of specified [type] from a state [snapshot].
  static Object restore(Type type, snapshot) =>
      TypeHandler.getHandlerFor(type).hydrate(type, snapshot);
}

class ScalarObject {
  const ScalarObject();
}

abstract class StateFormatter {
  /// Normalizes values of a state snapshot to be directly JSON encodable.
  /// As a result the whole snapshot should also be JSON encodable.
  ///
  /// See details in [JsonStateFormatter].
  static const StateFormatter JSON = const JsonStateFormatter();

  dynamic format(value);
}

/// Normalizes values of a state snapshot to be directly JSON encodable.
/// As a result the whole snapshot should also be JSON encodable.
///
/// This formatter will convert:
///
/// * `DateTime` objects into ISO-8601 strings.
/// * `Uri` objects into strings using `Uri.toString()`.
///
/// More built-in standard types will be added.
/// It will pass through everything else.
class JsonStateFormatter implements StateFormatter {
  const JsonStateFormatter();

  @override
  format(value) {
    if (value is DateTime) {
      return value.toIso8601String();
    } else if (value is Uri) {
      return value.toString();
    } else {
      return value;
    }
  }
}

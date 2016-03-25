library corsac_state;

import 'dart:mirrors';
import 'package:intl/intl.dart';

part 'src/type_handlers.dart';
part 'src/format.dart';

class State {
  /// If annotated field has non-null `view` it will only be included in
  /// snapshots generated for that view.
  final dynamic view;

  /// Marks annotated field as excluded from all state snapshots.
  final bool exclude;

  const State({this.view, this.exclude: false});

  /// Takes a "state snapshot" of [object].
  ///
  /// If [view] parameter is not null then resulting snapshot will include
  /// fields without associated `view` plus those which are associated with this
  /// view.
  ///
  /// If [format] parameter is provided it will be used to format certain values.
  ///
  /// If snapshot has been created with a custom format it will not be possible to
  /// use it for restoring, since original type information and data might be
  /// lost.
  static Map<String, dynamic> snapshot(object,
      {dynamic view, StateFormat format}) {
    var tm = reflect(object).type;
    var handler = _TypeHandler.getHandlerFor(tm.reflectedType);
    return handler.extract(tm.reflectedType, object,
        view: view, format: format);
  }

  /// Restores object of specified [type] from a state [snapshot].
  static Object restore(Type type, snapshot) =>
      _TypeHandler.getHandlerFor(type).hydrate(type, snapshot);
}

/// Annotation to be used on scalar value objects.
///
/// Scalar objects must conform to following rules:
///
/// * Have `value` getter which returns raw value of a primitive type
///   (`int`, `String`, `bool`, `double`).
/// * Have default constructor with single parameter for the raw value.
class ScalarObject {
  const ScalarObject();
}

part of corsac_state;

/// Configures formatting of state snapshots created with [State.snapshot].
///
/// Currently only allows to configure formatting for `DateTime` objects.
class StateFormat {
  /// Date format pattern to use on all `DateTime` objects.
  ///
  /// See `intl` package for details on date patterns.
  final String dateFormat;

  const StateFormat(this.dateFormat);
}

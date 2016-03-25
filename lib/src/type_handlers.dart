part of corsac_state;

abstract class _TypeHandler {
  Object extract(Type type, value, {view, StateFormat format});
  Object hydrate(Type type, value);

  static _TypeHandler getHandlerFor(Type type) {
    var mirror = reflectType(type);
    if (mirror == reflectType(int) ||
        mirror == reflectType(String) ||
        mirror == reflectType(double) ||
        mirror == reflectType(bool) ||
        mirror.isEnum) {
      return const _PrimitiveTypeHandler();
    } else if (_ScalarTypeHandler.isScalarObject(mirror)) {
      return const _ScalarTypeHandler();
    } else {
      return const _ObjectTypeHandler();
    }
  }
}

/// Handler for "primitive" types (int, String, bool, double).
///
/// This handler just passes through values.
class _PrimitiveTypeHandler implements _TypeHandler {
  const _PrimitiveTypeHandler();

  @override
  Object extract(Type type, value, {view, StateFormat format}) => value;

  @override
  Object hydrate(Type type, value) => value;
}

class _ScalarTypeHandler implements _TypeHandler {
  const _ScalarTypeHandler();

  @override
  Object extract(Type type, value, {view, StateFormat format}) {
    if (value == null) return null;

    if (value is DateTime) {
      if (format is StateFormat) {
        var dateFormat = new DateFormat(format.dateFormat);
        return dateFormat.format(value);
      }
      return value.toIso8601String();
    }
    if (value is Uri) return value.toString();

    return value.value;
  }

  @override
  Object hydrate(Type type, value) {
    if (value == null) return null;

    if (type == DateTime) return DateTime.parse(value);
    if (type == Uri) return Uri.parse(value);

    var mirror = reflectClass(type);
    return mirror.newInstance(new Symbol(''), [value]).reflectee;
  }

  static bool isScalarObject(ClassMirror type) {
    const standardScalarObjects = const [DateTime, Uri];

    return standardScalarObjects.contains(type.reflectedType) ||
        type.metadata.where((m) => m.reflectee is ScalarObject).isNotEmpty;
  }
}

class _ObjectTypeHandler implements _TypeHandler {
  const _ObjectTypeHandler();

  @override
  Map<String, dynamic> extract(Type type, value, {view, StateFormat format}) {
    if (value == null) return null;

    var state = {};
    InstanceMirror mirror = reflect(value);
    ClassMirror clazz = mirror.type;
    for (var d in clazz.declarations.values) {
      if (d is VariableMirror && !d.isStatic) {
        var meta = getMetadata(d);
        if (view != null && meta is State && meta.view != view) {
          continue;
        } else if (view == null && meta is State && meta.view != null) {
          continue;
        }
        var key = MirrorSystem.getName(d.simpleName);
        var fieldType = d.type.reflectedType;
        if (d.isPrivate) {
          key = key.replaceFirst('_', '');
          if (!clazz.declarations.containsKey(new Symbol(key))) continue;
        }

        var fieldValue = _TypeHandler.getHandlerFor(fieldType).extract(
            fieldType, mirror.getField(d.simpleName).reflectee,
            view: view, format: format);
        state[key] = fieldValue;
      }
    }
    return state;
  }

  State getMetadata(VariableMirror mirror) {
    return mirror.metadata
        .firstWhere((_) => _.reflectee is State, orElse: () => null)
        ?.reflectee;
  }

  @override
  Object hydrate(Type type, Map value) {
    if (value == null) return null;

    var mirror = reflectClass(type);
    if (!mirror.declarations.containsKey(mirror.simpleName)) {
      throw new StateError(
          'Class must declare default constructor in order to be hydrated.');
    }

    MethodMirror constructor = mirror.declarations[mirror.simpleName];
    List positional = new List();
    Map<Symbol, dynamic> named = new Map();
    for (var p in constructor.parameters) {
      var name = MirrorSystem.getName(p.simpleName);
      if (!value.containsKey(name)) {
        throw new StateError(
            'Constructor parameter not found in value. All constructor parameters must correspond to value fields (and vice versa).');
      }
      var paramType = p.type.reflectedType;
      var handler = _TypeHandler.getHandlerFor(paramType);
      var paramValue = handler.hydrate(paramType, value[name]);
      if (p.isNamed) {
        named[p.simpleName] = paramValue;
      } else {
        positional.add(paramValue);
      }
    }

    return mirror.newInstance(new Symbol(''), positional, named).reflectee;
  }
}

part of corsac_state;

abstract class TypeHandler {
  Object extract(Type type, value, {view, StateFormatter formatter});
  Object hydrate(Type type, Object value);

  static TypeHandler getHandlerFor(Type type) {
    var mirror = reflectType(type);
    if (mirror == reflectType(int) ||
        mirror == reflectType(String) ||
        mirror == reflectType(double) ||
        mirror == reflectType(bool) ||
        mirror.isEnum ||
        type == DateTime ||
        type == Uri) {
      return const PrimitiveTypeHandler();
    } else if (ScalarTypeHandler.isScalarObject(mirror)) {
      return const ScalarTypeHandler();
    } else {
      return const ObjectTypeHandler();
    }
  }
}

/// Handler for "primitive" types (int, String, bool, double).
///
/// This handler just passes through values.
class PrimitiveTypeHandler implements TypeHandler {
  const PrimitiveTypeHandler();

  @override
  Object extract(Type type, Object value, {view, StateFormatter formatter}) =>
      value;

  @override
  Object hydrate(Type type, Object value) => value;
}

class ScalarTypeHandler implements TypeHandler {
  const ScalarTypeHandler();

  @override
  Object extract(Type type, Object value, {view, StateFormatter formatter}) {
    if (value == null) return null;

    return (formatter is StateFormatter) ? formatter.format(value) : value;
  }

  @override
  Object hydrate(Type type, Object value) {
    if (value == null) return null;

    var mirror = reflectClass(type);
    return mirror.newInstance(new Symbol(''), [value]).reflectee;
  }

  static bool isScalarObject(ClassMirror type) {
    return type.metadata.where((m) => m.reflectee is ScalarObject).isNotEmpty;
  }
}

class ObjectTypeHandler implements TypeHandler {
  const ObjectTypeHandler();

  @override
  Map<String, dynamic> extract(Type type, value,
      {view, StateFormatter formatter}) {
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

        var fieldValue = TypeHandler.getHandlerFor(fieldType).extract(
            fieldType, mirror.getField(d.simpleName).reflectee,
            view: view, formatter: formatter);
        state[key] = fieldValue;
      }
    }
    return state;
  }

  State getMetadata(VariableMirror mirror) {
    return mirror.metadata
        .firstWhere((_) => _.type.reflectedType == State, orElse: () => null)
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
      var handler = TypeHandler.getHandlerFor(paramType);
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

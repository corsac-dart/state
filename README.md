# Corsac State

A foxy library for converting Dart objects into `Map`s and vice versa.

## 1. Usage

Maps produced by this library are not your regular Maps:

* They can be treated as snapshots of original object's state.
* Snapshots can be captured at any point in time.
* Original object can be "restored" from it's snapshot (with some limitations).
* Snapshots follow certain rules on how they are composed.

**Snapshot** is a `Map` object without any behavior, which represents
internal state of a "domain object" (or a "model"). Keys in a snapshot
refer to field names of corresponding domain object, and values are
"normalized" values of domain object's fields (can also be optionally
formatted).

### 1.1 Creating state snapshots

```dart
Map<String, dynamic> snapshot(object, {view, StateFormatter formatter});
```

There are certain rules for how Snapshots are composed.

First, they can only store primitive values (e.g. `int`, `String`), scalar objects
(`Uri`, `DateTime`) or other snapshots (meaning they can be nested). A value
can also be an `Iterable` or a `Map` of above types.

Second, snapshots does not include following fields of original object:

* Constants
* Static fields
* Private fields
* Virtual (computed) fields

Simplest way to create a snapshot:

```dart

import 'package:corsac_state/corsac_state.dart';

class User {
  final int id;
  String name;
  DateTime createdAt;
  User(this.id, this.name, this.createdAt);
}

void main() {
  var user = new User(1, 'Burt Macklin', new DateTime.now());
  var snapshot = State.snapshot(user);
  print(snapshot); // {id: 1, name: 'Burt Macklin', createdAt: <DateTime> }
}
```

One can optionally "normalize" the resulting snapshot for particular use case.
For instance, if the snapshot is to be converted to JSON string:

```dart
void main() {
  var user = new User(1, 'Burt Macklin', new DateTime.now());
  var snapshot = State.snapshot(user, formatter: StateFormatter.JSON);
  print(snapshot);
  // {id: 1, name: 'Burt Macklin', createdAt: "2016-01-01T03:22:43Z" }
}
```

Notice that `createdAt` value is converted to ISO8601 datetime string. As a
result this snapshot can be passed to `JSON.encode()` directly.

### 1.2 Restoring original object from a snapshot.

There are additional requirements to snapshots if they are to be used for
restoring original objects:

* By convention, original object's default constructor is reserved for restoring
  from a snapshot. This is due to limitations of Dart's mirror system which does
  not support instantiating an object without calling a constructor. However
  this is not necessarily a bad thing (we'll cover this in detail later).
* Generated snapshot must have all values required by original object's
  constructor, otherwise instantiation will fail.
* If snapshot was created with `StateFormatter` it can not be used to restore
  original object due to changes made by the formatter.

Basically, when restoring, default constructor of original object serves two
purposes. First, obviously, it allows to create a new instance. But most
importantly it defines requirements necessary to reconstruct the instance
in a valid state. And since it is you who knows and controls all the
requirements you are free to define those requirements in a way which makes
most sense to you.

We can restore user object from the example above with following:

```dart
User restoredUser = State.restore(User, snapshot);
```

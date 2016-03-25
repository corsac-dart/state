# Corsac State

A foxy library for converting Dart objects into `Map`s and vice versa.

## 1. Usage

Maps produced by this library are not your regular Maps:

* They are "state snapshots" of original object's state.
* Snapshots can be captured at any point in time.
* Original object can be "restored" from it's snapshot (with some limitations).
* Snapshots follow certain rules on how they are composed.

**State Snapshot** is a `Map` object, which represents
internal state of a "domain object" (or a "model"). Keys in a snapshot
refer to field names of corresponding domain object, and values are
"normalized" values of domain object's fields (can also be optionally
formatted).

### 1.1 Creating state snapshots

```dart
Map<String, dynamic> snapshot(object, {view, StateFormat format});
```

There are two main rules for how Snapshots are composed.

1. They can only store primitive values (e.g. `int`, `bool`, `String`) and
  other snapshots (meaning they can be nested). A value can also be an
  `Iterable` or a `Map` of above types.

  > For details on why such behavior please see below.

2. Secondly, snapshots does not include following fields of original domain object:
  * Constants
  * Static fields
  * Private fields
  * Virtual (computed) fields

Here is the simplest way to create a snapshot:

```dart

import 'package:corsac_state/corsac_state.dart';

/// Our example domain object.
class User {
  final int id;
  String name;
  DateTime createdAt;
  User(this.id, this.name, this.createdAt);
}

void main() {
  var user = new User(1, 'Burt Macklin', new DateTime.now());
  var snapshot = State.snapshot(user);
  print(snapshot);
  // {id: 1, name: 'Burt Macklin', createdAt: "2016-01-01T03:22:43Z" }
}
```

Note that `DateTime` object was converted to a ISO8601 `String`. This is a
consequence of the first rule. This this behavior can be overridden.

### 1.2 Restoring original object from a snapshot.

There are additional requirements to snapshots if they are to be used for
restoring original objects:

* By convention, original object's default constructor is reserved for restoring
  from a snapshot. This is due to limitations of Dart's mirror system which does
  not support instantiating an object without calling a constructor. However
  this is not necessarily a bad thing (we'll cover this in detail later).
* Generated snapshot must have all values required by original object's
  constructor, otherwise instantiation will fail.

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

## 2. Background

This library was specifically designed for extracting state of complex domain
objects (as well as restoring domain objects from a state snapshot).

Here, the term "domain object" mainly refers to objects built using techniques
from "Domain Driven Design" (DDD). This implies usage of such building blocks
like entities, value objects and aggregates.

> We assume here that you (reader) are familiar with these concepts so we won't
> go in detail about each of these. Please refer to resources on DDD if you're
> interested in this topic.

It is quite common that an entity's state includes some primitive values (`int`,
`bool`, `enum`) and many different value objects.

> We call `int`, `bool`, `String`, `enum` values "primitive" here in order to
> semantically distinguish them from other types of values. Such as value
> objects and particularly "scalar" value objects which we'll cover later.

### 2.1 Value objects

Simple example of a value object would be an `Address` object which itself
consists of several fields, like `zipCode`, `country` and `city`.

Our imaginary `User` entity may look something like this:

```dart
class User {
  final int id;
  String name;
  Address address;
  User(this.id, this.name, this.address);
}

/// Value object representing User's address.
class Address {
  final int zipCode;
  final String country;
  final String city;
  // the rest is excluded from here for simplicity.
}
```

So now, that we have our user, the next thing we usually want to do is to
transfer this user's state. Couple common scenarios are:

* store this user in some sort of database
* show in the UI
* (if we have an API server) return as JSON serialized string in API response

So we need to get access to this user's state.

One approach (for JSON serialize example) would be to add `toJson()` methods
to both `User` and `Address`. However there is a few downsides to this:

* it pollutes domain objects with unnecessary details
* it only serves specific use case.
* other use cases will most likely be very similar to this one and there is no
  way to share implementations.

With many different value objects it becomes quite a burden to maintain all
those representations.

Yet, there are certain patterns which can be generalized and that is why this
library exists.

State snapshots created by this library have a couple important qualities:

1. Since they only consist of maps, lists and primitive values they are usually
  directly serializable.
2. They represent single schema, which is defined by the domain object's public
  interface.

Once you have a snapshot you can easily to convert it into a JSON string or
a database record, and the other way around.

### 2.2 "Scalar" value objects

Many value objects, like the `Address` class from above are compound. They
consist of many primitive values.

However it is also quite often to have a value object which conceptually
represents a single value. Such a value is usually non-divisible or even if it
is then pieces would not make sense without each other. Typical examples of
such value objects are `Uri` and `DateTime` objects from standard library.

What difference does it make in our case? Assume our `User` entity now
has a `website` field or type `Uri`. If we try to make a snapshot of user's
state we will get something like:

```dart
class User {
  final int id;
  String name;
  Uri website;
  Address address;
  User(this.id, this.name, this.website, this.address);
}

void main() {
  var user = new User(
    1, "Burt", Uri.parse('http://burt.com'), new Address(/* address */));
  var snapshot = State.snapshot(user);
  print(snapshot);
  // We would get something like:
  // {id: 1, name: "Burt", website: {scheme: "http", host: "burt.com", ...}}
}
```

This is not what we would expect. That's why this library treats such objects
differently and actual result would be:

```dart
// {id: 1, name: "Burt", website: "http://burt.com", ...}}
```

This is by default enabled for some types provided by Dart SDK but one can also
enable this behavior for any custom type. There are 3 things that required:

1. Annotate your class with `ScalarObject`.
2. Reserve default constructor of your class for restoring from it's raw value.
3. Provide `value` getter which returns raw scalar value.

Here is an example of `Email` scalar value object:

```dart
@ScalarObject()
class Email {
  final String value;
  Email(this.value);
  // real implementation would probably add some validation in
  // the constructor, but we leave it out for simplicity.
}
```

That's it. If we add `email` field to our `User` entity and make a state
snapshot it will look like this:

```dart
{"id": 1, "email": "burt@gmail.com", ...}
```

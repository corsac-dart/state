library corsac_state.tests.state;

import 'package:test/test.dart';
import 'package:corsac_state/corsac_state.dart';

void main() {
  group('State:', () {
    test('it can take a snapshot of simple object', () {
      var date = new DateTime.now();
      var user = new User(3, 'Burt Macklin', date);
      var snapshot = State.snapshot(user);
      expect(snapshot, isMap);
      expect(snapshot['id'], 3);
      expect(snapshot['name'], 'Burt Macklin');
      expect(snapshot['createdAt'], date.toIso8601String());
    });

    test('it excludes private fields', () {
      var user = new User(3, 'Burt Macklin', new DateTime.now());
      var snapshot = State.snapshot(user);
      expect(snapshot, isNot(contains('_hidden')));
    });

    test('it excludes static fields', () {
      var user = new User(3, 'Burt Macklin', new DateTime.now());
      var snapshot = State.snapshot(user);
      expect(snapshot, isNot(contains('staticField')));
    });

    test('it excludes constants', () {
      var user = new User(3, 'Burt Macklin', new DateTime.now());
      var snapshot = State.snapshot(user);
      expect(snapshot, isNot(contains('constField')));
    });

    test('it excludes virtual (computed) fields', () {
      var user = new User(3, 'Burt Macklin', new DateTime.now());
      var snapshot = State.snapshot(user);
      expect(snapshot, isNot(contains('firstName')));
    });

    test('it includes fields in their view', () {
      var user = new User(3, 'Burt Macklin', new DateTime.now());
      var snapshotInternal = State.snapshot(user, view: 'internal');
      expect(snapshotInternal, contains('id'));
      expect(snapshotInternal, contains('name'));
      expect(snapshotInternal, contains('createdAt'));
      expect(snapshotInternal, contains('passwordHash'));

      var snapshot = State.snapshot(user);
      expect(snapshot, isNot(contains('passwordHash')));
    });

    test('it includes private fields with public getters', () {
      var user = new User(3, 'Burt Macklin', new DateTime.now());
      var snapshot = State.snapshot(user);
      expect(snapshot, contains('vip'));
    });

    test('it converts scalar objects when taking snapshot', () {
      var email = new Email('foo@bar.com');
      var user = new User(3, 'Burt Macklin', new DateTime.now())..email = email;
      var snapshot = State.snapshot(user);
      expect(snapshot, contains('email'));
      expect(snapshot['email'], 'foo@bar.com');
    });

    test('it converts Uri objects when taking snapshot', () {
      var user = new User(3, 'Burt Macklin', new DateTime.now());
      var snapshot = State.snapshot(user);
      expect(snapshot, contains('website'));
      expect(snapshot['website'], 'http://user.com');
    });

    test('it passes through null values', () {
      var user = new User(null, null, null);
      var snapshot = State.snapshot(user);
      expect(snapshot['id'], isNull);
      expect(snapshot['name'], isNull);
      expect(snapshot['createdAt'], isNull);
      expect(snapshot['email'], isNull);

      User restoredUser = State.restore(User, snapshot);
      expect(restoredUser.id, isNull);
      expect(restoredUser.name, isNull);
      expect(restoredUser.createdAt, isNull);
    });

    test('it allows custom format on DateTime objects', () {
      var user = new User(3, 'Burt Macklin', new DateTime(2012, 10, 9));
      var snapshot =
          State.snapshot(user, format: const StateFormat('yyyy-MM-dd'));
      expect(snapshot['createdAt'], '2012-10-09');
    });

    test('it restores object from a snapshot', () {
      var snapshot = {
        "id": 3,
        "name": "Burt Macklin",
        "createdAt": new DateTime.now().toIso8601String()
      };
      User user = State.restore(User, snapshot);
      expect(user.id, 3);
      expect(user.name, "Burt Macklin");
      expect(user.createdAt, new isInstanceOf<DateTime>());
    });
  });
}

class User {
  final int id;
  String name;
  DateTime createdAt;

  @State(view: 'internal')
  String passwordHash;

  bool _isHidden = true;
  static int staticField = 0;
  static const int constField = 3;

  String get firstName => name.split(' ').first; // virtual field

  bool _vip = true;
  bool get vip => _vip;

  Email email;
  Uri website = Uri.parse('http://user.com');

  User(this.id, this.name, this.createdAt);
}

@ScalarObject()
class Email {
  final String value;
  Email(this.value);

  toJson() => value;
}

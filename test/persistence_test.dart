import 'dart:async';

import "package:async_redux/async_redux.dart";
import "package:test/test.dart";

void main() {
  //
  Persistor persistor;
  LocalDb localDb;

  Future<void> setupPersistorAndLocalDb({Duration throttle}) async {
    persistor = Persistor(throttle: throttle);
    await persistor.init();
    await persistor.deleteAppState();
    localDb = persistor.localDb;
  }

  ///////////////////////////////////////////////////////////////////////////////

  Future<StoreTester<AppState>> createStoreTester() async {
    //
    var initialState = await persistor.readAppState();

    if (initialState == null) {
      initialState = AppState.initialState();
      await persistor.saveInitialState(initialState);
    }

    var store = Store<AppState>(
      initialState: initialState,
      persistObserver: persistor,
    );

    return StoreTester.from(store);
  }

  ///////////////////////////////////////////////////////////////////////////////

  test('Create some simple state and persist, without throttle.', () async {
    await setupPersistorAndLocalDb();

    var storeTester = await createStoreTester();
    expect(storeTester.state.name, "John");
    expect(await persistor.readAppState(), storeTester.state);

    storeTester.dispatch(ChangeNameAction("Mary"));
    TestInfo<AppState> info1 = await storeTester.waitAllGetLast([ChangeNameAction]);
    expect(localDb.get(db: "main", id: Id("name")), "Mary");
    expect(await persistor.readAppState(), info1.state);

    storeTester.dispatch(ChangeNameAction("Steve"));
    TestInfo<AppState> info2 = await storeTester.waitAllGetLast([ChangeNameAction]);
    expect(localDb.get(db: "main", id: Id("name")), "Steve");
    expect(await persistor.readAppState(), info2.state);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('Create some simple state and persist, with a 1 second throttle.', () async {
    await setupPersistorAndLocalDb(throttle: Duration(seconds: 1));

    var storeTester = await createStoreTester();
    expect(storeTester.state.name, "John");
    expect(await persistor.readAppState(), storeTester.state);

    // 1) The state is changed, but the persisted AppState is not.
    storeTester.dispatch(ChangeNameAction("Mary"));
    TestInfo<AppState> info1 = await storeTester.waitAllGetLast([ChangeNameAction]);
    expect(localDb.get(db: "main", id: Id("name")), "John");
    expect(info1.state.name, "Mary");
    expect(await persistor.readAppState(), isNot(info1.state));

    // 2) The state is changed, but the persisted AppState is not.
    storeTester.dispatch(ChangeNameAction("Steve"));
    TestInfo<AppState> info2 = await storeTester.waitAllGetLast([ChangeNameAction]);
    expect(localDb.get(db: "main", id: Id("name")), "John");
    expect(info2.state.name, "Steve");
    expect(await persistor.readAppState(), isNot(info2.state));

    // 3) The state is changed, but the persisted AppState is not.
    storeTester.dispatch(ChangeNameAction("Eve"));
    TestInfo<AppState> info3 = await storeTester.waitAllGetLast([ChangeNameAction]);
    expect(localDb.get(db: "main", id: Id("name")), "John");
    expect(info3.state.name, "Eve");
    expect(await persistor.readAppState(), isNot(info3.state));

    // 4) Now lets wait until the save is done.
    await Future.delayed(Duration(milliseconds: 1500));
    expect(localDb.get(db: "main", id: Id("name")), "Eve");
    expect(await persistor.readAppState(), storeTester.state);
  });

  ///////////////////////////////////////////////////////////////////////////////

//  test(
//      'The state is taking time to persist.
//      Meanwhile it tries to persist again.
//      It will not persist at this time, since the last persist hasn't finished,
//      but it will schedule a future persist.',
//      () async {
//  });

  ///////////////////////////////////////////////////////////////////////////////
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class AppState {
  String name;

  AppState({
    this.name,
  });

  AppState copy({
    String name,
  }) =>
      AppState(name: name ?? this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;

  static AppState initialState() {
    return AppState(name: "John");
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class Id {
  final String uid;

  Id(this.uid);

  @override
  String toString() => 'Id{uid: $uid}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Id && runtimeType == other.runtimeType && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}

////////////////////////////////////////////////////////////////////////////////////////////////////

/// T must have [isEmpty] method.
abstract class LocalDb<T> {
  //
  Map<String, T> dbs = {};

  Set<String> dbNames;

  bool get isEmpty => dbs.isEmpty || dbs.values.every((dynamic t) => t.isEmpty);

  bool get isNotEmpty => !isEmpty;

  T getDb(String name) {
    T db = dbs[name];
    if (db == null) throw PersistException("Database '$name' does not exist.");
    return db;
  }

  /// This method Must be called right after instantiating the object.
  /// If it's overridden, you must call super in the beginning.
  Future<void> init(Iterable<String> dbNames) async {
    assert(dbNames != null && dbNames.isNotEmpty);
    this.dbNames = dbNames.toSet();
  }

  Future<void> createDatabases();

  Future<void> deleteDatabases();

  Future<void> save({
    String db,
    Id id,
    Object info,
  });

  Object get({
    String db,
    Id id,
    Object orElse(),
    Object deserializer(Object obj),
  });

  Object getOrThrow({
    String db,
    Id id,
    Object deserializer(Object obj),
  });
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class SavedInfo {
  //
  final Id id;
  final Object info;

  static const notFound = SavedInfo._();

  const SavedInfo._()
      : id = null,
        info = null;

  SavedInfo(this.id, this.info) : assert(id != null);

  @override
  String toString() =>
      identical(this, notFound) ? "SavedInfo{Not Found}" : 'SavedInfo{id: $id, info: $info}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          info == other.info;

  @override
  int get hashCode => id.hashCode ^ info.hashCode;
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class LocalDbInMemory extends LocalDb<List<SavedInfo>> {
  //

  /// Must be called right after instantiating the object.
  /// The databases will be created as List<SavedInfo>.
  Future<void> init(Iterable<String> dbNames) async {
    super.init(dbNames);

    if (dbs.isNotEmpty) throw PersistException("Databases not empty.");

    dbNames.forEach((dbName) {
      dbs[dbName] = [];
    });
  }

  @override
  Future<void> createDatabases() => throw AssertionError();

  @override
  Future<void> deleteDatabases() async => dbs.values.forEach((db) => db.clear());

  @override
  Future<void> save({
    String db,
    Id id,
    Object info,
  }) async {
    assert(db != null);
    assert(id != null);
    assert(info != null);

    var savedInfo = SavedInfo(id, info);
    List<SavedInfo> dbObj = getDb(db);
    dbObj.add(savedInfo);
  }

  /// Searches the LAST change.
  /// If not found, returns SavedInfo.notFound.
  /// Will return null if the saved value is null.
  @override
  Object get({
    String db,
    Id id,
    Object orElse(),
    Object deserializer(Object obj),
  }) {
    assert(db != null);
    assert(id != null);

    List<SavedInfo> dbObj = getDb(db);

    for (int i = dbObj.length - 1; i >= 0; i--) {
      var savedInfo = dbObj[i];
      if (savedInfo.id == id)
        return (deserializer == null) ? savedInfo.info : deserializer(savedInfo.info);
    }
    if (orElse != null)
      return orElse();
    else
      return SavedInfo.notFound;
  }

  /// Searches the LAST change.
  /// If not found, returns SavedInfo.notFound.
  /// Will return null if the saved value is null.
  @override
  Object getOrThrow({
    String db,
    Id id,
    Object deserializer(Object obj),
  }) {
    assert(db != null);
    assert(id != null);

    var value = get(
      db: db,
      id: id,
      deserializer: deserializer,
    );

    if (value == SavedInfo.notFound)
      throw PersistException("Can't find: $id in db: $db.");
    else
      return value;
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class Persistor implements PersistObserver<AppState> {
  //
  Duration _throttle;

  Persistor({Duration throttle}) : _throttle = throttle;

  Duration get throttle => _throttle;

  LocalDb _localDb;

  LocalDb get localDb {
    _localDb = _localDb ?? LocalDbInMemory();
    return _localDb;
  }

  Future<void> init() async {
    localDb.init(["main", "students"]);
  }

  Future<void> saveInitialState(AppState state) async {
    if (localDb.isNotEmpty)
      throw PersistException("Store is already persisted.");
    else
      persistDifference(lastPersistedState: null, newState: state);
  }

  @override
  Future<void> persistDifference({
    AppState lastPersistedState,
    AppState newState,
  }) async {
    assert(newState != null);

    List<Future<void>> saves = [];

    if (lastPersistedState == null || lastPersistedState.name != newState.name) {
      await localDb.save(db: "main", id: Id("name"), info: newState.name);
    }
  }

  Future<AppState> readAppState() async {
    if (localDb.isEmpty)
      return null;
    else
      return AppState(name: localDb.getOrThrow(db: "main", id: Id("name")));
  }

  Future<void> deleteAppState() async {
    localDb.deleteDatabases();
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class ChangeNameAction extends ReduxAction<AppState> {
  String name;

  ChangeNameAction(this.name);

  @override
  FutureOr<AppState> reduce() => state.copy(
        name: name,
      );
}

////////////////////////////////////////////////////////////////////////////////////////////////////

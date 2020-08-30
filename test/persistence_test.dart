import 'dart:async';

import "package:async_redux/async_redux.dart";
import 'package:flutter/foundation.dart';
import "package:test/test.dart";

void main() {
  //
  MyPersistor persistor;
  LocalDb localDb;

  Future<void> setupPersistorAndLocalDb({
    Duration throttle,
    Duration saveDuration,
  }) async {
    persistor = MyPersistor(throttle: throttle, saveDuration: saveDuration);
    await persistor.init();
    await persistor.deleteState();
    localDb = persistor.localDb;
  }

  Future<StoreTester<AppState>> createStoreTester() async {
    //
    var initialState = await persistor.readState();

    if (initialState == null) {
      initialState = AppState.initialState();
      await persistor.saveInitialState(initialState);
    }

    var store = Store<AppState>(
      initialState: initialState,
      persistor: persistor,
    );

    return StoreTester.from(store);
  }

  void printResults(List<Object> results) => print("-\nRESULTS:\n${results.join("\n")}\n-");

  ///////////////////////////////////////////////////////////////////////////////

  test('Create some simple state and persist, without throttle.', () async {
    await setupPersistorAndLocalDb();

    var storeTester = await createStoreTester();
    expect(storeTester.state.name, "John");
    expect(await persistor.readState(), storeTester.state);

    storeTester.dispatch(ChangeNameAction("Mary"));
    TestInfo<AppState> info1 = await storeTester.waitAllGetLast([ChangeNameAction]);
    expect(localDb.get(db: "main", id: Id("name")), "Mary");
    expect(await persistor.readState(), info1.state);

    storeTester.dispatch(ChangeNameAction("Steve"));
    TestInfo<AppState> info2 = await storeTester.waitAllGetLast([ChangeNameAction]);
    expect(localDb.get(db: "main", id: Id("name")), "Steve");
    expect(await persistor.readState(), info2.state);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('Create some simple state and persist, with a 1 second throttle.', () async {
    await setupPersistorAndLocalDb(throttle: const Duration(seconds: 1));

    var storeTester = await createStoreTester();
    expect(storeTester.state.name, "John");
    expect(await persistor.readState(), storeTester.state);

    // 1) The state is changed, but the persisted AppState is not.
    storeTester.dispatch(ChangeNameAction("Mary"));
    TestInfo<AppState> info1 = await storeTester.waitAllGetLast([ChangeNameAction]);
    expect(localDb.get(db: "main", id: Id("name")), "John");
    expect(info1.state.name, "Mary");
    expect(await persistor.readState(), isNot(info1.state));

    // 2) The state is changed, but the persisted AppState is not.
    storeTester.dispatch(ChangeNameAction("Steve"));
    TestInfo<AppState> info2 = await storeTester.waitAllGetLast([ChangeNameAction]);
    expect(localDb.get(db: "main", id: Id("name")), "John");
    expect(info2.state.name, "Steve");
    expect(await persistor.readState(), isNot(info2.state));

    // 3) The state is changed, but the persisted AppState is not.
    storeTester.dispatch(ChangeNameAction("Eve"));
    TestInfo<AppState> info3 = await storeTester.waitAllGetLast([ChangeNameAction]);
    expect(localDb.get(db: "main", id: Id("name")), "John");
    expect(info3.state.name, "Eve");
    expect(await persistor.readState(), isNot(info3.state));

    // 4) Now lets wait until the save is done.
    await Future.delayed(const Duration(milliseconds: 1500));
    expect(localDb.get(db: "main", id: Id("name")), "Eve");
    expect(await persistor.readState(), storeTester.state);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      "There is no throttle. "
      "The state is changed each 40 milliseconds. "
      "Here we test that the initial state is persisted, "
      "and then that the state and the persistence change together.", () async {
    //
    List<String> results = [];

    await setupPersistorAndLocalDb(throttle: null);
    var storeTester = await createStoreTester();

    String result = writeStateAndDb(storeTester, localDb);
    results.add(result);

    int count = 0;
    Completer completer = Completer();

    Timer.periodic(const Duration(milliseconds: 40), (timer) {
      storeTester.dispatch(ChangeNameAction(count.toString()));
      String result = writeStateAndDb(storeTester, localDb);
      results.add(result);
      count++;
      if (count == 8) {
        timer.cancel();
        completer.complete();
      }
    });

    await completer.future;

    printResults(results);

    expect(
        results.join(),
        "(state:John, db: John)"
        "(state:0, db: 0)"
        "(state:1, db: 1)"
        "(state:2, db: 2)"
        "(state:3, db: 3)"
        "(state:4, db: 4)"
        "(state:5, db: 5)"
        "(state:6, db: 6)"
        "(state:7, db: 7)");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      "The throttle period is 215 milliseconds. "
      "The state is changed each 60 milliseconds. "
      "Here we test that the initial state is persisted, "
      "and then that the state and the persistence occur when they should.", () async {
    //
    List<String> results = [];

    await setupPersistorAndLocalDb(throttle: const Duration(milliseconds: 215));
    var storeTester = await createStoreTester();

    String result = writeStateAndDb(storeTester, localDb);
    results.add(result);

    int count = 0;
    Completer completer = Completer();

    Timer.periodic(const Duration(milliseconds: 60), (timer) {
      storeTester.dispatch(ChangeNameAction(count.toString()));
      String result = writeStateAndDb(storeTester, localDb);
      results.add(result);
      count++;
      if (count == 15) {
        timer.cancel();
        completer.complete();
      }
    });

    await completer.future;

    printResults(results);

    expect(
        results.join(),
        "(state:John, db: John)" // It starts with state and db in the initial state: John.
        "(state:0, db: John)" // Saved state in 60 millis.
        "(state:1, db: John)" // Saved state in 120 millis.
        "(state:2, db: John)" // Saved state in 180 millis.
        "(state:3, db: 2)" // Saved state in 240 millis. Saved db em 215 millis.
        "(state:4, db: 2)" // Saved state in 300 millis.
        "(state:5, db: 2)" // Saved state in 360 millis.
        "(state:6, db: 2)" // Saved state in 420 millis.
        "(state:7, db: 6)" // Saved state in 480 millis. Saved db em 430 millis.
        "(state:8, db: 6)" // Saved state in 540 millis.
        "(state:9, db: 6)" // Saved state in 600 millis.
        "(state:10, db: 9)" // Saved state in 660 millis. Saved db em 645 millis.
        "(state:11, db: 9)" // Saved state in 720 millis.
        "(state:12, db: 9)" // Saved state in 780 millis.
        "(state:13, db: 9)" // Saved state in 840 millis.
        "(state:14, db: 13)"); // Saved state in 900 millis. Saved db em 860 millis.
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      "There is no throttle. "
      "Each save takes 215 milliseconds. "
      "The state is changed each 60 milliseconds. "
      "Here we test that the initial state is persisted, "
      "and then that the state and the persistence occur when they should.", () async {
    //
    List<String> results = [];

    await setupPersistorAndLocalDb(
      throttle: null,
      saveDuration: const Duration(milliseconds: 215),
    );

    var storeTester = await createStoreTester();

    String result = writeStateAndDb(storeTester, localDb);
    results.add(result);

    int count = 0;
    Completer completer = Completer();

    Timer.periodic(const Duration(milliseconds: 60), (timer) {
      storeTester.dispatch(ChangeNameAction(count.toString()));

      String result = writeStateAndDb(storeTester, localDb);
      results.add(result);

      count++;
      if (count == 16) {
        timer.cancel();
        completer.complete();
      }
    });

    await completer.future;

    printResults(results);

    expect(
        results.join(),
        "(state:John, db: John)" // It starts with state and db in the initial state: John.
        "(state:0, db: John)" // Changed the state in 60 millis. Started saving state 0 (will finish: 60+215=275 millis).
        "(state:1, db: John)" // Changed the state in 120 millis.
        "(state:2, db: John)" // Changed state in 180 millis.
        "(state:3, db: John)" // Changed state in 240 millis. Started saving state 3 in 275 millis (will finish: 275+215=490 millis).
        "(state:4, db: 0)" // Changed state in 300 millis.
        "(state:5, db: 0)" // Changed state in 360 millis.
        "(state:6, db: 0)" // Changed state in 420 millis.
        "(state:7, db: 0)" // Changed state in 480 millis. Started saving state 7 in 490 millis (will finish: 490+215=705 millis).
        "(state:8, db: 3)" // Changed state in 540 millis.
        "(state:9, db: 3)" // Changed state in 600 millis.
        "(state:10, db: 3)" // Changed state in 660 millis. Started saving state 10 in 705 millis (will finish: 705+215=920 millis).
        "(state:11, db: 7)" // Changed state in 720 millis.
        "(state:12, db: 7)" // Changed state in 780 millis.
        "(state:13, db: 7)" // Changed state in 840 millis.
        "(state:14, db: 7)" // Changed state in 900 millis.
        "(state:15, db: 10)"); // Changed state in 960 millis. Started saving state 15 in 920 millis (will finish: 920+215 millis).
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      "There is a 300 millis throttle. "
      "A first state change happens. A save starts immediately."
      "A second state change happens 100 millis after the first. "
      "No other state changes happen. "
      "A second save will happen at 300 millis. "
      "This second save is necessary to save the second state change.", () async {
    //
    List<String> results = [];

    await setupPersistorAndLocalDb(
      throttle: const Duration(milliseconds: 300),
      saveDuration: null,
    );

    var storeTester = await createStoreTester();

    /// Discard the time waiting for the saving of the initial state.
    await Future.delayed(const Duration(milliseconds: 300));

    // At 0 millis: (state:John, db: John)
    results.add(writeStateAndDb(storeTester, localDb));

    // At 0 millis the state is changed and saved: (state:1st, db: 1st)
    storeTester.dispatch(ChangeNameAction("1st"));
    results.add(writeStateAndDb(storeTester, localDb));

    // At 100 millis the state is initially unchanged (state:1st, db: 1st)
    await Future.delayed(const Duration(milliseconds: 100));
    results.add(writeStateAndDb(storeTester, localDb));

    // At 100 millis the state is changed and saved: (state:2nd, db: 1st)
    storeTester.dispatch(ChangeNameAction("2nd"));
    results.add(writeStateAndDb(storeTester, localDb));

    // At 200 millis the state is unchanged: (state:2nd, db: 1st)
    await Future.delayed(const Duration(milliseconds: 100));
    results.add(writeStateAndDb(storeTester, localDb));

    // Right before 300 millis the state is unchanged: (state:2nd, db: 1st)
    await Future.delayed(const Duration(milliseconds: 80));
    results.add(writeStateAndDb(storeTester, localDb));

    // Right after 300 millis the state is saved: (state:2nd, db: 2nd)
    await Future.delayed(const Duration(milliseconds: 40));
    results.add(writeStateAndDb(storeTester, localDb));

    printResults(results);

    expect(
        results.join(),
        "(state:John, db: John)"
        "(state:1st, db: 1st)"
        "(state:1st, db: 1st)"
        "(state:2nd, db: 1st)"
        "(state:2nd, db: 1st)"
        "(state:2nd, db: 1st)"
        "(state:2nd, db: 2nd)");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      "There is a 300 save duration, and no throttle. "
      "A first state change happens. A save starts immediately."
      "A second state change happens 100 millis after the first. "
      "No other state changes happen. "
      "A second save will happen at 300 millis. "
      "This second save is necessary to save the second state change.", () async {
    //
    List<String> results = [];

    await setupPersistorAndLocalDb(
      throttle: null,
      saveDuration: const Duration(milliseconds: 300),
    );

    var storeTester = await createStoreTester();

    /// Discard the time waiting for the saving of the initial state.
    await Future.delayed(const Duration(milliseconds: 300));

    // At 0 millis: (state:John, db: John)
    results.add(writeStateAndDb(storeTester, localDb));

    // At 0 millis the state is and the save starts: (state:1st, db: John)
    storeTester.dispatch(ChangeNameAction("1st"));
    results.add(writeStateAndDb(storeTester, localDb));

    // At 100 millis the state is initially unchanged (state:1st, db: John)
    await Future.delayed(const Duration(milliseconds: 100));
    results.add(writeStateAndDb(storeTester, localDb));

    // At 100 millis the state is changed, but the previous save hasn't finished: (state:2nd, db: John)
    storeTester.dispatch(ChangeNameAction("2nd"));
    results.add(writeStateAndDb(storeTester, localDb));

    // At 200 millis the state is unchanged: (state:2nd, db: John)
    await Future.delayed(const Duration(milliseconds: 100));
    results.add(writeStateAndDb(storeTester, localDb));

    // Right before 300 millis the state is unchanged: (state:2nd, db: John)
    await Future.delayed(const Duration(milliseconds: 80));
    results.add(writeStateAndDb(storeTester, localDb));

    // Right after 300 millis the 1st state is saved: (state:2nd, db: 1st)
    await Future.delayed(const Duration(milliseconds: 40));
    results.add(writeStateAndDb(storeTester, localDb));

    // It will take 300 millis more (until 600) to save the 2nd state.
    // So, at 580 millis we're still at (state:2nd, db: 1st)
    await Future.delayed(const Duration(milliseconds: 260));
    results.add(writeStateAndDb(storeTester, localDb));

    // At 620 we're finally finished: (state:2nd, db: 2nd)
    await Future.delayed(const Duration(milliseconds: 40));
    results.add(writeStateAndDb(storeTester, localDb));

    printResults(results);

    expect(
        results.join(),
        "(state:John, db: John)"
        "(state:1st, db: John)"
        "(state:1st, db: John)"
        "(state:2nd, db: John)"
        "(state:2nd, db: John)"
        "(state:2nd, db: John)"
        "(state:2nd, db: 1st)"
        "(state:2nd, db: 1st)"
        "(state:2nd, db: 2nd)");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      "There is throttle period of 300 millis. "
      "A first state change happens. A save starts immediately."
      "A second state change happens 100 millis after the first. "
      "However at 150 a PersistAction is dispatched. "
      "And this saves the second state change right away.", () async {
    //
    List<String> results = [];

    await setupPersistorAndLocalDb(
      throttle: const Duration(milliseconds: 300),
      saveDuration: null,
    );

    var storeTester = await createStoreTester();

    /// Discard the throttle period for the saving of the initial state.
    await Future.delayed(const Duration(milliseconds: 300));

    // At 0 millis: (state:John, db: John)
    results.add(writeStateAndDb(storeTester, localDb));

    // At 0 millis the state is changed and saved: (state:1st, db: 1st)
    storeTester.dispatch(ChangeNameAction("1st"));
    results.add(writeStateAndDb(storeTester, localDb));

    // At 100 millis the state is initially unchanged (state:1st, db: 1st)
    await Future.delayed(const Duration(milliseconds: 100));
    results.add(writeStateAndDb(storeTester, localDb));

    // At 100 millis the state is changed and saved: (state:2nd, db: 1st)
    storeTester.dispatch(ChangeNameAction("2nd"));
    results.add(writeStateAndDb(storeTester, localDb));

    // At 150 millis the state is initially unchanged (state:2nd, db: 1st)
    await Future.delayed(const Duration(milliseconds: 50));
    results.add(writeStateAndDb(storeTester, localDb));

    // At 150 millis the PersistAction is dispatched. The state is changed: (state:2nd, db: 2nd)
    storeTester.dispatch(PersistAction());
    results.add(writeStateAndDb(storeTester, localDb));

    // At 400 millis the state is unchanged (state:2nd, db: 2nd)
    await Future.delayed(const Duration(milliseconds: 150));
    results.add(writeStateAndDb(storeTester, localDb));

    printResults(results);

    expect(
        results.join(),
        "(state:John, db: John)"
        "(state:1st, db: 1st)"
        "(state:1st, db: 1st)"
        "(state:2nd, db: 1st)"
        "(state:2nd, db: 1st)"
        "(state:2nd, db: 2nd)"
        "(state:2nd, db: 2nd)");
  });

  ///////////////////////////////////////////////////////////////////////////////
}

String writeStateAndDb(StoreTester<AppState> storeTester, LocalDb localDb) => "("
    "state:${storeTester.state.name}, "
    "db: ${localDb.get(db: 'main', id: Id('name'))}"
    ")";

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

class NotFound {
  const NotFound();

  static const instance = NotFound();
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class SavedInfo {
  //
  final Id id;
  final Object info;

  SavedInfo(this.id, this.info) : assert(id != null);

  @override
  String toString() => identical(this, NotFound.instance)
      ? "SavedInfo{Not Found}"
      : 'SavedInfo{id: $id, info: $info}';

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
  @override
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
    @required String db,
    @required Id id,
    @required Object info,
  }) async {
    assert(db != null);
    assert(id != null);
    assert(info != null);

    var savedInfo = SavedInfo(id, info);
    List<SavedInfo> dbObj = getDb(db);
    dbObj.add(savedInfo);
  }

  /// Searches the LAST change.
  /// If not found, returns NotFound.instance.
  /// Will return null if the saved value is null.
  @override
  Object get({
    @required String db,
    @required Id id,
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
      return NotFound.instance;
  }

  /// Searches the LAST change.
  /// If not found, returns NotFound.instance.
  /// Will return null if the saved value is null.
  @override
  Object getOrThrow({
    @required String db,
    @required Id id,
    Object deserializer(Object obj),
  }) {
    assert(db != null);
    assert(id != null);

    var value = get(
      db: db,
      id: id,
      deserializer: deserializer,
    );

    if (value == NotFound.instance)
      throw PersistException("Can't find: $id in db: $db.");
    else
      return value;
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class MyPersistor implements Persistor<AppState> {
  //
  final Duration _throttle;
  final Duration _saveDuration;

  MyPersistor({
    Duration throttle,
    Duration saveDuration,
  })  : _throttle = throttle,
        _saveDuration = saveDuration;

  @override
  Duration get throttle => _throttle;

  Duration get saveDuration => _saveDuration;

  LocalDb _localDb;

  LocalDb get localDb {
    _localDb = _localDb ?? LocalDbInMemory();
    return _localDb;
  }

  Future<void> init() async {
    localDb.init(["main", "students"]);
  }

  @override
  Future<void> saveInitialState(AppState state) async {
    if (localDb.isNotEmpty)
      throw PersistException("Store is already persisted.");
    else
      return persistDifference(lastPersistedState: null, newState: state);
  }

  @override
  Future<void> persistDifference({
    AppState lastPersistedState,
    @required AppState newState,
  }) async {
    assert(newState != null);

    if (saveDuration != null) await Future.delayed(saveDuration);

    if (lastPersistedState == null || lastPersistedState.name != newState.name) {
      await localDb.save(db: "main", id: Id("name"), info: newState.name);
    }
  }

  @override
  Future<AppState> readState() async {
    if (localDb.isEmpty)
      return null;
    else
      return AppState(name: localDb.getOrThrow(db: "main", id: Id("name")));
  }

  @override
  Future<void> deleteState() async {
    localDb.deleteDatabases();
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class ChangeNameAction extends ReduxAction<AppState> {
  String name;

  ChangeNameAction(this.name);

  @override
  AppState reduce() => state.copy(name: name);
}

////////////////////////////////////////////////////////////////////////////////////////////////////

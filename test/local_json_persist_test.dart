// Please run this test file by itself, not together with other tests.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:async_redux/async_redux.dart';
import 'package:async_redux/local_json_persist.dart';
import 'package:async_redux/src/local_persist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

enum files { abc, xyz }

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  /////////////////////////////////////////////////////////////////////////////

  test('Encode and decode state.', () async {
    //
    List<Object> simpleObj = [
      'Hello',
      'How are you?',
      [
        1,
        2,
        3,
        {'name': 'John'}
      ],
      42,
      true,
      false
    ];

    Uint8List encoded = LocalJsonPersist.encodeJson(simpleObj);
    Object? decoded = LocalJsonPersist.decodeJson(encoded);
    expect(decoded, simpleObj);

    expect(
        (decoded as List).map((obj) => "$obj (${obj.runtimeType})").join("\n"),
        'Hello (String)\n'
        'How are you? (String)\n'
        '[1, 2, 3, {name: John}] (List<dynamic>)\n'
        '42 (int)\n'
        'true (bool)\n'
        'false (bool)');
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Save and load state.', () async {
    //
    // Use a random number to make sure it's not checking already saved files.
    int randNumber = Random().nextInt(100000);

    List<Object> simpleObj = [
      'Goodbye',
      '"Life is what happens\n\rwhen you\'re busy making other plans." -John Lennon',
      [
        100,
        200,
        {"name": "João"}
      ],
      true,
      randNumber,
    ];

    var persist = LocalJsonPersist("abc");

    await persist.save(simpleObj);

    Object? decoded = await persist.load();

    expect(decoded, simpleObj);

    expect(
        (decoded as List).map((obj) => "$obj (${obj.runtimeType})").join("\n"),
        'Goodbye (String)\n'
        '"Life is what happens\n\rwhen you\'re busy making other plans." -John Lennon (String)\n'
        '[100, 200, {name: João}] (List<dynamic>)\n'
        'true (bool)\n'
        '$randNumber (int)');

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Test file can be defined by String or enum.', () async {
    //
    File file = await (LocalJsonPersist("abc").file());
    expect(file.path.endsWith("\\db\\abc.json") || file.path.endsWith("/db/abc.json"), isTrue);

    file = await (LocalJsonPersist(files.abc).file());
    expect(file.path.endsWith("\\db\\abc.json") || file.path.endsWith("/db/abc.json"), isTrue);

    file = await (LocalJsonPersist(files.xyz, dbSubDir: "kkk").file());
    expect(file.path.endsWith("\\kkk\\xyz.json") || file.path.endsWith("/kkk/xyz.json"), isTrue);
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Test dbDir and subDirs.', () async {
    //
    File file = await (LocalJsonPersist("xyz").file());
    expect(file.path.endsWith("\\xyz.json") || file.path.endsWith("/xyz.json"), isTrue);

    file = await (LocalJsonPersist("xyz", dbSubDir: "kkk").file());
    expect(file.path.endsWith("\\kkk\\xyz.json") || file.path.endsWith("/kkk/xyz.json"), isTrue);

    file = await (LocalJsonPersist("xyz", dbSubDir: "kkk", subDirs: ["mno"]).file());
    expect(file.path.endsWith("\\kkk\\mno\\xyz.json") || file.path.endsWith("/kkk/mno/xyz.json"),
        isTrue);

    file = await (LocalJsonPersist("xyz", dbSubDir: "kkk", subDirs: ["m", "n", "o"]).file());
    expect(
        file.path.endsWith("\\kkk\\m\\n\\o\\xyz.json") || file.path.endsWith("/kkk/m/n/o/xyz.json"),
        isTrue);

    file = await (LocalJsonPersist("xyz", subDirs: ["mno"]).file());
    expect(file.path.endsWith("\\db\\mno\\xyz.json") || file.path.endsWith("/db/mno/xyz.json"),
        isTrue);

    file = await (LocalJsonPersist("xyz", subDirs: ["m", "n", "o"]).file());
    expect(
        file.path.endsWith("\\db\\m\\n\\o\\xyz.json") || file.path.endsWith("/db/m/n/o/xyz.json"),
        isTrue);

    String saveDefaultDbSubDir = LocalJsonPersist.defaultDbSubDir;

    LocalJsonPersist.defaultDbSubDir = "myDir";

    file = await (LocalJsonPersist("xyz", subDirs: ["mno"]).file());
    expect(
        file.path.endsWith("\\myDir\\mno\\xyz.json") || file.path.endsWith("/myDir/mno/xyz.json"),
        isTrue);

    file = await (LocalJsonPersist("xyz", subDirs: ["m", "n", "o"]).file());
    expect(
        file.path.endsWith("\\myDir\\m\\n\\o\\xyz.json") ||
            file.path.endsWith("/myDir/m/n/o/xyz.json"),
        isTrue);

    LocalJsonPersist.defaultDbSubDir = "";

    file = await (LocalJsonPersist("xyz", subDirs: ["mno"]).file());
    expect(file.path.endsWith("\\mno\\xyz.json") || file.path.endsWith("/mno/xyz.json"), isTrue);
    expect(file.path.endsWith("\\db\\mno\\xyz.json") || file.path.endsWith("/db/mno/xyz.json"),
        isFalse);

    print('file.path = ${file.path}');
    file = await (LocalJsonPersist("xyz", subDirs: ["m", "n", "o"]).file());
    expect(
        file.path.endsWith("\\m\\n\\o\\xyz.json") || file.path.endsWith("/m/n/o/xyz.json"), isTrue);
    expect(
        file.path.endsWith("\\db\\m\\n\\o\\xyz.json") || file.path.endsWith("/db/m/n/o/xyz.json"),
        isFalse);

    LocalJsonPersist.defaultDbSubDir = "";

    file = await (LocalJsonPersist("xyz", subDirs: ["mno"]).file());
    expect(file.path.endsWith("\\mno\\xyz.json") || file.path.endsWith("/mno/xyz.json"), isTrue);
    expect(file.path.endsWith("\\db\\mno\\xyz.json") || file.path.endsWith("/db/mno/xyz.json"),
        isFalse);

    print('file.path = ${file.path}');
    file = await (LocalJsonPersist("xyz", subDirs: ["m", "n", "o"]).file());
    expect(
        file.path.endsWith("\\m\\n\\o\\xyz.json") || file.path.endsWith("/m/n/o/xyz.json"), isTrue);
    expect(
        file.path.endsWith("\\db\\m\\n\\o\\xyz.json") || file.path.endsWith("/db/m/n/o/xyz.json"),
        isFalse);

    LocalJsonPersist.defaultDbSubDir = saveDefaultDbSubDir;
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Add objects to save, and load from file name.', () async {
    //
    // User random numbers to make sure it's not checking already saved files.
    var rand = Random();
    int randNumber1 = rand.nextInt(1000);
    int randNumber2 = rand.nextInt(1000);
    int randNumber3 = rand.nextInt(1000);

    var persist = LocalJsonPersist("xyz");
    await persist.save([randNumber1, randNumber2, randNumber3]);

    Object? decoded = await persist.load();

    expect(decoded, [randNumber1, randNumber2, randNumber3]);

    expect(
        (decoded as List).map((obj) => "$obj (${obj.runtimeType})").join("\n"),
        '$randNumber1 (int)\n'
        '$randNumber2 (int)\n'
        '$randNumber3 (int)');

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Test create, overwrite and delete the file.', () async {
    //
    var persist = LocalJsonPersist("klm");

    // Create.
    await persist.save([123]);
    var decoded = await persist.load();
    expect(decoded, [123]);

    // Overwrite.
    await persist.save([789]);
    decoded = await persist.load();
    expect(decoded, [789]);

    // Delete.
    File file = await (persist.file());
    expect(file.existsSync(), true);
    await persist.delete();
    expect(file.existsSync(), false);
  });

  /////////////////////////////////////////////////////////////////////////////

  test("Load/Length/Exists file that doesn't exist, or exists and is empty.", () async {
    //
    // File doesn't exist.
    var persist = LocalJsonPersist("doesNotExist");
    expect(await persist.load(), isNull);
    expect(await persist.length(), 0);
    expect(await persist.exists(), false);

    // File exists and is empty.
    persist = LocalJsonPersist("my_file");
    await persist.save([]);
    expect(await persist.load(), []);
    expect(await persist.length(), 2);
    expect(await persist.exists(), true);

    // File exists and contains Json null, which is 4 chars: n, u, l and l.
    persist = LocalJsonPersist("my_file");
    await persist.save(null);
    expect(await persist.load(), null);
    expect(await persist.length(), 4);
    expect(await persist.exists(), true);
  });

  /////////////////////////////////////////////////////////////////////////////

  test("Deletes a file that exists or doesn't exist.", () async {
    //
    // File doesn't exist.
    var persist = LocalJsonPersist("doesNotExist");
    expect(await persist.delete(), isFalse);

    // File exists and is deleted.
    persist = LocalJsonPersist("my_file");
    await persist.save([]);
    expect(await persist.delete(), isTrue);
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Load as object.', () async {
    //
    // Use a random number to make sure it's not checking already saved files.
    int randNumber = Random().nextInt(100000);

    Map<String, dynamic> simpleObj = {
      "one": 1,
      "two": randNumber,
    };

    var persist = LocalJsonPersist("obj");
    await persist.save(simpleObj);

    Map<String, dynamic>? decoded = await persist.loadAsObj();

    expect(decoded, simpleObj);

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Loading an object-which-is-not-a-map as single object, fails.', () async {
    //
    List<Object> simpleObj = [
      {
        "one": 1,
        "two": 2,
      },
      {
        "three": 1,
        "four": 2,
      }
    ];

    var persist = LocalJsonPersist("obj");
    await persist.save(simpleObj);

    dynamic error;
    try {
      await persist.loadAsObj();
    } catch (_error) {
      error = _error;
    }
    expect(error, PersistException("Not an object: [{one: 1, two: 2}, {three: 1, four: 2}]"));

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Load as object (map) something which is not an object.', () async {
    //
    List<Object> simpleObj = ["hey"];

    var persist = LocalJsonPersist("obj");
    await persist.save(simpleObj);

    dynamic error;
    try {
      await persist.loadAsObj();
    } catch (_error) {
      error = _error;
    }
    expect(error, PersistException("Not an object: [hey]"));

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Encode and decode as JSON.', () async {
    //
    List<Object> simpleObj = [
      'Hello',
      'How are you?',
      [
        1,
        2,
        3,
        {'name': 'John'}
      ],
      42,
      true,
      false
    ];

    Uint8List encoded = LocalJsonPersist.encodeJson(simpleObj);
    Object? decoded = LocalJsonPersist.decodeJson(encoded);
    expect(decoded, simpleObj);

    expect(
        (decoded as List).map((obj) => "$obj (${obj.runtimeType})").join("\n"),
        'Hello (String)\n'
        'How are you? (String)\n'
        '[1, 2, 3, {name: John}] (List<dynamic>)\n'
        '42 (int)\n'
        'true (bool)\n'
        'false (bool)');
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Save and load a single string into/from JSON.', () async {
    //
    Object simpleObj = 'Goodbye';
    var persist = LocalJsonPersist("abc");
    await persist.save(simpleObj);
    Object? decoded = await persist.load();
    expect(decoded, simpleObj);
    expect(decoded, 'Goodbye');

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('loadConverting from .json file', () async {
    var simpleObj = {'Hello': 123};
    var persist = LocalJsonPersist("abc");
    await persist.save(simpleObj);
    Object? decoded = await persist.loadConverting(isList: false);
    expect(decoded, simpleObj);

    expect(await persist.exists(), isTrue);
    expect((await persist.file()).toString(), endsWith('\\db\\abc.json\''));

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('loadConverting from .db (json-sequence) file', () async {
    //
    var simpleObj = {'Hello': 123};

    // Save inside a List.
    var listWithOneElement = [simpleObj];
    var persistSequence = LocalPersist("abc");
    await persistSequence.save(listWithOneElement);

    // The '.db' file exists.
    expect(await persistSequence.exists(), isTrue);
    expect((await persistSequence.file()).toString(), endsWith('\\db\\abc.db\''));

    // ---

    // The '.json' file does NOT exist.
    var persist = LocalJsonPersist("abc");
    expect(await persist.exists(), isFalse);

    // When we load converting...
    Object? decoded = await persist.loadConverting(isList: false);
    expect(decoded, simpleObj);

    // The '.json' file now exists.
    expect(await persist.exists(), isTrue);
    expect((await persist.file()).toString(), endsWith('\\db\\abc.json\''));

    // But the '.db' file was deleted.
    expect(await persistSequence.exists(), isFalse);

    // ---

    // We now can read the '.json' file again.
    persist = LocalJsonPersist("abc");
    expect(await persist.exists(), isTrue);

    // And it works just the same.
    decoded = await persist.loadConverting(isList: false);
    expect(decoded, simpleObj);

    // ---

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('loadConverting from .db (json-sequence) file fails for more than 1 object', () async {
    var simpleObj = ['Hello', 123];
    var persistSequence = LocalPersist("abc");
    await persistSequence.save(simpleObj);

    dynamic _error;
    var persist = LocalJsonPersist("abc");
    try {
      await persist.loadConverting(isList: false);
    } catch (error) {
      _error = error;
      expect(error is PersistException, isTrue);
      expect(error.toString(), 'Json sequence to Json: 2 objects: [Hello, 123].');
    }

    expect(_error, isNot(null));

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('loadAsObjConverting from .db (json-sequence) file', () async {
    //
    var simpleObj = {'Hello': 123};

    // Save inside a List.
    var listWithOneElement = [simpleObj];
    var persistSequence = LocalPersist("abc");
    await persistSequence.save(listWithOneElement);

    // The '.db' file exists.
    expect(await persistSequence.exists(), isTrue);
    expect((await persistSequence.file()).toString(), endsWith('\\db\\abc.db\''));

    // ---

    // The '.json' file does NOT exist.
    var persist = LocalJsonPersist("abc");
    expect(await persist.exists(), isFalse);

    // When we load converting...
    Map<String, dynamic>? decoded = await persist.loadAsObjConverting();
    expect(decoded, simpleObj);

    // The '.json' file now exists.
    expect(await persist.exists(), isTrue);
    expect((await persist.file()).toString(), endsWith('\\db\\abc.json\''));

    // But the '.db' file was deleted.
    expect(await persistSequence.exists(), isFalse);

    // ---

    // We now can read the '.json' file again.
    persist = LocalJsonPersist("abc");
    expect(await persist.exists(), isTrue);

    // And it works just the same.
    decoded = await persist.loadAsObjConverting();
    expect(decoded, simpleObj);

    // ---

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('loadConverting from .json file', () async {
    var simpleObj = {'Hello': 123};
    var persist = LocalJsonPersist("abc");
    await persist.save(simpleObj);
    Object? decoded = await persist.loadConverting(isList: false);
    expect(decoded, simpleObj);

    expect(await persist.exists(), isTrue);
    expect((await persist.file()).toString(), endsWith('\\db\\abc.json\''));

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('loadConverting from .db (json-sequence) file', () async {
    //
    var simpleObj = {'Hello': 123};

    // Save inside a List.
    var listWithOneElement = [simpleObj];
    var persistSequence = LocalPersist("abc");
    await persistSequence.save(listWithOneElement);

    // The '.db' file exists.
    expect(await persistSequence.exists(), isTrue);
    expect((await persistSequence.file()).toString(), endsWith('\\db\\abc.db\''));

    // ---

    // The '.json' file does NOT exist.
    var persist = LocalJsonPersist("abc");
    expect(await persist.exists(), isFalse);

    // When we load converting...
    Object? decoded = await persist.loadConverting(isList: true);
    expect(decoded, [simpleObj]);

    // The '.json' file now exists.
    expect(await persist.exists(), isTrue);
    expect((await persist.file()).toString(), endsWith('\\db\\abc.json\''));

    // But the '.db' file was deleted.
    expect(await persistSequence.exists(), isFalse);

    // ---

    // We now can read the '.json' file again.
    persist = LocalJsonPersist("abc");
    expect(await persist.exists(), isTrue);

    // And it works just the same.
    decoded = await persist.loadConverting(isList: true);
    expect(decoded, [simpleObj]);

    // ---

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('loadConverting from .db (json-sequence) file for a single object', () async {
    //
    var simpleObj = ['Hello'];
    var persistSequence = LocalPersist("abc");
    await persistSequence.save(simpleObj);

    var persist = LocalJsonPersist("abc");
    var decoded = await persist.loadConverting(isList: true);

    expect(decoded, simpleObj);

    // ---

    var persistJson = LocalJsonPersist(simpleObj);
    await persistJson.save(simpleObj);

    decoded = await persistJson.load();
    expect(decoded, simpleObj);

    decoded = await persistJson.loadConverting(isList: true);
    expect(decoded, simpleObj);

    // ---

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('loadConverting from .db (json-sequence) file for more than 1 object', () async {
    //
    var simpleObj = ['Hello', 123];
    var persistSequence = LocalPersist("abc");
    await persistSequence.save(simpleObj);

    var persist = LocalJsonPersist("abc");
    var decoded = await persist.loadConverting(isList: true);

    expect(decoded, simpleObj);

    // ---

    var persistJson = LocalJsonPersist(simpleObj);
    await persistJson.save(simpleObj);

    decoded = await persistJson.load();
    expect(decoded, simpleObj);

    decoded = await persistJson.loadConverting(isList: true);
    expect(decoded, simpleObj);

    // ---

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('loadConverting from .db (json-sequence) file for a list inside a list', () async {
    //
    var simpleObj = [
      ['Hello', 123]
    ];

    var persistSequence = LocalPersist("abc");
    await persistSequence.save(simpleObj);

    var persist = LocalJsonPersist("abc");
    var decoded = await persist.loadConverting(isList: true);

    expect(decoded, simpleObj);

    // ---

    var persistJson = LocalJsonPersist(simpleObj);
    await persistJson.save(simpleObj);

    decoded = await persistJson.load();
    expect(decoded, simpleObj);

    decoded = await persistJson.loadConverting(isList: true);
    expect(decoded, simpleObj);

    // ---

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////
}

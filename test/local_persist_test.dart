import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:async_redux/async_redux.dart';
import "package:test/test.dart";

enum files { abc, xyz }

void main() {
  /////////////////////////////////////////////////////////////////////////////

  test('Encode and decode state.', () async {
    //
    List<Object> simpleObjs = [
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

    Uint8List encoded = LocalPersist.encode(simpleObjs);
    List<Object> decoded = LocalPersist.decode(encoded);
    expect(decoded, simpleObjs);

    expect(
        decoded.map((obj) => "$obj (${obj.runtimeType})").join("\n"),
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
    // User a random number to make sure it's not checking already saved files.
    int randNumber = Random().nextInt(100000);

    List<Object> simpleObjs = [
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

    var persist = LocalPersist("abc");

    await persist.save(simpleObjs);

    List<Object> decoded = await persist.load();

    expect(decoded, simpleObjs);

    expect(
        decoded.map((obj) => "$obj (${obj.runtimeType})").join("\n"),
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
    File file = await LocalPersist("abc").file();
    expect(file.path.endsWith("\\db\\abc.db") || file.path.endsWith("/db/abc.db"), isTrue);

    file = await LocalPersist(files.abc).file();
    expect(file.path.endsWith("\\db\\abc.db") || file.path.endsWith("/db/abc.db"), isTrue);

    file = await LocalPersist(files.xyz, dbSubDir: "kkk").file();
    expect(file.path.endsWith("\\kkk\\xyz.db") || file.path.endsWith("/kkk/xyz.db"), isTrue);
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Add objects to save, and load from file name.', () async {
    //
    // User random numbers to make sure it's not checking already saved files.
    var rand = Random();
    int randNumber1 = rand.nextInt(1000);
    int randNumber2 = rand.nextInt(1000);
    int randNumber3 = rand.nextInt(1000);

    var persist = LocalPersist("xyz");
    await persist.save([randNumber1, randNumber2, randNumber3]);

    List<Object> decoded = await persist.load();

    expect(decoded, [randNumber1, randNumber2, randNumber3]);

    expect(
        decoded.map((obj) => "$obj (${obj.runtimeType})").join("\n"),
        '$randNumber1 (int)\n'
        '$randNumber2 (int)\n'
        '$randNumber3 (int)');

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Test appending, then loading.', () async {
    //
    // User random numbers to make sure it's not checking already saved files.
    var rand = Random();
    int randNumber1 = rand.nextInt(1000);
    int randNumber2 = rand.nextInt(1000);

    var persist = LocalPersist("lmn");

    await persist.save(["Hello", randNumber1], append: false);
    await persist.save(["There", randNumber2], append: true);

    var simpleObjs = [
      35,
      false,
      {
        "x": 1,
        "y": [1, 2]
      }
    ];
    await persist.save(simpleObjs, append: true);

    List<Object> decoded = await persist.load();

    expect(decoded, [
      "Hello",
      randNumber1,
      "There",
      randNumber2,
      35,
      false,
      {
        "x": 1,
        "y": [1, 2]
      }
    ]);

    expect(
        LocalPersist.simpleObjsToString(decoded),
        'Hello (String)\n'
        '$randNumber1 (int)\n'
        'There (String)\n'
        '$randNumber2 (int)\n'
        '35 (int)\n'
        'false (bool)\n'
        '{x: 1, y: [1, 2]} (_InternalLinkedHashMap<String, dynamic>)');

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Test create, append, overwrite and delete the file.', () async {
    //
    var persist = LocalPersist("klm");

    // Create.
    await persist.save([123], append: false);
    var decoded = await persist.load();
    expect(decoded, [123]);

    // Append.
    await persist.save([456], append: true);
    decoded = await persist.load();
    expect(decoded, [123, 456]);

    // Overwrite.
    await persist.save([789], append: false);
    decoded = await persist.load();
    expect(decoded, [789]);

    // Delete.
    File file = await persist.file();
    expect(file.existsSync(), true);
    await persist.delete();
    expect(file.existsSync(), false);
  });

  /////////////////////////////////////////////////////////////////////////////

  test("Load/Length/Exists file that doesn't exist, or exists and is empty.", () async {
    //
    // File doesn't exist.
    var persist = LocalPersist("doesnotexist");
    expect(await persist.load(), isNull);
    expect(await persist.length(), 0);
    expect(await persist.exists(), false);

    // File exists and is empty.
    persist = LocalPersist("my_file");
    await persist.save([]);
    expect(await persist.load(), []);
    expect(await persist.length(), 0);
    expect(await persist.exists(), true);
  });

  /////////////////////////////////////////////////////////////////////////////

  test("Deletes a file that exists or doesn't exist.", () async {
    //
    // File doesn't exist.
    var persist = LocalPersist("doesnotexist");
    expect(await persist.delete(), isFalse);

    // File exists and is deleted.
    persist = LocalPersist("my_file");
    await persist.save([]);
    expect(await persist.delete(), isTrue);
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Load as object.', () async {
    //
    // User a random number to make sure it's not checking already saved files.
    int randNumber = Random().nextInt(100000);

    List<Object> simpleObjs = [
      {
        "one": 1,
        "two": randNumber,
      }
    ];

    var persist = LocalPersist("obj");
    await persist.save(simpleObjs);

    Map<String, dynamic> decoded = await persist.loadAsObj();

    expect(decoded, simpleObjs[0]);

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Load many object as single object.', () async {
    //
    List<Object> simpleObjs = [
      {
        "one": 1,
        "two": 2,
      },
      {
        "three": 1,
        "four": 2,
      }
    ];

    var persist = LocalPersist("obj");
    await persist.save(simpleObjs);

    var error;
    try {
      await persist.loadAsObj();
    } catch (_error) {
      error = _error;
    }
    expect(error, PersistException("Not a single object."));

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Load as object (map) something which is not an object.', () async {
    //
    List<Object> simpleObjs = ["hey"];

    var persist = LocalPersist("obj");
    await persist.save(simpleObjs);

    var error;
    try {
      await persist.loadAsObj();
    } catch (_error) {
      error = _error;
    }
    expect(error, PersistException("Not an object."));

    // Cleans up test.
    await persist.delete();
  });

  /////////////////////////////////////////////////////////////////////////////
}

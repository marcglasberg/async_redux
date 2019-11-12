import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:async_redux/async_redux.dart';
import "package:test/test.dart";

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

    Uint8List encoded = Saver.encode(simpleObjs);
    List<Object> decoded = Loader.decode(encoded);
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

    var saver = Saver(simpleObjs);
    File file = await saver.save("abc.db");

    var loader = Loader();
    List<Object> decoded = await loader.loadFile(file);

    expect(decoded, simpleObjs);

    expect(
        decoded.map((obj) => "$obj (${obj.runtimeType})").join("\n"),
        'Goodbye (String)\n'
        '"Life is what happens\n\rwhen you\'re busy making other plans." -John Lennon (String)\n'
        '[100, 200, {name: João}] (List<dynamic>)\n'
        'true (bool)\n'
        '$randNumber (int)');

    // Cleans up test.
    await Deleter().delete("abc.db");
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Add objects to save, and load from file name.', () async {
    //
    // User random numbers to make sure it's not checking already saved files.
    var rand = Random();
    int randNumber1 = rand.nextInt(1000);
    int randNumber2 = rand.nextInt(1000);
    int randNumber3 = rand.nextInt(1000);

    var saver = Saver()
      ..add(randNumber1)
      ..addAll([randNumber2, randNumber3]);
    await saver.save("xyz.db");

    var loader = Loader();
    List<Object> decoded = await loader.load("xyz.db");

    expect(decoded, [randNumber1, randNumber2, randNumber3]);

    expect(
        decoded.map((obj) => "$obj (${obj.runtimeType})").join("\n"),
        '$randNumber1 (int)\n'
        '$randNumber2 (int)\n'
        '$randNumber3 (int)');

    // Cleans up test.
    await Deleter().delete("xyz.db");
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Test appending, then loading.', () async {
    //
    // User random numbers to make sure it's not checking already saved files.
    var rand = Random();
    int randNumber1 = rand.nextInt(1000);
    int randNumber2 = rand.nextInt(1000);

    var saver = Saver(["Hello", randNumber1]);
    await saver.save("lmn.db", append: false);

    saver = Saver(["There", randNumber2]);
    await saver.save("lmn.db", append: true);

    saver = Saver([
      35,
      false,
      {
        "x": 1,
        "y": [1, 2]
      }
    ]);
    await saver.save("lmn.db", append: true);

    var loader = Loader();
    List<Object> decoded = await loader.load("lmn.db");

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
        decoded.map((obj) => "$obj (${obj.runtimeType})").join("\n"),
        'Hello (String)\n'
        '$randNumber1 (int)\n'
        'There (String)\n'
        '$randNumber2 (int)\n'
        '35 (int)\n'
        'false (bool)\n'
        '{x: 1, y: [1, 2]} (_InternalLinkedHashMap<String, dynamic>)');

    // Cleans up test.
    await Deleter().delete("lmn.db");
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Test create, append, overwrite and delete the file.', () async {
    //
    // Create.
    var saver = Saver([123]);
    File file = await saver.save("klm.db", append: false);
    var loader = Loader();
    var decoded = await loader.load("klm.db");
    expect(decoded, [123]);

    // Append.
    saver = Saver([456]);
    await saver.saveFile(file, append: true);
    loader = Loader();
    decoded = await loader.load("klm.db");
    expect(decoded, [123, 456]);

    // Overwrite.
    saver = Saver([789]);
    await saver.saveFile(file, append: false);
    loader = Loader();
    decoded = await loader.load("klm.db");
    expect(decoded, [789]);

    // Delete.
    var deleter = Deleter();
    expect(file.existsSync(), true);
    await deleter.delete("klm.db");
    expect(file.existsSync(), false);
  });

  /////////////////////////////////////////////////////////////////////////////
}

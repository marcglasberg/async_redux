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
    File file = await saver.save("abc");

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
    await Deleter().delete("abc");
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
    await saver.save("xyz");

    var loader = Loader();
    List<Object> decoded = await loader.load("xyz");

    expect(decoded, [randNumber1, randNumber2, randNumber3]);

    expect(
        decoded.map((obj) => "$obj (${obj.runtimeType})").join("\n"),
        '$randNumber1 (int)\n'
        '$randNumber2 (int)\n'
        '$randNumber3 (int)');

    // Cleans up test.
    await Deleter().delete("xyz");
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Test appending, then loading.', () async {
    //
    // User random numbers to make sure it's not checking already saved files.
    var rand = Random();
    int randNumber1 = rand.nextInt(1000);
    int randNumber2 = rand.nextInt(1000);

    var saver = Saver(["Hello", randNumber1]);
    await saver.save("lmn", append: false);

    saver = Saver(["There", randNumber2]);
    await saver.save("lmn", append: true);

    saver = Saver([
      35,
      false,
      {
        "x": 1,
        "y": [1, 2]
      }
    ]);
    await saver.save("lmn", append: true);

    var loader = Loader();
    List<Object> decoded = await loader.load("lmn");

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
    await Deleter().delete("lmn");
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Test create, append, overwrite and delete the file.', () async {
    //
    // Create.
    var saver = Saver([123]);
    File file = await saver.save("klm", append: false);
    var loader = Loader();
    var decoded = await loader.load("klm");
    expect(decoded, [123]);

    // Append.
    saver = Saver([456]);
    await saver.saveFile(file, append: true);
    loader = Loader();
    decoded = await loader.load("klm");
    expect(decoded, [123, 456]);

    // Overwrite.
    saver = Saver([789]);
    await saver.saveFile(file, append: false);
    loader = Loader();
    decoded = await loader.load("klm");
    expect(decoded, [789]);

    // Delete.
    var deleter = Deleter();
    expect(file.existsSync(), true);
    await deleter.delete("klm");
    expect(file.existsSync(), false);
  });

  /////////////////////////////////////////////////////////////////////////////

  test("Load/Length/Exists file that doesn't exist, or exists and is empty.", () async {
    //
    // File doesn't exist.
    expect(await Loader().load("doesnotexist"), isNull);
    expect(await Loader().length("doesnotexist"), 0);
    expect(Loader().exists("doesnotexist"), false);

    // File exists and is empty.
    var saver = Saver([]);
    File file = await saver.save("my_file");
    expect(await Loader().loadFile(file), []);
    expect(await Loader().lengthFile(file), 0);
    expect(Loader().existsFile(file), true);
  });

  /////////////////////////////////////////////////////////////////////////////

  test("Deletes a file that exists or doesn't exist.", () async {
    //
    // File doesn't exist.
    expect(await Deleter().delete("doesnotexist"), isFalse);

    // File exists and is deleted.
    var saver = Saver([]);
    File file = await saver.save("my_file");
    expect(await Deleter().deleteFile(file), isTrue);
  });

  /////////////////////////////////////////////////////////////////////////////
}

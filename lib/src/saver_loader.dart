import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Developed by Marcelo Glasberg (Nov 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

// /////////////////////////////////////////////////////////////////////////////////////////////////

/// This will save multiple simple objects in UTF-8 Json format.
///
/// 1) Example of saving:
///
/// List<Object> simpleObjs = ['"Hello"', '"How are you?"', [1, 2, 3], 42];
/// var saver = Saver(simpleObjs);
/// File file = await saver.save("xyz");
///
///
/// 2) Example of encoding, and not saving:
///
/// saver = Saver()..add('"Hello"')..addAll(['"How are you?"', [1, 2, 3], 42]);
/// Uint8List encoded = Saver.encode(saver.simpleObjs);
///
class Saver {
  //
  /// The default is saving/loading to/from "appDocsDir/db/".
  /// This is not final, so you can change it.
  static String defaultDbSubDir = "db";

  /// The default is adding a ".db" termination to the file name.
  /// This is not final, so you can change it.
  static String defaultTermination = ".db";

  static Directory get appDocDir => _appDocDir;
  static Directory _appDocDir;

  // Each json may have at most 65.536 ‬bytes.
  // Note this refers to a single json object, not to the total json file,
  // which may contain many objects.
  static const maxJsonSize = 256 * 256;

  List<Object> simpleObjs;

  Saver([List<Object> simpleObjs]) : simpleObjs = simpleObjs ?? [];

  /// Saves to "appDocsDir/db/$dbName" (except in tests it saves to the system temp dir).
  /// If [append] is false (the default), the file will be overwritten.
  /// If [append] is true, it will write to the end of the file.
  Future<File> save(String dbName, {String dbSubDir, bool append: false}) async {
    if (_appDocDir == null) await _findAppDocDir();

    String pathNameStr = pathName(dbName, dbSubDir: dbSubDir);

    File file = File(pathNameStr);

    file.createSync(recursive: true);

    return saveFile(file, append: append);
  }

  /// Loads from the given file.
  Future<File> saveFile(File file, {bool append: false}) async {
    Uint8List encoded = Saver.encode(simpleObjs);

    return file.writeAsBytes(
      encoded,
      flush: true,
      mode: append ? FileMode.writeOnlyAppend : FileMode.writeOnly,
    );
  }

  static String pathName(String dbName, {String dbSubDir}) => p.join(Saver._appDocDir.path,
      dbSubDir ?? Saver.defaultDbSubDir, "$dbName${Saver.defaultTermination}");

  /// If running from Flutter, this will get the application's documents directory.
  /// If running from tests, it will use the system's temp directory.
  static Future<void> _findAppDocDir() async {
    if (_appDocDir == null) {
      try {
        _appDocDir = await getApplicationDocumentsDirectory();
      } on MissingPluginException catch (_) {
        _appDocDir = Directory.systemTemp;
      }
    }
  }

  void add(Object simpleObj) {
    simpleObjs.add(simpleObj);
  }

  void addAll(List<Object> simpleObjs) {
    this.simpleObjs.addAll(simpleObjs);
  }

  static Uint8List encode(List<Object> simpleObjs) {
    Iterable<String> jsons = toJsons(simpleObjs);
    List<Uint8List> chunks = toUint8Lists(jsons);
    Uint8List encoded = concatUint8Lists(chunks);
    return encoded;
  }

  static Iterable<String> toJsons(List<Object> simpleObjs) {
    var jsonEncoder = JsonEncoder();
    return simpleObjs.map((j) => jsonEncoder.convert(j));
  }

  static List<Uint8List> toUint8Lists(Iterable<String> jsons) {
    List<Uint8List> chunks = [];

    for (String json in jsons) {
      Utf8Encoder encoder = Utf8Encoder();
      Uint8List bytes = encoder.convert(json);
      var size = bytes.length;

      if (size > maxJsonSize)
        throw PersistException("Size is $size but max is $maxJsonSize bytes.");

      chunks.add(Uint8List.fromList([size ~/ 256, size % 256]));
      chunks.add(bytes);
    }

    return chunks;
  }

  static Uint8List concatUint8Lists(List<Uint8List> chunks) {
    return Uint8List.fromList(chunks.expand((x) => (x)).toList());
  }
}

// /////////////////////////////////////////////////////////////////////////////////////////////////

/// This will load multiple simple objects in UTF-8 Json format.
///
/// 1) Example of loading from a file:
///
/// var loader = Loader();
/// List<Object> decoded = await loader.loadFile(file);
/// loader.printSimpleObjs(decoded);
///
/// 2) Example of loading from a file name:
///
/// var loader = Loader();
/// List<Object> decoded = await loader.load("my_file");
/// loader.printSimpleObjs(decoded);
///
/// 3) Example of decoding, and not loading:
///
/// Uint8List encoded = Saver.encode(Saver(simpleObjs).simpleObjs);
/// var loader = Loader();
/// List<Object> decoded = loader.decode(encoded);
/// loader.printSimpleObjs(decoded);
///
class Loader {
  //
  List<Object> simpleObjs;

  /// Loads from "appDocsDir/db/$dbName" (except in tests it loads from the system temp dir).
  /// If the file doesn't exist, returns null.
  /// If the file exists and is empty, returns an empty list.
  Future<List<Object>> load(String dbName, {String dbSubDir}) async {
    if (Saver._appDocDir == null) await Saver._findAppDocDir();
    String pathNameStr = Saver.pathName(dbName, dbSubDir: dbSubDir);
    var file = File(pathNameStr);
    return loadFile(file);
  }

  /// Loads from the given file.
  /// If the file doesn't exist, returns null.
  /// If the file exists and is empty, returns an empty list.
  Future<List<Object>> loadFile(File file) async {
    if (!file.existsSync())
      return null;
    else {
      Uint8List encoded;
      try {
        encoded = await file.readAsBytes();
      } catch (error) {
        if ((error is FileSystemException) && error.message.contains("No such file or directory"))
          return null;
        rethrow;
      }

      simpleObjs = decode(encoded);
      return simpleObjs;
    }
  }

  /// Returns the file length.
  /// If the file doesn't exist, or exists and is empty, returns 0.
  Future<int> length(String dbName, {String dbSubDir}) async {
    String pathNameStr = Saver.pathName(dbName, dbSubDir: dbSubDir);
    return lengthFile(File(pathNameStr));
  }

  /// Returns the file length.
  /// If the file doesn't exist, or exists and is empty, returns 0.
  Future<int> lengthFile(File file) async {
    if (!file.existsSync())
      return 0;
    else {
      try {
        return file.length();
      } catch (error) {
        if ((error is FileSystemException) && error.message.contains("No such file or directory"))
          return 0;
        rethrow;
      }
    }
  }

  /// Returns true if the file exist. False, otherwise.
  bool exists(String dbName, {String dbSubDir}) {
    String pathNameStr = Saver.pathName(dbName, dbSubDir: dbSubDir);
    return existsFile(File(pathNameStr));
  }

  /// Returns true if the file exist. False, otherwise.
  bool existsFile(File file) => file.existsSync();

  @override
  String toString() => simpleObjs == null
      ? simpleObjs
      : simpleObjs.map((obj) => print("$obj (${obj.runtimeType})")).join("\n");

  static List<Object> decode(Uint8List bytes) {
    List<Uint8List> chunks = toUint8Lists(bytes);
    Iterable<String> jsons = toJsons(chunks);
    return toSimpleObjs(jsons).toList();
  }

  static List<Uint8List> toUint8Lists(Uint8List bytes) {
    List<Uint8List> chunks = [];
    var buffer = bytes.buffer;
    int pos = 0;
    while (pos < bytes.length) {
      int size = bytes[pos] * 256 + bytes[pos + 1];
      Uint8List info = Uint8List.view(buffer, pos + 2, size);
      chunks.add(info);
      pos += 2 + size;
    }
    return chunks;
  }

  static Iterable<String> toJsons(Iterable<Uint8List> chunks) {
    var utf8Decoder = Utf8Decoder();
    return chunks.map((readChunks) => utf8Decoder.convert(readChunks));
  }

  static Iterable<Object> toSimpleObjs(Iterable<String> jsons) {
    var jsonDecoder = JsonDecoder();
    return jsons.map((json) => jsonDecoder.convert(json));
  }
}

// /////////////////////////////////////////////////////////////////////////////////////////////////

class Deleter {
  //
  /// Deletes "appDocsDir/db/$dbName" (except in tests it deletes from the system temp dir).
  /// If the file was deleted, returns true.
  /// If the file did not exist, return false.
  Future<bool> delete(String dbName, {String dbSubDir}) async {
    if (Saver._appDocDir == null) await Saver._findAppDocDir();
    String pathNameStr = Saver.pathName(dbName, dbSubDir: dbSubDir);
    File file = File(pathNameStr);
    return deleteFile(file);
  }

  /// Deletes the file.
  /// If the file was deleted, returns true.
  /// If the file did not exist, return false.
  Future<bool> deleteFile(File file) async {
    if (!file.existsSync())
      return false;
    else {
      try {
        await file.delete(recursive: true);
        return true;
      } catch (error) {
        if ((error is FileSystemException) && error.message.contains("No such file or directory"))
          return false;
        rethrow;
      }
    }
  }
}

// /////////////////////////////////////////////////////////////////////////////////////////////////

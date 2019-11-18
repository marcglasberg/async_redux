import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Developed by Marcelo Glasberg (Nov 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

/// This will save/load multiple simple objects in UTF-8 Json format.
///
/// Save example:
///
/// ```dart
/// var persist = LocalPersist("xyz");
/// List<Object> simpleObjs = ['"Hello"', '"How are you?"', [1, 2, 3], 42];
/// await persist.save();
/// ```
///
/// Load example:
///
/// ```dart
/// var persist = LocalPersist("xyz");
/// List<Object> decoded = await persist.load();
/// ```
///
class LocalPersist {
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

  final String dbName, dbSubDir;

  File _file;

  /// Saves to the given file.
  LocalPersist(File file)
      : assert(file != null),
        dbName = null,
        dbSubDir = null,
        _file = file;

  /// Saves to "appDocsDir/db/${dbName}.db"
  /// (except in tests it saves to the system temp dir).
  LocalPersist.fromFilename(String dbName, {String dbSubDir, bool append: false})
      : dbName = dbName,
        dbSubDir = dbSubDir,
        _file = null;

  /// Saves the given simple objects.
  /// If [append] is false (the default), the file will be overwritten.
  /// If [append] is true, it will write to the end of the file.
  Future<File> save(List<Object> simpleObjs, {bool append: false}) async {
    File file = this._file ?? await this.file();
    await file.create(recursive: true);

    Uint8List encoded = LocalPersist.encode(simpleObjs);

    return file.writeAsBytes(
      encoded,
      flush: true,
      mode: append ? FileMode.writeOnlyAppend : FileMode.writeOnly,
    );
  }

  /// Loads the simple objects from the file.
  /// If the file doesn't exist, returns null.
  /// If the file exists and is empty, returns an empty list.
  Future<List<Object>> load() async {
    File file = this._file ?? await this.file();

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

      List<Object> simpleObjs = decode(encoded);
      return simpleObjs;
    }
  }

  /// Same as [load], but expects the file to be a Map<String, dynamic>
  /// representing a single object. Will fail if it's not a map,
  /// or if contains more than one single object.
  Future<Map<String, dynamic>> loadAsObj() async {
    List<Object> simpleObjs = await load();
    if (simpleObjs == null) return null;
    if (simpleObjs.length != 1) throw PersistException("Not a single object.");
    var simpleObj = simpleObjs[0];
    if (simpleObj is! Map<String, dynamic>) throw PersistException("Not an object.");
    return simpleObj;
  }

  /// Deletes the file.
  /// If the file was deleted, returns true.
  /// If the file did not exist, return false.
  Future<bool> delete() async {
    File file = this._file ?? await this.file();

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

  /// Returns the file length.
  /// If the file doesn't exist, or exists and is empty, returns 0.
  Future<int> length() async {
    File file = this._file ?? await this.file();

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
  Future<bool> exists() async {
    File file = this._file ?? await this.file();
    return file.existsSync();
  }

  /// Gets the file.
  Future<File> file() async {
    if (_file != null)
      return _file;
    else {
      if (_appDocDir == null) await _findAppDocDir();
      String pathNameStr = pathName(dbName, dbSubDir: dbSubDir);
      _file = File(pathNameStr);
      return _file;
    }
  }

  static String simpleObjsToString(List<Object> simpleObjs) => simpleObjs == null
      ? simpleObjs
      : simpleObjs.map((obj) => "$obj (${obj.runtimeType})").join("\n");

  static String pathName(String dbName, {String dbSubDir}) => p.join(LocalPersist._appDocDir.path,
      dbSubDir ?? LocalPersist.defaultDbSubDir, "$dbName${LocalPersist.defaultTermination}");

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

  static Uint8List encode(List<Object> simpleObjs) {
    Iterable<String> jsons = objsToJsons(simpleObjs);
    List<Uint8List> chunks = jsonsToUint8Lists(jsons);
    Uint8List encoded = concatUint8Lists(chunks);
    return encoded;
  }

  static Iterable<String> objsToJsons(List<Object> simpleObjs) {
    var jsonEncoder = JsonEncoder();
    return simpleObjs.map((j) => jsonEncoder.convert(j));
  }

  static List<Uint8List> jsonsToUint8Lists(Iterable<String> jsons) {
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

  static List<Object> decode(Uint8List bytes) {
    List<Uint8List> chunks = bytesToUint8Lists(bytes);
    Iterable<String> jsons = uint8ListsToJsons(chunks);
    return toSimpleObjs(jsons).toList();
  }

  static List<Uint8List> bytesToUint8Lists(Uint8List bytes) {
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

  static Iterable<String> uint8ListsToJsons(Iterable<Uint8List> chunks) {
    var utf8Decoder = Utf8Decoder();
    return chunks.map((readChunks) => utf8Decoder.convert(readChunks));
  }

  static Iterable<Object> toSimpleObjs(Iterable<String> jsons) {
    var jsonDecoder = JsonDecoder();
    return jsons.map((json) => jsonDecoder.convert(json));
  }
}

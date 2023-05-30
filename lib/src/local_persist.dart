// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:async_redux/async_redux.dart';
import 'package:file/file.dart' as f;
import 'package:file/local.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// This will save/load objects into the local disk, as a '.json' file.
///
/// =========================================================
///
/// 1) Save a simple object in UTF-8 Json format.
///
/// Use [saveJson] to save as Json:
///
/// ```dart
/// var persist = LocalPersist("xyz");
/// var simpleObj = "Hello";
/// await persist.saveJson(simpleObj);
/// ```
///
/// Use [loadJson] to load from Json:
///
/// ```dart
/// var persist = LocalPersist("xyz");
/// Object? decoded = await persist.loadJson();
/// ```
///
/// Examples of valid JSON includes:
/// 42
/// 42.5
/// "abc"
/// [1, 2, 3]
/// ["42", 123]
/// {"42": 123}
///
///
/// Examples of invalid JSON includes:
/// [1, 2, 3][4, 5, 6] // Not valid because Json does not allow two separate objects.
/// 1, 2, 3 // Not valid because Json does not allow comma separated objects.
/// 'abc' // Not valid because string must use double quotes.
/// {42: "123"} // Not valid because a map key must be of type string.
///
/// =========================================================
///
/// 2) Save multiple simple objects in a concatenation of UTF-8 Json sequence.
/// Note: A Json sequence is NOT valid Json.
///
/// Use [save] to save a list of objects as a Json sequence:
///
/// ```dart
/// var persist = LocalPersist("xyz");
/// List<Object> simpleObjs = ['"Hello"', '"How are you?"', [1, 2, 3], 42];
/// await persist.save();
/// ```
///
/// The save method has an [append] parameter. If [append] is false (the default),
/// the file will be overwritten. If [append] is true, it will write to the end
/// of the file. Being able to append is the only advantage of saving as a Json
/// sequence instead of saving in regular Json. If you don't need to append,
/// use [saveJson] instead of [save].
///
/// Also, a limitation is that, in a json sequence, each object may have at most
/// 65.536 bytes. Note this refers to a single json object, not to the total json
/// sequence file, which may contain many objects.
///
/// Use [load] to load a list of objects from a Json sequence:
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
  /// Make it an empty string to remove it.
  static String defaultDbSubDir = "db";

  /// The default is adding a ".db" termination to the file name.
  /// This is not final, so you can change it.
  static String defaultTermination = ".db";

  static Directory? get appDocDir => _appDocDir;
  static Directory? _appDocDir;

  // In a json sequence, each object may have at most 65.536 bytes.
  // Note this refers to a single json object, not to the total json sequence file,
  // which may contain many objects.
  static const maxJsonSize = 256 * 256;

  static f.FileSystem _fileSystem = const LocalFileSystem();

  final String? dbName, dbSubDir;

  final List<String>? subDirs;

  final f.FileSystem _fileSystemRef;

  File? _file;

  /// Saves to `appDocsDir/db/${dbName}.db`
  ///
  /// If [dbName] is a String, it will be used as such.
  /// If [dbName] is an enum, it will use only the enum value itself.
  /// For example if `files` is an enum, then `LocalPersist(files.abc)`
  /// is the same as `LocalPersist("abc")`
  /// If [dbName] is another object type, a toString() will be done,
  /// and then the text after the last dot will be used.
  ///
  /// The default database directory [defaultDbSubDir] is `db`.
  /// You can change this variable to globally change the directory,
  /// or provide [dbSubDir] in the constructor.
  ///
  /// You can also provide other [subDirs] as Strings or enums.
  /// Example: `LocalPersist("photos", subDirs: ["article", "images"])`
  /// saves to `appDocsDir/db/article/images/photos.db`
  ///
  /// Important:
  /// — In tests, instead of using `appDocsDir` it will save to
  /// the system temp dir.
  /// — If you mock the file-system (see method `setFileSystem()`)
  /// it will save to `fileSystem.systemTempDirectory`.
  ///
  LocalPersist(Object dbName, {this.dbSubDir, List<Object>? subDirs})
      : dbName = _getStringFromEnum(dbName),
        subDirs = subDirs?.map((s) => _getStringFromEnum(s)).toList(),
        _file = null,
        _fileSystemRef = _fileSystem;

  /// Saves to the given file.
  LocalPersist.from(File file)
      : dbName = null,
        dbSubDir = null,
        subDirs = null,
        _file = file,
        _fileSystemRef = _fileSystem;

  /// Saves the given simple objects.
  /// If [append] is false (the default), the file will be overwritten.
  /// If [append] is true, it will write to the end of the file.
  Future<File> save(List<Object> simpleObjs, {bool append = false}) async {
    _checkIfFileSystemIsTheSame();
    File file = _file ?? await this.file();
    await file.create(recursive: true);

    Uint8List encoded = LocalPersist.encode(simpleObjs);

    return file.writeAsBytes(
      encoded,
      flush: true,
      mode: append ? FileMode.writeOnlyAppend : FileMode.writeOnly,
    );
  }

  /// Saves the given simple object as JSON (but in a '.db' file).
  /// If the file exists, it will be overwritten.
  Future<File> saveJson(Object? simpleObj) async {
    _checkIfFileSystemIsTheSame();

    Uint8List encoded = encodeJson(simpleObj);

    File file = _file ?? await this.file();
    await file.create(recursive: true);

    return file.writeAsBytes(
      encoded,
      flush: true,
      mode: FileMode.writeOnly,
    );
  }

  /// Loads the simple objects from the file.
  /// If the file doesn't exist, returns null.
  /// If the file exists and is empty, returns an empty list.
  Future<List<Object?>?> load() async {
    _checkIfFileSystemIsTheSame();
    File file = _file ?? await this.file();

    if (!file.existsSync())
      return null;
    else {
      Uint8List encoded;
      try {
        encoded = await file.readAsBytes();
      } catch (error) {
        if ((error is FileSystemException) && //
            error.message.contains("No such file or directory")) return null;
        rethrow;
      }

      List<Object?> simpleObjs = decode(encoded);
      return simpleObjs;
    }
  }

  /// Loads an object from a JSON file ('.db' file).
  /// If the file doesn't exist, returns null.
  /// Note: The file must contain a single JSON, which is NOT
  /// the default file-format for [LocalPersist].
  Future<Object?>? loadJson() async {
    _checkIfFileSystemIsTheSame();
    File file = _file ?? await this.file();

    if (!file.existsSync())
      return null;
    else {
      Uint8List encoded;
      try {
        encoded = await file.readAsBytes();
      } catch (error) {
        if ((error is FileSystemException) && //
            error.message.contains("No such file or directory")) return null;
        rethrow;
      }

      Object? simpleObjs = decodeJson(encoded);
      return simpleObjs;
    }
  }

  /// Same as [load], but expects the file to be a Map<String, dynamic>
  /// representing a single object. Will fail if it's not a map,
  /// or if contains more than one single object. It may return null.
  Future<Map<String, dynamic>?> loadAsObj() async {
    List<Object?>? simpleObjs = await load();
    if (simpleObjs == null) return null;
    if (simpleObjs.length != 1) throw PersistException("Not a single object: $simpleObjs");
    var simpleObj = simpleObjs[0];
    if ((simpleObj != null) && (simpleObj is! Map<String, dynamic>))
      throw PersistException("Not an object: $simpleObj");
    return simpleObj as FutureOr<Map<String, dynamic>?>;
  }

  /// Deletes the file.
  /// If the file was deleted, returns true.
  /// If the file did not exist, return false.
  Future<bool> delete() async {
    _checkIfFileSystemIsTheSame();
    File file = _file ?? await this.file();

    if (file.existsSync()) {
      try {
        file.deleteSync(recursive: true);
        return true;
      } catch (error) {
        if ((error is FileSystemException) && //
            error.message.contains("No such file or directory")) return false;
        rethrow;
      }
    } else
      return false;
  }

  /// Returns the file length.
  /// If the file doesn't exist, or exists and is empty, returns 0.
  Future<int> length() async {
    _checkIfFileSystemIsTheSame();
    File file = _file ?? await this.file();

    if (!file.existsSync())
      return 0;
    else {
      try {
        return file.length();
      } catch (error) {
        if ((error is FileSystemException) && //
            error.message.contains("No such file or directory")) return 0;
        rethrow;
      }
    }
  }

  /// Returns true if the file exist. False, otherwise.
  Future<bool> exists() async {
    _checkIfFileSystemIsTheSame();
    File file = _file ?? await this.file();
    return file.existsSync();
  }

  // If the fileSystemRef has changed, files will have to be recreated.
  void _checkIfFileSystemIsTheSame() {
    if (!identical(_fileSystemRef, _fileSystem)) _file = null;
  }

  /// Gets the file.
  Future<File> file() async {
    if (_file != null)
      return _file!;
    else {
      if (_appDocDir == null) await findAppDocDir();
      String pathNameStr = pathName(
        dbName,
        dbSubDir: dbSubDir,
        subDirs: subDirs,
      );
      _file = _fileSystem.file(pathNameStr);
      return _file!;
    }
  }

  static String? simpleObjsToString(List<Object?>? simpleObjs) => //
      simpleObjs == null
          ? simpleObjs as String?
          : simpleObjs.map((obj) => "$obj (${obj.runtimeType})").join("\n");

  static String pathName(
    String? dbName, {
    String? dbSubDir,
    List<String>? subDirs,
  }) {
    return p.joinAll([
      LocalPersist._appDocDir!.path,
      dbSubDir ?? LocalPersist.defaultDbSubDir,
      if (subDirs != null) ...subDirs,
      "$dbName${LocalPersist.defaultTermination}"
    ]);
  }

  static String _getStringFromEnum(Object dbName) =>
      (dbName is String) ? dbName : dbName.toString().split(".").last;

  /// If running from Flutter, this will get the application's documents directory.
  /// If running from tests, it will use the system's temp directory.
  static Future<void> findAppDocDir() async {
    if (_appDocDir != null) return;

    if (_fileSystem == const LocalFileSystem()) {
      try {
        _appDocDir = await getApplicationDocumentsDirectory();
      } on MissingPluginException catch (_) {
        _appDocDir = const LocalFileSystem().systemTempDirectory;
      }
    } else
      _appDocDir = _fileSystem.systemTempDirectory;
  }

  static Uint8List encode(List<Object> simpleObjs) {
    Iterable<String> jsons = objsToJsons(simpleObjs);
    List<Uint8List> chunks = jsonsToUint8Lists(jsons);
    Uint8List encoded = concatUint8Lists(chunks);
    return encoded;
  }

  static Iterable<String> objsToJsons(List<Object> simpleObjs) {
    var jsonEncoder = const JsonEncoder();
    return simpleObjs.map((j) => jsonEncoder.convert(j));
  }

  static List<Uint8List> jsonsToUint8Lists(Iterable<String> jsons) {
    List<Uint8List> chunks = [];

    for (String json in jsons) {
      Utf8Encoder encoder = const Utf8Encoder();
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

  static List<Object?> decode(Uint8List bytes) {
    List<Uint8List> chunks = bytesToUint8Lists(bytes);
    Iterable<String> jsons = uint8ListsToJsons(chunks);
    return toSimpleObjs(jsons).toList();
  }

  /// Decodes a single JSON into a simple object, from the given [bytes].
  static Object? decodeJson(Uint8List bytes) {
    ByteBuffer buffer = bytes.buffer;
    Uint8List info = Uint8List.view(buffer);
    var utf8Decoder = const Utf8Decoder();
    String json = utf8Decoder.convert(info);
    var jsonDecoder = const JsonDecoder();
    return jsonDecoder.convert(json);
  }

  /// Decodes a single simple object into a JSON, from the given [simpleObj].
  static Uint8List encodeJson(Object? simpleObj) {
    var jsonEncoder = const JsonEncoder();
    String json = jsonEncoder.convert(simpleObj);

    Utf8Encoder encoder = const Utf8Encoder();
    Uint8List encoded = encoder.convert(json);
    return encoded;
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
    var utf8Decoder = const Utf8Decoder();
    return chunks.map((readChunks) => utf8Decoder.convert(readChunks));
  }

  static Iterable<Object?> toSimpleObjs(Iterable<String> jsons) {
    var jsonDecoder = const JsonDecoder();
    return jsons.map((json) => jsonDecoder.convert(json));
  }

  /// You can set a memory file-system in your tests. For example:
  /// ```
  /// final mfs = MemoryFileSystem();
  /// setUpAll(() { LocalPersist.setFileSystem(mfs); });
  /// tearDownAll(() { LocalPersist.resetFileSystem(); });
  ///  ...
  /// expect(mfs.file('myPic.jpg').readAsBytesSync(), List.filled(100, 0));
  /// ```
  static void setFileSystem(f.FileSystem fileSystem) {
    _fileSystem = fileSystem;
  }

  static f.FileSystem getFileSystem() => _fileSystem;

  static void resetFileSystem() => setFileSystem(const LocalFileSystem());
}

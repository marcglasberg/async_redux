// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:async_redux/src/persistor.dart';
import 'package:file/file.dart' as f;
import 'package:file/local.dart';
import 'package:path/path.dart' as p;

import 'local_persist.dart';

/// Save a simple-object in a file, in UTF-8 Json format.
///
/// Use [save] to save as Json:
///
/// ```dart
/// var persist = LocalJsonPersist("xyz");
/// var simpleObj = "Hello";
/// await persist.saveJson(simpleObj);
/// ```
///
/// Use [load] to load from Json:
///
/// ```dart
/// var persist = LocalJsonPersist("xyz");
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
class LocalJsonPersist {
  //
  /// The default is saving/loading to/from "appDocsDir/db/".
  /// This is not final, so you can change it.
  /// Make it an empty string to remove it.
  static String defaultDbSubDir = "db";

  /// If running from Flutter, the default base directory is the application's documents dir.
  /// If running from tests (detected by the `LocalFileSystem` not being present),
  /// it will use the system's temp directory.
  ///
  /// You can change this variable to globally change the directory:
  /// ```
  /// // Will use the application's cache directory.
  /// LocalPersist.useBaseDirectory = LocalPersist.useAppCacheDir;
  ///
  /// // Will use the application's downloads directory.
  /// LocalPersist.useBaseDirectory = LocalPersist.useAppDownloadsDir;
  ///
  /// // Will use whatever Directory is given.
  /// LocalPersist.useBaseDirectory = () => LocalPersist.useCustomBaseDirectory(baseDirectory: myDir);
  /// ```
  static Future<void> Function() useBaseDirectory = useAppDocumentsDir;

  /// The default is adding a ".json" termination to the file name.
  static const String jsonTermination = ".json";

  static Directory? get appDocDir => _baseDirectory;

  static Directory? get _baseDirectory => LocalPersist.appDocDir;

  static f.FileSystem get _fileSystem => LocalPersist.getFileSystem();

  final String? dbName, dbSubDir;

  final List<String>? subDirs;

  final f.FileSystem _fileSystemRef;

  File? _file;

  /// Saves to `appDocsDir/db/${dbName}.json`
  ///
  /// If [dbName] is a String, it will be used as such.
  /// If [dbName] is an enum, it will use only the enum value itself.
  /// For example if `files` is an enum, then `LocalJsonPersist(files.abc)`
  /// is the same as `LocalJsonPersist("abc")`
  /// If [dbName] is another object type, its [toString] will be called,
  /// and then the text after the last dot will be used.
  ///
  /// The default database directory [defaultDbSubDir] is `db`.
  /// You can change this variable to globally change the directory,
  /// or provide [dbSubDir] in the constructor.
  ///
  /// You can also provide other [subDirs] as Strings or enums.
  /// Example: `LocalJsonPersist("photos", subDirs: ["article", "images"])`
  /// saves to `appDocsDir/db/article/images/photos.db`
  ///
  /// Important:
  /// — In tests, instead of using `appDocsDir` it will save to
  /// the system temp dir.
  /// — If you mock the file-system (see method `setFileSystem()`)
  /// it will save to `fileSystem.systemTempDirectory`.
  ///
  LocalJsonPersist(Object dbName, {this.dbSubDir, List<Object>? subDirs})
      : dbName = _getStringFromEnum(dbName),
        subDirs = subDirs?.map((s) => _getStringFromEnum(s)).toList(),
        _file = null,
        _fileSystemRef = _fileSystem;

  /// Saves to the given file.
  LocalJsonPersist.from(File file)
      : dbName = null,
        dbSubDir = null,
        subDirs = null,
        _file = file,
        _fileSystemRef = _fileSystem;

  /// If running from Flutter, this will get the application's documents directory.
  /// If running from tests, it will use the system's temp directory.
  static Future<void> useAppDocumentsDir() => LocalPersist.useAppDocumentsDir();

  /// If running from Flutter, this will get the application's cache directory.
  /// If running from tests, it will use the system's temp directory.
  static Future<void> useAppCacheDir() => LocalPersist.useAppCacheDir();

  /// If running from Flutter, this will get the application's downloads directory.
  /// If running from tests, it will use the system's temp directory.
  static Future<void> useAppDownloadsDir() => LocalPersist.useAppDownloadsDir();

  /// If running from Flutter, the base directory will be the given [baseDirectory].
  /// If running from tests, it will use the optional [testDirectory], or if this is not provided,
  /// it will use the system's temp directory.
  static Future<void> useCustomBaseDirectory({
    required Directory baseDirectory,
    Directory? testDirectory,
  }) =>
      LocalPersist.useCustomBaseDirectory(baseDirectory: baseDirectory, testDirectory: testDirectory);

  /// Saves the given simple object as JSON.
  /// If the file exists, it will be overwritten.
  Future<File> save(Object? simpleObj) async {
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

  /// Loads a simple-object from a JSON file. If the file doesn't exist, returns null.
  /// A JSON can be a String, a number, null, true, false, '{' (a map) or ']' (a list).
  /// Note: The file must contain a single JSON, and it can't be empty. It can, however
  /// simple contain 'null' (without the quotes) which will return null.
  Future<Object?> load() async {
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

  /// This method can be used if you were using a Json sequence file with a ".db" termination,
  /// and wants to convert it to a regular Json file. This only works if your original ".db"
  /// file has a single object.
  ///
  /// 1) It first loads a Json file called "[dbName].json".
  /// - If the file exists and is NOT empty, return its content as a single simple object.
  /// - If the file exists and is empty, returns null.
  /// - If the file doesn't exist, goes to step 2.
  ///
  /// 2) Next, tries loading a Json-SEQUENCE file called "[dbName].db".
  /// - If the file doesn't exist, returns null.
  /// - If the file exists and is empty, saves it as an empty Json file called "[dbName].json"
  /// - If the file exists with a single object, saves it as a Json file called "[dbName].json"
  /// - If the file exists and has 2 or more objects:
  ///   * If [isList] is false, throws an exception.
  ///   * If [isList] is true, wraps the result in a List<Object>.
  /// - Then deletes the "[dbName].db" file (always deletes, no matter what happens).
  ///
  /// Note: In effect, this will convert all files it loads from a Json-sequence to Json.
  /// This only works if the original ".db" file is a Json-sequence file, and it's on you
  /// to make sure that's the case.
  ///
  Future<Object?> loadConverting({required bool isList}) async {
    //
    _checkIfFileSystemIsTheSame();
    File file = _file ?? await this.file();

    if (!file.existsSync())
      return _readsFromJsonSequenceDbFile(isList);
    else {
      Uint8List encoded;
      try {
        // Loads the '.json' (Json) file.
        encoded = await file.readAsBytes();
      } catch (error) {
        if ((error is FileSystemException) && //
            error.message.contains("No such file or directory"))
          return _readsFromJsonSequenceDbFile(isList);
        rethrow;
      }

      Object? simpleObjs = decodeJson(encoded);
      return simpleObjs;
    }
  }

  /// Reads a Json-sequence from a '.db' file.
  Future<Object?> _readsFromJsonSequenceDbFile(bool isList) async {
    //
    /// Prepares to open the '.db' file with the same name and location.
    var jsonSequenceFile = LocalPersist(dbName!, dbSubDir: dbSubDir, subDirs: subDirs);

    // If the '.db' (Json-sequence) file exists,
    if (await jsonSequenceFile.exists()) {
      //
      // Loads the '.db' file into memory.
      List<Object?>? objs = await jsonSequenceFile.load();

      // Deletes the Json-sequence file.
      jsonSequenceFile.delete();

      if (isList) {
        objs ??= const [];

        // Saves the '.json' (Json) file, so that it loads directly, next time.
        await save(objs);

        return objs;
      }
      //
      // Not a list.
      else {
        if (objs != null && objs.length > 1)
          throw PersistException("Json sequence to Json: ${objs.length} objects: $objs.");
        //
        else {
          // Saves the '.json' (Json) file, so that it loads directly, next time.
          var obj = (objs == null || objs.isEmpty) ? null : objs[0];

          await save(obj);

          return obj;
        }
      }
    }
    //
    else
      return null;
  }

  /// Same as [load], but expects the file to be a Map<String, dynamic>
  /// representing a single object. Will fail if it's not a map. It may return null.
  Future<Map<String, dynamic>?> loadAsObj() async {
    Object? simpleObj = await load();
    if (simpleObj == null) return null;
    if (simpleObj is! Map<String, dynamic>) throw PersistException("Not an object: $simpleObj");
    return simpleObj;
  }

  /// Same as [loadConverting], but expects the file to be a Map<String, dynamic>
  /// representing a single object. Will fail if it's not a map. It may return null.
  Future<Map<String, dynamic>?> loadAsObjConverting() async {
    Object? simpleObj = await loadConverting(isList: false);
    if (simpleObj == null) return null;
    if (simpleObj is! Map<String, dynamic>) throw PersistException("Not an object: $simpleObj");
    return simpleObj;
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
      if (_baseDirectory == null) await useBaseDirectory();
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
      LocalJsonPersist._baseDirectory!.path,
      dbSubDir ?? LocalJsonPersist.defaultDbSubDir,
      if (subDirs != null) ...subDirs,
      "$dbName${LocalJsonPersist.jsonTermination}"
    ]);
  }

  static String _getStringFromEnum(Object dbName) =>
      (dbName is String) ? dbName : dbName.toString().split(".").last;

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

  /// You can set a memory file-system in your tests. For example:
  /// ```
  /// final mfs = MemoryFileSystem();
  /// setUpAll(() { LocalJsonPersist.setFileSystem(mfs); });
  /// tearDownAll(() { LocalJsonPersist.resetFileSystem(); });
  ///  ...
  /// expect(mfs.file('myPic.jpg').readAsBytesSync(), List.filled(100, 0));
  /// ```
  static void setFileSystem(f.FileSystem fileSystem) {
    LocalPersist.setFileSystem(fileSystem);
  }

  static void resetFileSystem() => LocalPersist.setFileSystem(const LocalFileSystem());
}

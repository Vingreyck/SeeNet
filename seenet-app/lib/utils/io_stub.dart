import 'dart:typed_data';

class File {
  final String path;
  File(this.path);
  Future<bool> exists() async => false;
  Future<List<int>> readAsBytes() async => [];
  Future<Uint8List> readAsBytesSync() => Future.value(Uint8List(0));
  Future<File> writeAsString(String contents, {bool flush = false}) async => this;
  Future<File> writeAsBytes(List<int> bytes, {bool flush = false}) async => this;
  int lengthSync() => 0;
  String get uri => path;
}

class Directory {
  final String path;
  Directory(this.path);
  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
}

class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isMacOS => false;
  static bool get isWeb => true;
}

class SocketException implements Exception {
  final String message;
  const SocketException(this.message);
  @override
  String toString() => 'SocketException: $message';
}

class HttpException implements Exception {
  final String message;
  const HttpException(this.message);
  @override
  String toString() => 'HttpException: $message';
}
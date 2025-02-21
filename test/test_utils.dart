import 'dart:io';

/// Do not run on CI environments, like GitHub Actions.
bool get isCI => Platform.environment.containsKey('CI');

# Migrating to AsyncRedux 30

AsyncRedux 30 requires Dart 3.13 and Flutter 3.47 or later, and supports Flutter 3.50.
The default error dialogs use the standalone Material and Cupertino packages.

## Imports and dependencies

Add `material_ui` and, when importing Cupertino APIs, `cupertino_ui` as direct
app dependencies. Replace the corresponding SDK imports:

```dart
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
```

The app's themes, localization delegates and dialogs must use types from the same
design packages. For localized apps, the new Material package provides
`GlobalMaterialLocalizations.delegates`, including the Widgets and Cupertino delegates.
Keep any additional localization delegates supplied by the app.

`UserExceptionDialog` and the dialog helpers now use these packages directly.
The `onShowUserExceptionDialog` callback remains available for custom dialogs.
Store, state selection, dispatch and automatic persistence APIs are unchanged.

## Development

Tests use `bdd_framework` 5.x. Its business-test runner is imported from
`package:bdd_framework/flutter_test.dart`; the widget runner remains a separate
entry point. The analyzer plugin resolves its dependencies independently.

Run `dart analyze` from the package root to include plugin diagnostics, and run
`flutter test`. Follow the official design-package migration guide for app-specific
changes: https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui

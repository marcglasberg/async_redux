# Migrating to `material_ui` and `cupertino_ui`

Official guide: https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui

## What must change

Only two files in `lib/` use Material/Cupertino:

- `lib/src/user_exception_dialog.dart` — the default error dialog
  (`AlertDialog`, `TextButton`, `CupertinoAlertDialog`, `CupertinoDialogAction`).
- `lib/src/show_dialog_super.dart` — `showDialog`, `showCupertinoDialog`, `Colors`.

No public API exposes Material/Cupertino types. `test/` and `example/` also import
`package:flutter/material.dart`.

## Choose one approach

**A) Migrate to the new packages (breaking change, major version).**

1. Check the current SDK requirements of `material_ui` and `cupertino_ui` on pub.dev,
   and raise `environment` in `pubspec.yaml` to match.
2. Add `material_ui` and `cupertino_ui` to `dependencies`.
3. Run `dart fix --apply --code=migrate_design_widgets` (also in `example/`).
4. In the CHANGELOG, tell users of apps still on `package:flutter/material.dart` that
   the default dialog now needs the new packages' localizations: they must either migrate
   their app, or provide their own dialog through `UserExceptionDialog(onShowUserExceptionDialog: ...)`.

**B) Remove the design dependency (no API change, visual change).**

Rewrite the default dialog using only `package:flutter/widgets.dart`
(`showGeneralDialog` plus a custom widget). It then works in both old and new apps,
with no compatibility bridge. Mention the new look in the CHANGELOG.

## Verify

1. `flutter analyze` and `flutter test` must pass.
2. Add a widget test that dispatches an action throwing `UserException` inside a
   `material_ui` `MaterialApp` (no `MaterialUiCompatibilityBridge`), for both
   `TargetPlatform.android` and `TargetPlatform.iOS`, and checks the dialog shows.
   With approach B, also test inside a `package:flutter/material.dart` `MaterialApp`.
3. Update the `UserExceptionDialog` docs and the website accordingly.

import 'package:async_redux/async_redux.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

/// Use it like this:
///
/// ```
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context)
///     => StoreProvider<AppState>(
///       store: store,
///       child: MaterialApp(
///           home: UserExceptionDialog<AppState>(
///             child: MyHomePage(),
///           )));
/// }
///
/// ```
///
/// For more info, see: https://pub.dartlang.org/packages/async_redux
///
class UserExceptionDialog<St> extends StatelessWidget {
  final Widget child;
  final ShowUserExceptionDialog? onShowUserExceptionDialog;

  UserExceptionDialog({
    required this.child,
    this.onShowUserExceptionDialog,
  });

  @override
  Widget build(BuildContext context) {
    return StoreConnector<St, _ViewModel>(
      model: _ViewModel(),
      builder: (context, vm) {
        return _UserExceptionDialogWidget(child, vm.error, onShowUserExceptionDialog);
      },
    );
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _UserExceptionDialogWidget extends StatefulWidget {
  final Widget child;
  final Event<UserException>? error;
  final ShowUserExceptionDialog onShowUserExceptionDialog;

  _UserExceptionDialogWidget(
    this.child,
    this.error,
    ShowUserExceptionDialog? onShowUserExceptionDialog,
  ) : onShowUserExceptionDialog = //
            onShowUserExceptionDialog ?? _defaultUserExceptionDialog;

  static void _defaultUserExceptionDialog(
    BuildContext context,
    UserException userException,
  ) {
    defaultTargetPlatform;
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS)) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: Text(userException.dialogTitle()!),
          content: Text(userException.dialogContent()!),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        ),
      );
    } else
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(userException.dialogTitle()!),
          content: Text(userException.dialogContent()!),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        ),
      );
  }

  @override
  _UserExceptionDialogState createState() => _UserExceptionDialogState();
}

// ////////////////////////////////////////////////////////////////////////////

class _UserExceptionDialogState extends State<_UserExceptionDialogWidget> {
  @override
  void didUpdateWidget(_UserExceptionDialogWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    UserException? userException = widget.error!.consume();

    if (userException != null)
      WidgetsBinding.instance!.addPostFrameCallback((_) {
        widget.onShowUserExceptionDialog(context, userException);
      });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ////////////////////////////////////////////////////////////////////////////

class _ViewModel extends BaseModel {
  _ViewModel();

  Event<UserException>? error;

  _ViewModel.build({required this.error});

  @override
  _ViewModel fromStore() => _ViewModel.build(
        error: Event(getAndRemoveFirstError!()),
      );

  /// Does not respect equals contract:
  /// A==B ➜ true only if B.error.state is not null.
  @override
  bool operator ==(Object other) {
    return error!.state == null;
  }

  @override
  int get hashCode => error.hashCode;
}

// ////////////////////////////////////////////////////////////////////////////

typedef ShowUserExceptionDialog = void Function(
  BuildContext context,
  UserException userException,
);

// ////////////////////////////////////////////////////////////////////////////

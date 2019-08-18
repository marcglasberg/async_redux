import 'package:flutter/material.dart';

import '../async_redux.dart';

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
  final ShowUserExceptionDialog onShowUserExceptionDialog;

  UserExceptionDialog({
    @required this.child,
    this.onShowUserExceptionDialog,
  }) : assert(child != null);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<St, _ViewModel>(
      model: _ViewModel(),
      builder: (context, vm) {
        return _Widget(child, vm.error, onShowUserExceptionDialog);
      },
    );
  }
}

class _Widget extends StatefulWidget {
  final Widget child;
  final Event<UserException> error;
  final ShowUserExceptionDialog onShowUserExceptionDialog;

  _Widget(
    this.child,
    this.error,
    ShowUserExceptionDialog onShowUserExceptionDialog,
  ) : onShowUserExceptionDialog = onShowUserExceptionDialog ?? _defaultUserExceptionDialog;

  static void _defaultUserExceptionDialog(
    BuildContext context,
    UserException userException,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(userException.dialogTitle()),
        content: Text(userException.dialogContent()),
        actions: [
          FlatButton(
            child: Text("OK"),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }

  @override
  _WidgetState createState() => _WidgetState();
}

class _WidgetState extends State<_Widget> {
  @override
  void didUpdateWidget(_Widget oldWidget) {
    super.didUpdateWidget(oldWidget);

    UserException userException = widget.error.consume();

    if (userException != null)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onShowUserExceptionDialog(context, userException);
      });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ViewModel extends BaseModel {
  _ViewModel();

  Event<UserException> error;

  _ViewModel.build({@required this.error});

  @override
  _ViewModel fromStore() => _ViewModel.build(
        error: Event(store.getAndRemoveFirstError()),
      );

  /// Does not respect equals contract:
  /// A==B ➜ true only if B.error.state is not null.
  @override
  bool operator ==(Object other) {
    return error.state == null;
  }

  @override
  int get hashCode => error.hashCode;
}

typedef ShowUserExceptionDialog = void Function(BuildContext context, UserException userException);

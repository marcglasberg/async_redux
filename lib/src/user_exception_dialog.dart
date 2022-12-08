import 'dart:collection';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'show_dialog_super.dart';

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

  /// If false (the default), the dialog will appear in the context of the
  /// [NavigateAction.navigatorKey]. If you don't set up that key, or if you
  /// pass `true` here, it will use the local context of the
  /// [UserExceptionDialog] widget.
  ///
  /// Make sure this is `false` if you are putting the [UserExceptionDialog] in
  /// the `builder` parameter of the [MaterialApp] widget, because in this case
  /// the [UserExceptionDialog] will be above the app's [Navigator], and if
  /// you open the dialog in the local context you won't be able to use the
  /// Android back-button to close it.
  final bool useLocalContext;

  UserExceptionDialog({
    required this.child,
    this.onShowUserExceptionDialog,
    this.useLocalContext = false,
  });

  @override
  Widget build(BuildContext context) {
    //
    return StoreConnector<St, _Vm>(
      vm: () => _Factory<St>(),
      builder: (context, vm) {
        //
        Event<UserException>? errorEvent = //
            (_Factory._errorEvents.isEmpty) //
                ? null
                : _Factory._errorEvents.removeFirst();

        return _UserExceptionDialogWidget(
          child,
          errorEvent,
          onShowUserExceptionDialog,
          useLocalContext,
        );
      },
    );
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _UserExceptionDialogWidget extends StatefulWidget {
  final Widget child;
  final Event<UserException>? errorEvent;
  final ShowUserExceptionDialog onShowUserExceptionDialog;
  final bool useLocalContext;

  _UserExceptionDialogWidget(
    this.child,
    this.errorEvent,
    ShowUserExceptionDialog? onShowUserExceptionDialog,
    this.useLocalContext,
  ) : onShowUserExceptionDialog = //
            onShowUserExceptionDialog ?? _defaultUserExceptionDialog;

  static void _defaultUserExceptionDialog(
    BuildContext context,
    UserException userException,
    bool useLocalContext,
  ) {
    if (!useLocalContext) {
      var navigatorContext = NavigateAction.navigatorKey?.currentContext;
      if (navigatorContext != null) context = navigatorContext;
    }

    Locale? locale;
    try {
      locale = Localizations.localeOf(context);
    } catch (error) {
      // This works when the MaterialApp widget is initialized.
    }

    defaultTargetPlatform;
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS)) {
      showCupertinoDialogSuper<int>(
        context: context,
        onDismissed: (int? result) {
          if (result == 1)
            userException.onOk?.call();
          else if (result == 2)
            userException.onCancel?.call();
          else {
            if (userException.onCancel == null)
              userException.onOk?.call();
            else
              userException.onCancel?.call();
          }
        },
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: Text(userException.dialogTitle(locale)),
          content: Text(userException.dialogContent(locale)),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop(1);
              },
            ),
            if (userException.onCancel != null)
              CupertinoDialogAction(
                child: const Text("CANCEL"),
                onPressed: () {
                  Navigator.of(context).pop(2);
                },
              )
          ],
        ),
      );
    } else
      showDialogSuper<int>(
        context: context,
        onDismissed: (int? result) {
          if (result == 1)
            userException.onOk?.call();
          else if (result == 2)
            userException.onCancel?.call();
          else {
            if (userException.onCancel == null)
              userException.onOk?.call();
            else
              userException.onCancel?.call();
          }
        },
        builder: (BuildContext context) => AlertDialog(
          title: Text(userException.dialogTitle(locale)),
          content: Text(userException.dialogContent(locale)),
          actions: [
            if (userException.onCancel != null)
              TextButton(
                child: const Text("CANCEL"),
                onPressed: () {
                  Navigator.of(context).pop(2);
                },
              ),
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop(1);
              },
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

    UserException? userException = widget.errorEvent?.consume();

    if (userException != null)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onShowUserExceptionDialog(context, userException, widget.useLocalContext);
      });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ////////////////////////////////////////////////////////////////////////////

class _Factory<St> extends VmFactory<St, UserExceptionDialog> {
  static final Queue<Event<UserException>> _errorEvents = Queue();

  @override
  _Vm fromStore() {
    UserException? error = getAndRemoveFirstError();

    if (error != null) _errorEvents.add(Event(error));

    return _Vm(
      rebuild: (error != null),
    );
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _Vm extends Vm {
  //
  final bool rebuild;

  _Vm({required this.rebuild});

  /// Does not respect equals contract:
  /// Is not equal when it should rebuild.
  @override
  bool operator ==(Object other) => !rebuild;

  @override
  int get hashCode => rebuild.hashCode;
}

// ////////////////////////////////////////////////////////////////////////////

typedef ShowUserExceptionDialog = void Function(
  BuildContext context,
  UserException userException,
  bool useLocalContext,
);

// ////////////////////////////////////////////////////////////////////////////

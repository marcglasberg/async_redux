// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'show_dialog_super.dart';

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
/// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux
///
class UserExceptionDialog<St> extends StatefulWidget {
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
  State<UserExceptionDialog<St>> createState() => _UserExceptionDialogState<St>();
}

class _UserExceptionDialogState<St> extends State<UserExceptionDialog<St>> {
  Store<St>? _store;
  StreamSubscription<St>? _subscription;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Depend only on replacement of the store, not on changes to its state.
    context.dependOnInheritedWidgetOfExactType<StoreProvider<St>>();
    final store = StoreProvider.backdoorInheritedWidget<St>(context);
    if (!identical(store, _store)) {
      _subscription?.cancel();
      _store = store;
      _subscription = store.onChange.listen((_) => _scheduleErrors());
    }

    // Also handle errors queued before mounting or before replacing the store.
    _scheduleErrors();
  }

  void _scheduleErrors() {
    if (!mounted || _scheduled || !_store!.internalHasErrors) return;

    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;

      final store = _store!;
      // Leave errors in their store until they can actually be displayed.
      // This also avoids losing errors if unmounted before this callback runs.
      while (mounted && identical(store, _store)) {
        final error = store.getAndRemoveFirstError();
        if (error == null) break;
        (widget.onShowUserExceptionDialog ?? _defaultUserExceptionDialog)(
            context, error, widget.useLocalContext);
      }
    });
    // A stream event can arrive while the app is idle, with no frame scheduled.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  static void _defaultUserExceptionDialog(
    BuildContext context,
    UserException userException,
    bool useLocalContext,
  ) {
    if (!useLocalContext) {
      var navigatorContext = NavigateAction.navigatorKey?.currentContext;
      if (navigatorContext != null) context = navigatorContext;
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
        builder: (BuildContext context) {
          var (title, content) = userException.titleAndContent();
          return CupertinoAlertDialog(
            title: Text(title),
            content: Text(content),
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
          );
        },
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
        builder: (BuildContext context) {
          var (title, content) = userException.titleAndContent();
          return AlertDialog(
            title: Text(title),
            content: Text(content),
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
          );
        },
      );
  }
}

typedef ShowUserExceptionDialog = void Function(
  BuildContext context,
  UserException userException,
  bool useLocalContext,
);

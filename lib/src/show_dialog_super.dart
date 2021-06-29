import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Displays a Material dialog above the current contents of the app, with
/// Material entrance and exit animations, modal barrier color, and modal
/// barrier behavior (dialog is dismissible with a tap on the barrier).
///
/// This function takes a [builder] which typically builds a [Dialog] widget.
/// Content below the dialog is dimmed with a [ModalBarrier]. The widget
/// returned by the [builder] does not share a context with the location that
/// [showDialogSuper] is originally called from. Use a [StatefulBuilder] or a
/// custom [StatefulWidget] if the dialog needs to update dynamically.
///
/// The [child] argument is deprecated, and should be replaced with [builder].
///
/// The [context] argument is used to look up the [Navigator] and [Theme] for
/// the dialog. It is only used when the method is called. Its corresponding
/// widget can be safely removed from the tree before the dialog is closed.
///
/// The [onDismissed] callback will be called when the dialog is dismissed.
/// Note: If the dialog is popped by `Navigator.of(context).pop(result)`,
/// then the `result` will be available to the callback. That way you can
/// differentiate between the dialog being dismissed by an Ok or a Cancel
/// button, for example.
///
/// The [barrierDismissible] argument is used to indicate whether tapping on the
/// barrier will dismiss the dialog. It is `true` by default and can not be `null`.
///
/// The [barrierColor] argument is used to specify the color of the modal
/// barrier that darkens everything below the dialog. If `null` the default color
/// `Colors.black54` is used.
///
/// The [useSafeArea] argument is used to indicate if the dialog should only
/// display in 'safe' areas of the screen not used by the operating system
/// (see [SafeArea] for more details). It is `true` by default, which means
/// the dialog will not overlap operating system areas. If it is set to `false`
/// the dialog will only be constrained by the screen size. It can not be `null`.
///
/// The [useRootNavigator] argument is used to determine whether to push the
/// dialog to the [Navigator] furthest from or nearest to the given [context].
/// By default, [useRootNavigator] is `true` and the dialog route created by
/// this method is pushed to the root navigator. It can not be `null`.
///
/// The [routeSettings] argument is passed to [showGeneralDialog],
/// see [RouteSettings] for details.
///
/// If the application has multiple [Navigator] objects, it may be necessary to
/// call `Navigator.of(context, rootNavigator: true).pop(result)` to close the
/// dialog rather than just `Navigator.pop(context, result)`.
///
/// Returns a [Future] that resolves to the value (if any) that was passed to
/// [Navigator.pop] when the dialog was closed.
///
/// ### State Restoration in Dialogs
///
/// Using this method will not enable state restoration for the dialog. In order
/// to enable state restoration for a dialog, use [Navigator.restorablePush]
/// or [Navigator.restorablePushNamed] with [DialogRoute].
///
/// For more information about state restoration, see [RestorationManager].
///
/// {@tool sample --template=freeform}
///
/// This sample demonstrates how to create a restorable Material dialog. This is
/// accomplished by enabling state restoration by specifying
/// [MaterialApp.restorationScopeId] and using [Navigator.restorablePush] to
/// push [DialogRoute] when the button is tapped.
///
/// {@macro flutter.widgets.RestorationManager}
///
/// ```dart imports
/// import 'package:flutter/material.dart';
/// ```
///
/// ```dart
/// void main() {
///   runApp(MyApp());
/// }
///
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       restorationScopeId: 'app',
///       title: 'Restorable Routes Demo',
///       home: MyHomePage(),
///     );
///   }
/// }
///
/// class MyHomePage extends StatelessWidget {
///   static Route<Object?> _dialogBuilder(BuildContext context, Object? arguments) {
///     return DialogRoute<void>(
///       context: context,
///       builder: (BuildContext context) => const AlertDialog(title: Text('Material Alert!')),
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       body: Center(
///         child: OutlinedButton(
///           onPressed: () {
///             Navigator.of(context).restorablePush(_dialogBuilder);
///           },
///           child: const Text('Open Dialog'),
///         ),
///       ),
///     );
///   }
/// }
/// ```
///
/// {@end-tool}
///
/// See also:
///
///  * [AlertDialog], for dialogs that have a row of buttons below a body.
///  * [SimpleDialog], which handles the scrolling of the contents and does
///    not show buttons below its body.
///  * [Dialog], on which [SimpleDialog] and [AlertDialog] are based.
///  * [showCupertinoDialog], which displays an iOS-style dialog.
///  * [showGeneralDialog], which allows for customization of the dialog popup.
///  * <https://material.io/design/components/dialogs.html>
Future<T?> showDialogSuper<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor = Colors.black54,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  void Function(T?)? onDismissed,
}) async {
  T? result = await showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
  );

  if (onDismissed != null) onDismissed(result);

  return result;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////

/// Displays an iOS-style dialog above the current contents of the app, with
/// iOS-style entrance and exit animations, modal barrier color, and modal
/// barrier behavior (by default, the dialog is not dismissible with a tap on
/// the barrier).
///
/// This function takes a [builder] which typically builds a [CupertinoAlertDialog]
/// widget. Content below the dialog is dimmed with a [ModalBarrier]. The widget
/// returned by the [builder] does not share a context with the location that
/// [showCupertinoDialogSuper] is originally called from. Use a [StatefulBuilder]
/// or a custom [StatefulWidget] if the dialog needs to update dynamically.
///
/// The [context] argument is used to look up the [Navigator] for the dialog.
/// It is only used when the method is called. Its corresponding widget can
/// be safely removed from the tree before the dialog is closed.
///
/// The [onDismissed] callback will be called when the dialog is dismissed.
/// Note: If the dialog is popped by `Navigator.of(context).pop(result)`,
/// then the `result` will be available to the callback. That way you can
/// differentiate between the dialog being dismissed by an Ok or a Cancel
/// button, for example.
///
/// The [useRootNavigator] argument is used to determine whether to push the
/// dialog to the [Navigator] furthest from or nearest to the given `context`.
/// By default, `useRootNavigator` is `true` and the dialog route created by
/// this method is pushed to the root navigator.
///
/// If the application has multiple [Navigator] objects, it may be necessary to
/// call `Navigator.of(context, rootNavigator: true).pop(result)` to close the
/// dialog rather than just `Navigator.pop(context, result)`.
///
/// Returns a [Future] that resolves to the value (if any) that was passed to
/// [Navigator.pop] when the dialog was closed.
///
/// ### State Restoration in Dialogs
///
/// Using this method will not enable state restoration for the dialog. In order
/// to enable state restoration for a dialog, use [Navigator.restorablePush]
/// or [Navigator.restorablePushNamed] with [CupertinoDialogRoute].
///
/// For more information about state restoration, see [RestorationManager].
///
/// {@tool sample --template=stateless_widget_restoration_cupertino}
///
/// This sample demonstrates how to create a restorable Cupertino dialog. This is
/// accomplished by enabling state restoration by specifying
/// [CupertinoApp.restorationScopeId] and using [Navigator.restorablePush] to
/// push [CupertinoDialogRoute] when the [CupertinoButton] is tapped.
///
/// {@macro flutter.widgets.RestorationManager}
///
/// ```dart
/// Widget build(BuildContext context) {
///   return CupertinoPageScaffold(
///     navigationBar: const CupertinoNavigationBar(
///       middle: Text('Home'),
///     ),
///     child: Center(child: CupertinoButton(
///       onPressed: () {
///         Navigator.of(context).restorablePush(_dialogBuilder);
///       },
///       child: const Text('Open Dialog'),
///     )),
///   );
/// }
///
/// static Route<Object?> _dialogBuilder(BuildContext context, Object? arguments) {
///   return CupertinoDialogRoute<void>(
///     context: context,
///     builder: (BuildContext context) {
///       return const CupertinoAlertDialog(
///         title: Text('Title'),
///         content: Text('Content'),
///         actions: <Widget>[
///           CupertinoDialogAction(child: Text('Yes')),
///           CupertinoDialogAction(child: Text('No')),
///         ],
///       );
///     },
///   );
/// }
/// ```
///
/// {@end-tool}
///
/// See also:
///
///  * [CupertinoAlertDialog], an iOS-style alert dialog.
///  * [showDialog], which displays a Material-style dialog.
///  * [showGeneralDialog], which allows for customization of the dialog popup.
///  * <https://developer.apple.com/ios/human-interface-guidelines/views/alerts/>
Future<T?> showCupertinoDialogSuper<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor = Colors.black54,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  void Function(T?)? onDismissed,
}) async {
  T? result = await showCupertinoDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
  );

  if (onDismissed != null) onDismissed(result);

  return result;
}

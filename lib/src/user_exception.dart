import 'dart:ui';

import 'package:async_redux/async_redux.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

// /////////////////////////////////////////////////////////////////////////////

/// Represents an error the user could fix, like wrong typed text, or missing
/// internet connection. Methods [dialogTitle] and [dialogContent] return
/// [String]s you can show in an error dialog.
///
/// An [UserException] may have an optional [cause], which is a more specific
/// root cause of the error.
///
/// If the error has a "cause" which is another [UserException] or [String],
/// the dialog-title will be the present exception's [msg], and the
/// dialog-content will be the [cause]. Otherwise, the dialog-title will be
/// an empty string, and the dialog-title will be the present
/// exception's [msg].
///
/// In other words, If the [cause] is an [UserException] or [String], it may
/// be used in the dialog. But if the [cause] is of a different type it's
/// considered just internal information, and won't be shown to the user.
///
/// An [UserException] may also have an optional [code], of type
/// [ExceptionCode]. If there is a non-null [code], the String returned by
/// [ExceptionCode.asText] may be used instead of the [msg]. This facilitates
/// translating error messages, since [ExceptionCode.asText] accepts
/// a [Locale].
///
/// You can define a special Matcher for your UserException, to use in your
/// tests. Create a test lib with this code:
///
/// ```
/// import 'package:matcher/matcher.dart';
/// const Matcher throwsUserException
///    = Throws(const TypeMatcher<UserException>());
/// ```
///
/// Then use it in your tests:
///
/// ```
/// expect(() => someFunction(), throwsUserException);
/// ```
///
class UserException implements Exception {
  /// Some message shown to the user.
  final String? msg;

  /// The cause of the user-exception. Usually another error.
  final Object? cause;

  /// The error may have some code. This may be used for error message
  /// translations, and also to simplify receiving errors from web-services,
  /// cloud-functions etc.
  final ExceptionCode? code;

  const UserException(this.msg, {this.cause, this.code});

  /// Adding `.debug` to the constructor will print the exception to the console.
  /// Use this for debugging purposes only.
  /// This constructor is marked as deprecated so that you don't forget to remove it.
  @deprecated
  UserException.debug(this.msg, {this.cause, this.code}) {
    print("================================================================\n"
        "UserException${code == null ? "" : " (code: $code)"}:\n"
        "Msg = $msg,\n"
        "${cause == null ? "" : "Cause = $cause,\n"}"
        "================================================================");
  }

  /// Returns the first cause which, recursively, is NOT a UserException.
  /// If not found, returns null.
  Object? hardCause() {
    if (cause is UserException)
      return (cause as UserException).hardCause();
    else
      return cause;
  }

  /// Returns a deep copy of this exception, but stopping at, and not
  /// including, the first [cause] which is not a UserException.
  UserException withoutHardCause() => UserException(
        msg,
        cause: (cause is UserException)
            ? //
            (cause as UserException).withoutHardCause()
            : null,
        code: code,
      );

  String? dialogTitle([Locale? locale]) => //
      (cause is UserException || cause is String)
          ? //
          _codeAsTextOrMsg(locale)
          : "";

  String? dialogContent([Locale? locale]) {
    if (cause is UserException)
      return (cause as UserException)._dialogTitleAndContent(locale);
    else if (cause is String)
      return cause as String?;
    else
      return _codeAsTextOrMsg(locale);
  }

  String? _dialogTitleAndContent([Locale? locale]) => (cause is UserException)
      ? joinExceptionMainAndCause(
          locale,
          _codeAsTextOrMsg(locale),
          (cause as UserException)._codeAsTextOrMsg(locale),
        )
      : _codeAsTextOrMsg(locale);

  /// Return the string that join the main message and the reason message.
  /// You can change this variable to inject another way to join them.
  static var joinExceptionMainAndCause = (
    Locale? locale,
    String? mainMsg,
    String? causeMsg,
  ) =>
      "$mainMsg\n\n${_getReasonFromLocale(locale) ?? "Reason"}: $causeMsg";

  static String? _getReasonFromLocale(Locale? locale) {
    if (locale == null)
      return null;
    else {
      var reason = _reason[locale.toString()];
      reason ??= _reason[locale.languageCode];
      return reason;
    }
  }

  static const Map<String, String> _reason = {
    "en": "Reason", // English
    "es": "Razón", // Spanish
    "fr": "Raison", // French
    "de": "Grund", // German
    "zh": "原因", // Chinese
    "jp": "理由", // Japanese
    "pt": "Motivo", // Portuguese
    "it": "Motivo", // Italian
    "pl": "Powód", // Polish
    "ko": "이유", // Korean
    "ms": "Sebab", // Malay
    "ru": "Причина", // Russian
    "uk": "Причина", // Ukrainian
    "ar": "السبب", // Arabic
    "he": "סיבה", // Hebrew
  };

  /// If there is a [code], and this [code] has a non-empty text returned by
  /// [ExceptionCode.asText] in the given [Locale], return this text.
  /// Otherwise, if the [msg] is a non-empty text, return this [msg].
  /// Otherwise, if there is a [code], return the [code] itself.
  /// Otherwise, return an empty text.
  String? _codeAsTextOrMsg(Locale? locale) {
    String? codeAsText = code?.asText(locale);
    if (codeAsText != null && codeAsText.isNotEmpty) return codeAsText;
    if (msg != null && msg!.isNotEmpty) return msg;
    return code?.toString() ?? "";
  }

  @override
  String toString() => _dialogTitleAndContent()!;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserException &&
          runtimeType == other.runtimeType &&
          msg == other.msg &&
          cause == other.cause &&
          code == other.code;

  @override
  int get hashCode => msg.hashCode ^ cause.hashCode ^ code.hashCode;
}

abstract class ExceptionCode {
  const ExceptionCode();

  String? asText([Locale? locale]);
}

// /////////////////////////////////////////////////////////////////////////////

/// If you want the [UserExceptionDialog] to display some [UserException],
/// you must throw the exception from inside an action's `before` or `reduce`
/// methods.
///
/// However, sometimes you need to create some callback that throws
/// an [UserException]. If this callback is be called outside of an action,
/// the dialog will not display the exception. To solve this, the callback
/// should not throw an exception, but instead call the [UserExceptionAction],
/// which will then simply throw the exception in its `reduce` method.
///
class UserExceptionAction<St> extends ReduxAction<St> {
  final UserException exception;

  UserExceptionAction(
    /// Some message shown to the user.
    String msg, {

    /// The cause of the user-exception. Usually another error.
    Object? cause,

    /// The error may have some code. This may be used for error message
    /// translations, and also to simplify receiving errors from web-services,
    /// cloud-functions etc.
    ExceptionCode? code,
  }) : this.from(UserException(msg, cause: cause, code: code));

  UserExceptionAction.from(this.exception);

  @override
  Future<St> reduce() async => throw exception;
}

// /////////////////////////////////////////////////////////////////////////////

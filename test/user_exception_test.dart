import 'dart:ui';

import 'package:async_redux/async_redux.dart';
import "package:test/test.dart";

class UserExceptionCode extends ExceptionCode {
  final String id, pt, en;

  const UserExceptionCode._(
    this.id, {
    this.en,
    this.pt,
  });

  static const errorInName = UserExceptionCode._(
    "errorInName",
    en: "Please, type a valid name",
    pt: "Por favor, digite um nome válido",
  );

  static const tryAgain = UserExceptionCode._(
    "tryAgain",
    en: "Try again",
    pt: "Tente novamente",
  );

  static const noInternetConnection = UserExceptionCode._(
    "noInternetConnection",
    en: "There is no internet connection",
    pt: "Não há conexão com a internet",
  );

  static const unknownError = UserExceptionCode._("unknownError");

  @override
  String toString() => id;

  @override
  String asText([Locale locale]) {
    if (locale.toString() == "en_US")
      return en;
    else if (locale.toString() == "pt_BR")
      return pt;
    else
      return null;
  }
}

void main() {
  var localeEn = Locale('en', 'US');
  var localePt = Locale('pt', 'BR');

  ///////////////////////////////////////////////////////////////////////////////
  test('Get title and content from UserException.', () {
    // UserException with no given cause.
    var exception = UserException("Some msg");
    expect(exception.dialogTitle(), "");
    expect(exception.dialogContent(), "Some msg");
    expect(exception.toString(), "Some msg");

    // UserException with cause, and the cause is also an UserException.
    exception = UserException("Some msg", cause: UserException("Other msg"));
    expect(exception.dialogTitle(), "Some msg");
    expect(exception.dialogContent(), "Other msg");
    expect(exception.toString(), "Some msg\n\nReason: Other msg");

    // UserException with cause, and the cause is NOT an UserException.
    exception = UserException("Some msg", cause: StoreException("Other msg"));
    expect(exception.dialogTitle(), "");
    expect(exception.dialogContent(), "Some msg");
    expect(exception.toString(), "Some msg");
    // UserException with no given cause.

    // ---

    // Nothing changes with Locale, since there is no code.
    exception = UserException("Some msg");
    expect(exception.dialogTitle(localePt), "");
    expect(exception.dialogContent(localePt), "Some msg");

    // UserException with cause, and the cause is also an UserException.
    exception = UserException("Some msg", cause: UserException("Other msg"));
    expect(exception.dialogTitle(localePt), "Some msg");
    expect(exception.dialogContent(localePt), "Other msg");

    // UserException with cause, and the cause is NOT an UserException.
    exception = UserException("Some msg", cause: StoreException("Other msg"));
    expect(exception.dialogTitle(localePt), "");
    expect(exception.dialogContent(localePt), "Some msg");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('Get title and content from UserException with code, but no Locale.', () {
    // UserException with no given cause.
    var exception = UserException(
      "Some msg",
      code: UserExceptionCode.errorInName,
    );
    expect(exception.dialogTitle(), "");
    expect(exception.dialogContent(), "Some msg");
    expect(exception.toString(), "Some msg");

    // UserException with cause, and the cause is also an UserException.
    exception = UserException(
      "Some msg",
      code: UserExceptionCode.errorInName,
      cause: UserException("Other msg"),
    );
    expect(exception.dialogTitle(), "Some msg");
    expect(exception.dialogContent(), "Other msg");
    expect(exception.toString(), "Some msg\n\nReason: Other msg");

    // UserException with cause, and the cause is NOT an UserException.
    exception = UserException(
      "Some msg",
      code: UserExceptionCode.errorInName,
      cause: StoreException("Other msg"),
    );
    expect(exception.dialogTitle(), "");
    expect(exception.dialogContent(), "Some msg");
    expect(exception.toString(), "Some msg");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('Get title and content from UserException with code and Locale.', () {
    // UserException with no given cause.
    var exception = UserException(
      "Some msg",
      code: UserExceptionCode.errorInName,
    );
    expect(exception.dialogTitle(localeEn), "");
    expect(exception.dialogTitle(localePt), "");
    expect(exception.dialogContent(localeEn), "Please, type a valid name");
    expect(exception.dialogContent(localePt), "Por favor, digite um nome válido");
    expect(exception.toString(), "Some msg");

    // UserException with cause, and the cause is also an UserException.
    exception = UserException(
      "Some msg",
      code: UserExceptionCode.errorInName,
      cause: UserException("Other msg"),
    );
    expect(exception.dialogTitle(localeEn), "Please, type a valid name");
    expect(exception.dialogTitle(localePt), "Por favor, digite um nome válido");
    expect(exception.dialogContent(localeEn), "Other msg");
    expect(exception.dialogContent(localePt), "Other msg");
    expect(exception.toString(), "Some msg\n\nReason: Other msg");

    // UserException with cause, and the cause is NOT an UserException.
    exception = UserException(
      "Some msg",
      code: UserExceptionCode.errorInName,
      cause: StoreException("Other msg"),
    );
    expect(exception.dialogTitle(localeEn), "");
    expect(exception.dialogTitle(localePt), "");
    expect(exception.dialogContent(localeEn), "Please, type a valid name");
    expect(exception.dialogContent(localePt), "Por favor, digite um nome válido");
    expect(exception.toString(), "Some msg");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('Get title and content from UserException with code, Locale, and cause with code.', () {
    // UserException with cause, and the cause is also an UserException.
    var exception = UserException(
      "Some msg",
      code: UserExceptionCode.errorInName,
      cause: UserException("Other msg", code: UserExceptionCode.tryAgain),
    );
    expect(exception.dialogTitle(localeEn), "Please, type a valid name");
    expect(exception.dialogTitle(localePt), "Por favor, digite um nome válido");
    expect(exception.dialogContent(localeEn), "Try again");
    expect(exception.dialogContent(localePt), "Tente novamente");
    expect(exception.toString(), "Some msg\n\nReason: Other msg");

    // ---

    // UserException with cause,
    // and the cause is also an UserException with another cause which is also an UserException.
    exception = UserException(
      "Some msg",
      code: UserExceptionCode.errorInName,
      cause: UserException(
        "Other msg",
        code: UserExceptionCode.tryAgain,
        cause: UserException("Yet another msg", code: UserExceptionCode.noInternetConnection),
      ),
    );
    expect(exception.dialogTitle(localeEn), "Please, type a valid name");
    expect(exception.dialogTitle(localePt), "Por favor, digite um nome válido");
    expect(
        exception.dialogContent(localeEn), "Try again\n\nReason: There is no internet connection");
    expect(exception.dialogContent(localePt),
        "Tente novamente\n\nReason: Não há conexão com a internet");
    expect(exception.toString(), "Some msg\n\nReason: Other msg");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('If there is a code, but no translation, use the message.', () {
    //
    // Regular code with translation: uses the translation.
    var exception = UserException("Some msg", code: UserExceptionCode.errorInName);
    expect(exception.dialogContent(localeEn), "Please, type a valid name");

    // Code with no translation: uses the message.
    exception = UserException("Some msg", code: UserExceptionCode.unknownError);
    expect(exception.dialogContent(localeEn), "Some msg");

    // Code with no translation and no message: uses the code id.
    exception = UserException(null, code: UserExceptionCode.unknownError);
    expect(exception.dialogContent(localeEn), "unknownError");

    // Again, code with no translation and no message: uses the code id.
    exception = UserException("", code: UserExceptionCode.unknownError);
    expect(exception.dialogContent(localeEn), "unknownError");
  });

  ///////////////////////////////////////////////////////////////////////////////
}

import 'dart:ui';

import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

class UserExceptionCode extends ExceptionCode {
  final String? id, pt, en;

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
  String toString() => id!;

  @override
  String? asText([Locale? locale]) {
    if (locale.toString() == "en_US")
      return en;
    else if (locale.toString() == "pt_BR")
      return pt;
    else
      return null;
  }
}

void main() {
  var localeEn = const Locale('en', 'US');
  var localePt = const Locale('pt', 'BR');

  ///////////////////////////////////////////////////////////////////////////////

  test('Get title and content from UserException.', () {
    // UserException with no given cause.
    var exception = const UserException("Some msg");
    expect(exception.dialogTitle(), "");
    expect(exception.dialogContent(), "Some msg");
    expect(exception.toString(), "Some msg");

    // UserException with cause, and the cause is also an UserException.
    exception = const UserException("Some msg", cause: UserException("Other msg"));
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
    exception = const UserException("Some msg");
    expect(exception.dialogTitle(localePt), "");
    expect(exception.dialogContent(localePt), "Some msg");

    // UserException with cause, and the cause is also an UserException.
    exception = const UserException("Some msg", cause: const UserException("Other msg"));
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
    var exception = const UserException(
      "Some msg",
      code: UserExceptionCode.errorInName,
    );
    expect(exception.dialogTitle(), "");
    expect(exception.dialogContent(), "Some msg");
    expect(exception.toString(), "Some msg");

    // UserException with cause, and the cause is also an UserException.
    exception = const UserException(
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
    var exception = const UserException(
      "Some msg",
      code: UserExceptionCode.errorInName,
    );
    expect(exception.dialogTitle(localeEn), "");
    expect(exception.dialogTitle(localePt), "");
    expect(exception.dialogContent(localeEn), "Please, type a valid name");
    expect(exception.dialogContent(localePt), "Por favor, digite um nome válido");
    expect(exception.toString(), "Some msg");

    // UserException with cause, and the cause is also an UserException.
    exception = const UserException(
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
    var exception = const UserException(
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
    exception = const UserException(
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
        "Tente novamente\n\nMotivo: Não há conexão com a internet");
    expect(exception.toString(), "Some msg\n\nReason: Other msg");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('If there is a code, but no translation, use the message.', () {
    //
    // Regular code with translation: uses the translation.
    var exception = const UserException("Some msg", code: UserExceptionCode.errorInName);
    expect(exception.dialogContent(localeEn), "Please, type a valid name");

    // Code with no translation: uses the message.
    exception = const UserException("Some msg", code: UserExceptionCode.unknownError);
    expect(exception.dialogContent(localeEn), "Some msg");

    // Code with no translation and no message: uses the code id.
    exception = const UserException(null, code: UserExceptionCode.unknownError);
    expect(exception.dialogContent(localeEn), "unknownError");

    // Again, code with no translation and no message: uses the code id.
    exception = const UserException("", code: UserExceptionCode.unknownError);
    expect(exception.dialogContent(localeEn), "unknownError");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('Message with a reason gets translated to the current locale.', () {
    //
    var exception = const UserException(
      "This is a message",
      cause: UserException(
        "This is a cause",
        cause: UserException("Another cause"),
      ),
    );

    // Locale "en_US".
    expect(exception.dialogTitle(localeEn), "This is a message");
    expect(exception.dialogContent(localeEn), "This is a cause\n\nReason: Another cause");

    // Locale "pt_BR".
    expect(exception.dialogTitle(localePt), "This is a message");
    expect(exception.dialogContent(localePt), "This is a cause\n\nMotivo: Another cause");

    // Locale "en" (language only).
    expect(exception.dialogTitle(const Locale('en')), "This is a message");
    expect(exception.dialogContent(const Locale('en')), "This is a cause\n\nReason: Another cause");

    // Locale "pt" (language only).
    expect(exception.dialogTitle(const Locale('pt')), "This is a message");
    expect(exception.dialogContent(const Locale('pt')), "This is a cause\n\nMotivo: Another cause");

    // Unknown locale.
    expect(exception.dialogTitle(const Locale('unkwnow')), "This is a message");
    expect(exception.dialogContent(const Locale('unkwnow')),
        "This is a cause\n\nReason: Another cause");

    // ---

    UserException.joinExceptionMainAndCause =
        (Locale? locale, String? mainMsg, String? causeMsg) => "xyz $locale $mainMsg $causeMsg";

    // Locale "en_US".
    expect(exception.dialogTitle(localeEn), "This is a message");
    expect(exception.dialogContent(localeEn), "xyz en_US This is a cause Another cause");

    // Locale "en_US".
    expect(exception.dialogTitle(const Locale('unknown')), "This is a message");
    expect(exception.dialogContent(const Locale('unknown')),
        "xyz unknown This is a cause Another cause");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('UserException.pure() removes cause which is not UserException', () {
    //
    // No cause.
    const exception1 = UserException(
      "msg1",
      code: UserExceptionCode.errorInName,
    );
    expect(exception1.withoutHardCause(), exception1);

    // All causes are UserExceptions.
    const exception2 = UserException(
      "msg2",
      cause: exception1,
      code: UserExceptionCode.errorInName,
    );
    expect(exception2.withoutHardCause(), exception2);

    // Some cause is not UserExceptions, so it's cut.
    var exception3 = UserException(
      "msg1",
      cause: AssertionError(),
      code: UserExceptionCode.errorInName,
    );
    expect(exception3, isNot(exception1));
    expect(exception3.withoutHardCause(), isNot(exception3));
    expect(exception3.withoutHardCause(), exception1);

    // Some cause is not UserExceptions, so it's cut.
    var exception4 = UserException(
      "msg2",
      cause: UserException("msg1", cause: AssertionError(), code: UserExceptionCode.errorInName),
      code: UserExceptionCode.errorInName,
    );
    expect(exception4, isNot(exception1));
    expect(exception4, isNot(exception2));
    expect(exception4.withoutHardCause(), exception2);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'UserException.hardCause() Returns the first cause which, '
      'recursively, is NOT a UserException', () {
    //
    // No cause.
    const exception1 = UserException("msg1");
    expect(exception1.hardCause(), null);

    // All causes are UserExceptions.
    const exception2 = const UserException("msg2", cause: exception1);
    expect(exception2.hardCause(), null);

    // Some cause is not UserException.
    var cause = AssertionError();
    var exception3 = UserException("msg1", cause: cause);
    expect(exception3.hardCause(), cause);

    // Some cause is not UserException.
    var exception4 = UserException("msg2", cause: UserException("msg1", cause: cause));
    expect(exception4.hardCause(), cause);
  });

  ///////////////////////////////////////////////////////////////////////////////
}

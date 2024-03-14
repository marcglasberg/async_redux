import 'package:async_redux/async_redux.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'Get title and content from UserException. '
      'Note: This is already tested in async_redux_core, so no need to do much here.', () {
    //
    // UserException with no given cause.
    var exception = const UserException('Some msg');
    var (title, content) = exception.titleAndContent();
    expect(title, '');
    expect(content, 'Some msg');
    expect(exception.toString(), 'UserException{Some msg}');

    // UserException with cause, and the cause is also an UserException.
    exception = const UserException('Some msg', reason: 'Other msg');
    (title, content) = exception.titleAndContent();
    expect(title, 'Some msg');
    expect(content, 'Other msg');
    expect(exception.toString(), 'UserException{Some msg|Reason: Other msg}');

    // UserException with cause, and the cause is NOT an UserException.
    exception = const UserException('Some msg', reason: 'Other msg');
    (title, content) = exception.titleAndContent();
    expect(title, 'Some msg');
    expect(content, 'Other msg');
    expect(exception.toString(), 'UserException{Some msg|Reason: Other msg}');
  });

  test('Adding callbacks', () {
    //
    String result = '';
    var exception = const UserException('Some msg') //
        .addCallbacks(onOk: () => result += 'a', onCancel: () => result += 'b');

    expect(exception.onOk, isNotNull);
    expect(exception.onCancel, isNotNull);

    expect(result, '');
    exception.onOk?.call();
    expect(result, 'a');
    exception.onCancel?.call();
    expect(result, 'ab');
  });

  test('Adding properties', () {
    //
    var exception = const UserException('Some msg').addProps({'1': 'a', '2': 'b'});

    expect(exception.reason, isNull);
    expect(exception.hardCause, isNull);
    expect(exception.onOk, isNull);
    expect(exception.onCancel, isNull);
    expect(exception.props, {'1': 'a', '2': 'b'}.lock);

    exception = exception.addProps({'2': 'c', '3': 'd'});
    expect(exception.props, {'1': 'a', '2': 'c', '3': 'd'}.lock);

    exception = exception.addProps(null);
    exception = exception.addProps({});
    expect(exception.props, {'1': 'a', '2': 'c', '3': 'd'}.lock);
  });

  test('Adding hard cause', () {
    //
    // 1) The cause is not null, String, or UserException.
    var exception = const UserException('Some msg') //
        .addCause(const FormatException('Some other msg'));

    expect(exception.reason, isNull);
    expect(exception.hardCause, isA<FormatException>());
    expect(exception.onOk, isNull);
    expect(exception.onCancel, isNull);
    expect(exception.props, isEmpty);

    // 2) Another hard cause will replace a previous one.
    exception = exception.addCause(UnsupportedError('Yet another'));

    expect(exception.reason, isNull);
    expect(exception.hardCause, isA<UnsupportedError>());
    expect(exception.onOk, isNull);
    expect(exception.onCancel, isNull);
    expect(exception.props, isEmpty);

    // 3)  string will add to the reason.
    exception = exception.addCause('Some text');

    expect(exception.reason, 'Some text');
    expect(exception.hardCause, isA<UnsupportedError>());
    expect(exception.onOk, isNull);
    expect(exception.onCancel, isNull);
    expect(exception.props, isEmpty);

    // 4) A string will add to (not replace) the reason.
    exception = exception.addCause('Yet another text');

    expect(exception.reason, 'Some text\n\nReason: Yet another text');
    expect(exception.hardCause, isA<UnsupportedError>());
    expect(exception.onOk, isNull);
    expect(exception.onCancel, isNull);
    expect(exception.props, isEmpty);

    // 5) A UserException will add to (not replace) the reason.
    exception = exception.addCause(const UserException('My exception'));

    expect(exception.reason, 'Some text\n\nReason: Yet another text\n\nReason: My exception');
    expect(exception.hardCause, isA<UnsupportedError>());
    expect(exception.onOk, isNull);
    expect(exception.onCancel, isNull);
    expect(exception.props, isEmpty);

    // 6) A UserException with a reason will add to (not replace) the reason.
    exception = exception.addCause(const UserException('Another exception', reason: 'My reason'));

    expect(
        exception.reason,
        'Some text\n\nReason: Yet another text\n\nReason: My exception\n\n'
        'Reason: Another exception\n\nReason: My reason');
    expect(exception.hardCause, isA<UnsupportedError>());
    expect(exception.onOk, isNull);
    expect(exception.onCancel, isNull);
    expect(exception.props, isEmpty);

    // 6) Adding null as a cause doesn't change anything.
    exception = exception.addCause(null);

    expect(
        exception.reason,
        'Some text\n\nReason: Yet another text\n\nReason: My exception\n\n'
        'Reason: Another exception\n\nReason: My reason');
    expect(exception.hardCause, isA<UnsupportedError>());
    expect(exception.onOk, isNull);
    expect(exception.onCancel, isNull);
    expect(exception.props, isEmpty);
  });
}

import 'package:async_redux_lints/src/rules/timer_or_stream_not_in_props_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(TimerOrStreamNotInPropsTest);
  });
}

@reflectiveTest
class TimerOrStreamNotInPropsTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = TimerOrStreamNotInPropsRule();
    super.setUp();
  }

  Future<void> test_discardedTimer() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    Timer(Duration(seconds: 1), () {});
    return null;
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Timer(Duration(seconds: 1), () {})',
        messageContainsAll: ["The 'Timer' isn't stored in the store props."],
        correctionContains: "'setProp(key, value)'",
      ),
    ]);
  }

  Future<void> test_fieldInitializer() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  final timer = Timer(Duration(seconds: 1), () {});

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Timer(Duration(seconds: 1), () {})')]);
  }

  Future<void> test_discardedSubscription() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  final Stream<int> stream;
  A(this.stream);

  @override
  AppState? reduce() {
    stream.listen((_) {});
    return null;
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'stream.listen((_) {})',
        messageContainsAll: ["The 'StreamSubscription' isn't stored"],
      ),
    ]);
  }

  Future<void> test_streamSubtype() async {
    var code = '''$header
abstract class MyStream extends Stream<int> {}

class A extends ReduxAction<AppState> {
  final MyStream stream;
  A(this.stream);

  @override
  AppState? reduce() {
    stream.listen((_) {});
    return null;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'stream.listen((_) {})')]);
  }

  Future<void> test_cascade() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  final Stream<int> stream;
  A(this.stream);

  @override
  AppState? reduce() {
    stream.listen((_) {})..onError((_) {});
    return null;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'stream.listen((_) {})')]);
  }

  Future<void> test_inClosure() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    Future(() {
      Timer(Duration(seconds: 1), () {});
    });
    return null;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Timer(Duration(seconds: 1), () {})')]);
  }

  Future<void> test_inMixin() async {
    var code = '''$header
mixin M on ReduxAction<AppState> {
  void start() {
    Timer(Duration(seconds: 1), () {});
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Timer(Duration(seconds: 1), () {})')]);
  }

  Future<void> test_localVariableNotKept() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    var timer = Timer(Duration(seconds: 1), () {});
    print(timer.hashCode);
    return null;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Timer(Duration(seconds: 1), () {})')]);
  }

  Future<void> test_localVariableAssignedLater() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    Timer timer;
    timer = Timer(Duration(seconds: 1), () {});
    print(timer.hashCode);
    return null;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Timer(Duration(seconds: 1), () {})')]);
  }

  Future<void> test_fieldNotKept() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  Timer? _timer;

  @override
  AppState? reduce() {
    _timer = Timer(Duration(seconds: 1), () {});
    print(_timer?.hashCode);
    return null;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Timer(Duration(seconds: 1), () {})')]);
  }

  Future<void> test_setProp_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  final Stream<int> stream;
  A(this.stream);

  @override
  AppState? reduce() {
    setProp('timer', Timer(Duration(seconds: 1), () {}));
    setProp('subscription', stream.listen((_) {}));
    store.setProp('other', (Timer(Duration(seconds: 1), () {})));
    return null;
  }
}
''');
  }

  Future<void> test_localVariablePassedToSetProp_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  final Stream<int> stream;
  A(this.stream);

  @override
  AppState? reduce() {
    var timer = Timer(Duration(seconds: 1), () {});
    final subscription = stream.listen((_) {});
    setProp('timer', timer);
    setProp('subscription', subscription);
    return null;
  }
}
''');
  }

  Future<void> test_localVariableCancelled_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  final Stream<int> stream;
  A(this.stream);

  @override
  Future<AppState?> reduce() async {
    var subscription = stream.listen((_) {});
    try {
      await Future.value(1);
    } finally {
      await subscription.cancel();
    }
    return null;
  }
}
''');
  }

  Future<void> test_fieldCancelledInAnotherMethod_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  final Stream<int> stream;
  StreamSubscription<int>? _subscription;
  A(this.stream);

  @override
  AppState? reduce() {
    _subscription = stream.listen((_) {});
    return null;
  }

  @override
  void after() {
    this._subscription!.cancel();
  }
}
''');
  }

  Future<void> test_staticFieldCancelled_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  static StreamSubscription<int>? subscription;
  final Stream<int> stream;
  A(this.stream);

  @override
  AppState? reduce() {
    A.subscription?.cancel();
    subscription = stream.listen((_) {});
    return null;
  }
}
''');
  }

  Future<void> test_returnedOrPassedOn_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  final Stream<int> stream;
  final List<StreamSubscription<int>> subscriptions;
  A(this.stream, this.subscriptions);

  Timer createTimer() => Timer(Duration(seconds: 1), () {});

  StreamSubscription<int> subscribe() {
    return stream.listen((_) {});
  }

  @override
  Future<AppState?> reduce() async {
    subscriptions.add(stream.listen((_) {}));
    var other = stream.listen((_) {});
    subscriptions.add(other);
    await stream.listen((_) {}).asFuture<void>();
    return null;
  }
}
''');
  }

  Future<void> test_timerRun_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    Timer.run(() {});
    return null;
  }
}
''');
  }

  Future<void> test_outsideAction_isValid() async {
    await assertNoDiagnostics('''$header
class Service {
  void start(Stream<int> stream) {
    Timer(Duration(seconds: 1), () {});
    stream.listen((_) {});
  }
}
''');
  }
}

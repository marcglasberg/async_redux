import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';

/// A stub of the parts of package `equatable` that the rules look at.
const equatableStub = r'''
abstract class Equatable {
  const Equatable();

  List<Object?> get props;

  @override
  bool operator ==(Object other) => other is Equatable && props == other.props;

  @override
  int get hashCode => props.hashCode;
}

mixin EquatableMixin {
  List<Object?> get props;

  @override
  bool operator ==(Object other) => other is EquatableMixin && props == other.props;

  @override
  int get hashCode => props.hashCode;
}
''';

/// Adds package `equatable` to the test. Call it before `super.setUp()`.
void addEquatablePackage(AnalysisRuleTest test) =>
    test.newPackage('equatable').addFile('lib/equatable.dart', equatableStub);

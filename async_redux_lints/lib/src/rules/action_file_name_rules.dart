import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../names.dart';
import '../package_files.dart';
import '../redux_types.dart';

/// The ways to name the files that declare actions. Each one has its own opt-in rule,
/// since plugin rules can't be configured.
enum ActionFileNameStyle {
  /// `load_user_action.dart`.
  endsWithAction,

  /// `ACTION_load_user.dart`.
  startsWithAction;

  /// Returns true if the file [name], without `.dart`, follows this style.
  bool matches(String name) => switch (this) {
    endsWithAction => name.endsWith('_action'),
    startsWithAction => name.startsWith('ACTION_'),
  };

  /// Returns the name, with `.dart`, that a file currently named [fileName], without
  /// `.dart`, should have in this style. If the file declares a single action named
  /// [actionName], the name is based on it. Otherwise, it's based on the current name.
  String suggestedName(String fileName, String? actionName) {
    var base = (actionName == null) ? '' : _snakeCase(_withoutActionWord(actionName));
    if (base.isEmpty) base = _withoutActionsPrefixOrSuffix(fileName);
    return switch (this) {
      endsWithAction => '${base}_action.dart',
      startsWithAction => 'ACTION_$base.dart',
    };
  }

  /// Returns the file [name] without `ACTION_` or `ACTIONS_` at its start, and
  /// without `_action` or `_actions` at its end.
  static String _withoutActionsPrefixOrSuffix(String name) {
    if (name.startsWith('ACTIONS_')) {
      name = name.substring('ACTIONS_'.length);
    } else if (name.startsWith('ACTION_')) {
      name = name.substring('ACTION_'.length);
    }
    if (name.endsWith('_actions')) {
      name = name.substring(0, name.length - '_actions'.length);
    } else if (name.endsWith('_action')) {
      name = name.substring(0, name.length - '_action'.length);
    }
    return name;
  }

  /// Returns [name] without the word `Action` at its end, and the underscores before
  /// it. For example, `LoadUser` for `LoadUserAction` or `LoadUser_Action`.
  static String _withoutActionWord(String name) {
    if (!name.endsWith('Action')) return name;
    return withoutTrailingUnderscores(name.substring(0, name.length - 'Action'.length));
  }

  /// Returns [name] in snake case. For example, `load_user` for `LoadUser`, and
  /// `http_request` for `HTTPRequest`.
  ///
  /// An underscore is added before an uppercase letter that follows a lowercase letter
  /// or a digit, and before an uppercase letter that follows another one and comes
  /// before a lowercase letter. Repeated underscores become one, and the underscores
  /// at the start and at the end are removed.
  static String _snakeCase(String name) {
    var buffer = StringBuffer();
    // True at the start, so that leading underscores are removed.
    var lastIsUnderscore = true;
    for (var i = 0; i < name.length; i++) {
      var codeUnit = name.codeUnitAt(i);
      if (codeUnit == _underscore) {
        if (!lastIsUnderscore) buffer.writeCharCode(_underscore);
        lastIsUnderscore = true;
        continue;
      }
      if (i > 0 && !lastIsUnderscore && isUppercase(codeUnit)) {
        var previous = name.codeUnitAt(i - 1);
        var next = (i + 1 < name.length) ? name.codeUnitAt(i + 1) : 0;
        if (isLowercase(previous) ||
            isDigit(previous) ||
            (isUppercase(previous) && isLowercase(next))) {
          buffer.writeCharCode(_underscore);
        }
      }
      buffer.writeCharCode(codeUnit);
      lastIsUnderscore = false;
    }
    return withoutTrailingUnderscores(buffer.toString().toLowerCase());
  }

  static const _underscore = 0x5F;
}

/// Opt-in rule for the `load_user_action.dart` file naming style.
class ActionFileNameEndsWithActionRule extends _ActionFileNameRule {
  static const LintCode code = LintCode(
    'action_file_name_ends_with_action',
    "The file '{0}' declares actions, so its name should end with '_action'.",
    correctionMessage: "Try renaming the file to '{1}'.",
    severity: DiagnosticSeverity.WARNING,
  );

  ActionFileNameEndsWithActionRule()
    : super(
        ActionFileNameStyle.endsWithAction,
        name: 'action_file_name_ends_with_action',
        description:
            "The names of files with actions should end with '_action', like "
            "'load_user_action.dart'.",
      );

  @override
  LintCode get diagnosticCode => code;
}

/// Opt-in rule for the `ACTION_load_user.dart` file naming style.
class ActionFileNameStartsWithActionRule extends _ActionFileNameRule {
  static const LintCode code = LintCode(
    'action_file_name_starts_with_action',
    "The file '{0}' declares actions, so its name should start with 'ACTION_'.",
    correctionMessage: "Try renaming the file to '{1}'.",
    severity: DiagnosticSeverity.WARNING,
  );

  ActionFileNameStartsWithActionRule()
    : super(
        ActionFileNameStyle.startsWithAction,
        name: 'action_file_name_starts_with_action',
        description:
            "The names of files with actions should start with 'ACTION_', like "
            "'ACTION_load_user.dart'.",
      );

  @override
  LintCode get diagnosticCode => code;
}

/// Reports a file that declares concrete actions, when its name doesn't follow the
/// [style]. The diagnostic is shown on the name of the first action of the file.
///
/// Files in the test directory, and files whose names end with `_test`, are not
/// checked, since test files must be named after what they test.
abstract class _ActionFileNameRule extends AnalysisRule {
  final ActionFileNameStyle style;

  _ActionFileNameRule(this.style, {required super.name, required super.description});

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addCompilationUnit(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final _ActionFileNameRule rule;
  final RuleContext context;

  _Visitor(this.rule, this.context);

  @override
  void visitCompilationUnit(CompilationUnit node) {
    var file = context.currentUnit?.file;
    if (file == null) return;
    if (isInTestDirectory(context.package, file)) return;

    var fileName = file.shortName;
    if (!fileName.endsWith('.dart')) return;
    fileName = fileName.substring(0, fileName.length - '.dart'.length);
    if (fileName.endsWith('_test') || rule.style.matches(fileName)) return;

    var actionNames = <Token>[
      for (var declaration in node.declarations)
        if (declaration case ClassDeclaration(
          :var declaredFragment,
          :var namePart,
        ) when isConcreteAction(declaredFragment?.element))
          namePart.typeName
        else if (declaration case ClassTypeAlias(
          :var declaredFragment,
          :var name,
        ) when isConcreteAction(declaredFragment?.element))
          name,
    ];
    if (actionNames.isEmpty) return;

    var suggestion = rule.style.suggestedName(
      fileName,
      (actionNames.length == 1) ? actionNames.single.lexeme : null,
    );
    rule.reportAtToken(actionNames.first, arguments: ['$fileName.dart', suggestion]);
  }
}

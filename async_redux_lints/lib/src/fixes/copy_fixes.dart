import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import '../rules/copy_missing_field_rule.dart';
import '../state_class_utils.dart';
import 'insertions.dart';

/// Adds the missing fields to the copy method. For each field, adds a nullable
/// parameter, like `int? counter`, if the method doesn't have it, and passes
/// `counter: counter ?? this.counter` to the constructor that the method calls.
///
/// Never changes existing code. A field is only added if the constructor call has no
/// argument for it, and the constructor has a named parameter for it. Otherwise, for
/// example with `counter: 0` or `counter: this.counter`, the field is left for the
/// user to fix, and the warning stays. The fix is not offered if no field can be
/// added.
class AddMissingFieldsToCopy extends ResolvedCorrectionProducer with Insertions {
  static const _kind = FixKind(
    'async_redux_lints.fix.addMissingFieldsToCopy',
    DartFixKindPriority.standard,
    '{0}',
  );

  String _message = '';

  AddMissingFieldsToCopy({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_message];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var method = node.thisOrAncestorOfType<MethodDeclaration>();
    var classDeclaration = node.thisOrAncestorOfType<ClassDeclaration>();
    if (method == null || classDeclaration == null) return;

    var fields = missingCopyFields(
      classDeclaration,
    ).where((copy) => copy.method == method).firstOrNull?.missingFields;
    if (fields == null) return;

    var creations = <InstanceCreationExpression>[];
    var body = method.body;
    if (body is! EmptyFunctionBody) {
      body.accept(_CreationCollector(fields.first.element.enclosingElement, creations));
      if (creations.isEmpty) return;
    }

    var parameters = method.parameters!;
    var canAddParameters =
        parameters.leftDelimiter == null ||
        parameters.leftDelimiter!.type == TokenType.OPEN_CURLY_BRACKET;
    var addable = [
      for (var field in fields)
        if ((field.unusedParameter != null || canAddParameters) &&
            creations.every((creation) => _canAddArgument(creation, field)))
          field,
    ];
    if (addable.isEmpty) return;

    var insertions = <Insertion>[];
    var newParameters = [
      for (var field in addable)
        if (field.unusedParameter == null) _parameterSource(field),
    ];
    if (newParameters.isNotEmpty) {
      insertions.add(_addParameters(parameters, newParameters));
    }

    for (var creation in creations) {
      var list = creation.argumentList;
      var arguments = list.arguments;
      var newArguments = [
        for (var name in addable.map((field) => field.element.name))
          '$name: $name ?? this.$name',
      ];
      insertions.add(
        arguments.isEmpty
            ? Insertion(list.leftParenthesis.end, newArguments.join(', '))
            : addAfterLast(arguments.last, list.leftParenthesis, newArguments),
      );
    }

    var names = [for (var field in addable) field.declaration.name.lexeme];
    _message = "Add ${joinNames(names)} to '${method.name.lexeme}'";

    await insertAll(builder, insertions);
  }

  /// Returns true if [creation] has no argument for [field], and its constructor has
  /// a named parameter for it.
  bool _canAddArgument(InstanceCreationExpression creation, CopyField field) {
    var constructor = creation.constructorName.element?.baseElement;
    if (constructor == null) return false;
    var parameter = constructor.formalParameters
        .where((parameter) => parameter.name == field.element.name)
        .firstOrNull;
    if (parameter == null || !parameter.isNamed) return false;
    return !creation.argumentList.arguments.any(
      (argument) => argument.correspondingParameter?.baseElement == parameter,
    );
  }

  /// Returns the source of a nullable parameter for [field], like `int? counter`.
  String _parameterSource(CopyField field) {
    var name = field.declaration.name.lexeme;
    var list = field.declaration.parent;
    var typeAnnotation = list is VariableDeclarationList ? list.type : null;
    if (typeAnnotation == null) return name;

    var typeSource = utils.getNodeText(typeAnnotation);
    var type = typeAnnotation.type;
    var isNullable =
        type == null ||
        type is DynamicType ||
        type is VoidType ||
        type.nullabilitySuffix == NullabilitySuffix.question;
    return '$typeSource${isNullable ? '' : '?'} $name';
  }

  /// Adds [parameters] as named parameters to [list], which must not have optional
  /// positional parameters.
  Insertion _addParameters(FormalParameterList list, List<String> parameters) {
    var all = list.parameters;
    var joined = parameters.join(', ');
    if (all.isEmpty) {
      return Insertion(list.leftParenthesis.end, '{$joined}');
    }
    var delimiter = list.leftDelimiter;
    if (delimiter != null) return addAfterLast(all.last, delimiter, parameters);
    var last = all.last;
    var comma = last.endToken.next!;
    return comma.type == TokenType.COMMA
        ? Insertion(comma.end, ' {$joined}')
        : Insertion(last.end, ', {$joined}');
  }
}

/// Collects the calls to the constructors of a class.
class _CreationCollector extends RecursiveAstVisitor<void> {
  final Element classElement;
  final List<InstanceCreationExpression> creations;

  _CreationCollector(this.classElement, this.creations);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    var constructor = node.constructorName.element?.baseElement;
    if (constructor?.enclosingElement == classElement) creations.add(node);
    super.visitInstanceCreationExpression(node);
  }
}

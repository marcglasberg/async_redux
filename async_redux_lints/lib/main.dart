import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/fixes/copy_fixes.dart';
import 'src/fixes/dispatch_sync_fixes.dart';
import 'src/fixes/equality_fixes.dart';
import 'src/fixes/reduce_without_await_fixes.dart';
import 'src/fixes/return_type_fixes.dart';
import 'src/fixes/state_access_fixes.dart';
import 'src/fixes/vm_equals_fixes.dart';
import 'src/fixes/wait_fail_fixes.dart';
import 'src/rules/avoid_context_state_rule.dart';
import 'src/rules/copy_missing_field_rule.dart';
import 'src/rules/dispatch_sync_async_action_rule.dart';
import 'src/rules/mixin_combination_rules.dart';
import 'src/rules/reduce_without_await_rule.dart';
import 'src/rules/return_type_rules.dart';
import 'src/rules/select_in_callback_rule.dart';
import 'src/rules/state_class_equality_rules.dart';
import 'src/rules/state_class_must_be_immutable_rule.dart';
import 'src/rules/vm_field_not_in_equals_rule.dart';
import 'src/rules/wait_fail_rules.dart';

/// The entry point loaded by the Dart analysis server.
final plugin = AsyncReduxLintsPlugin();

class AsyncReduxLintsPlugin extends Plugin {
  @override
  String get name => 'async_redux_lints';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(ReduceReturnTypeRule());
    registry.registerFixForRule(ReduceReturnTypeRule.code, ChangeToSyncReturnType.new);
    registry.registerFixForRule(ReduceReturnTypeRule.code, ChangeToAsyncReturnType.new);

    registry.registerWarningRule(BeforeReturnTypeRule());
    registry.registerFixForRule(BeforeReturnTypeRule.code, ChangeToSyncReturnType.new);
    registry.registerFixForRule(BeforeReturnTypeRule.code, ChangeToAsyncReturnType.new);

    registry.registerWarningRule(WrapReduceReturnTypeRule());
    registry.registerFixForRule(
      WrapReduceReturnTypeRule.code,
      ChangeToAsyncReturnType.new,
    );

    registry.registerWarningRule(ReduceWithoutAwaitRule());
    registry.registerFixForRule(ReduceWithoutAwaitRule.code, AddAwaitMicrotask.new);
    registry.registerFixForRule(ReduceWithoutAwaitRule.code, MakeReduceSync.new);

    registry.registerWarningRule(DispatchSyncAsyncActionRule());
    registry.registerFixForRule(
      DispatchSyncAsyncActionRule.code,
      ReplaceWithDispatch.new,
    );
    registry.registerFixForRule(
      DispatchSyncAsyncActionRule.code,
      ReplaceWithDispatchAndWait.new,
    );

    registry.registerWarningRule(IncompatibleMixinsRule());
    registry.registerWarningRule(PollingWithCaveatMixinRule());

    registry.registerWarningRule(WaitFailInvalidArgumentRule());
    registry.registerFixForRule(WaitFailInvalidArgumentRule.code, UseActionType.new);

    registry.registerWarningRule(WaitFailNeverMatchesRule());
    registry.registerFixForRule(WaitFailNeverMatchesRule.code, UseActionType.new);

    registry.registerWarningRule(AvoidContextStateRule());
    registry.registerFixForRule(AvoidContextStateRule.code, UseContextSelect.new);
    registry.registerFixForRule(AvoidContextStateRule.code, UseContextRead.new);

    registry.registerWarningRule(ContextStateInInitStateRule());
    registry.registerFixForRule(ContextStateInInitStateRule.code, UseContextRead.new);

    registry.registerWarningRule(SelectInCallbackRule());
    registry.registerFixForRule(SelectInCallbackRule.code, ReplaceSelectWithRead.new);

    registry.registerWarningRule(VmFieldNotInEqualsRule());
    registry.registerFixForRule(VmFieldNotInEqualsRule.code, AddFieldToVmEquals.new);
    registry.registerFixForRule(VmFieldNotInEqualsRule.code, AddAllFieldsToVmEquals.new);

    registry.registerWarningRule(CopyMissingFieldRule());
    registry.registerFixForRule(CopyMissingFieldRule.code, AddMissingFieldsToCopy.new);

    registry.registerWarningRule(StateClassMissingEqualityRule());

    registry.registerWarningRule(EqualityMissingFieldRule());
    registry.registerFixForRule(
      EqualityMissingFieldRule.code,
      AddMissingFieldsToEquality.new,
    );

    registry.registerWarningRule(StateClassMustBeImmutableRule());
  }
}

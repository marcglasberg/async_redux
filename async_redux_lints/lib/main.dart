import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/fixes/base_class_fixes.dart';
import 'src/fixes/copy_fixes.dart';
import 'src/fixes/dispatch_context_fixes.dart';
import 'src/fixes/dispatch_sync_fixes.dart';
import 'src/fixes/equality_fixes.dart';
import 'src/fixes/equatable_props_fixes.dart';
import 'src/fixes/error_fixes.dart';
import 'src/fixes/event_fixes.dart';
import 'src/fixes/immutable_collection_fixes.dart';
import 'src/fixes/mixin_fixes.dart';
import 'src/fixes/persistence_fixes.dart';
import 'src/fixes/reduce_without_await_fixes.dart';
import 'src/fixes/reducer_fixes.dart';
import 'src/fixes/rename_action_fixes.dart';
import 'src/fixes/return_type_fixes.dart';
import 'src/fixes/state_access_fixes.dart';
import 'src/fixes/store_setup_fixes.dart';
import 'src/fixes/testing_fixes.dart';
import 'src/fixes/to_string_fixes.dart';
import 'src/fixes/vm_equals_fixes.dart';
import 'src/fixes/wait_fail_fixes.dart';
import 'src/fixes/widget_fixes.dart';
import 'src/rules/action_file_name_rules.dart';
import 'src/rules/action_name_rules.dart';
import 'src/rules/action_without_to_string_rule.dart';
import 'src/rules/after_throws_rule.dart';
import 'src/rules/avoid_context_state_rule.dart';
import 'src/rules/base_action_rules.dart';
import 'src/rules/copy_missing_field_rule.dart';
import 'src/rules/dispatch_context_rules.dart';
import 'src/rules/dispatch_and_wait_unlimited_retries_rule.dart';
import 'src/rules/dispatch_sync_async_action_rule.dart';
import 'src/rules/equatable_props_missing_field_rule.dart';
import 'src/rules/event_rules.dart';
import 'src/rules/global_error_observer_rules.dart';
import 'src/rules/internet_simulation_in_production_rule.dart';
import 'src/rules/missing_key_params_rule.dart';
import 'src/rules/missing_super_in_mixin_override_rule.dart';
import 'src/rules/mixin_combination_rules.dart';
import 'src/rules/persistence_rules.dart';
import 'src/rules/polling_action_restarts_polling_rule.dart';
import 'src/rules/power_feature_rules.dart';
import 'src/rules/prefer_return_null_rule.dart';
import 'src/rules/reduce_without_await_rule.dart';
import 'src/rules/retry_without_non_reentrant_rule.dart';
import 'src/rules/return_type_rules.dart';
import 'src/rules/select_outside_build_rule.dart';
import 'src/rules/sequential_rules.dart';
import 'src/rules/server_push_associated_action_rule.dart';
import 'src/rules/stale_state_after_await_rule.dart';
import 'src/rules/state_class_equality_rules.dart';
import 'src/rules/state_class_must_be_immutable_rule.dart';
import 'src/rules/state_contents_rules.dart';
import 'src/rules/store_setup_rules.dart';
import 'src/rules/testing_rules.dart';
import 'src/rules/timer_or_stream_not_in_props_rule.dart';
import 'src/rules/user_exception_rules.dart';
import 'src/rules/vm_field_not_in_equals_rule.dart';
import 'src/rules/wait_fail_rules.dart';
import 'src/rules/widget_rules.dart';

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

    registry.registerWarningRule(ContextInDisposeRule());

    registry.registerWarningRule(ContextInSelectorRule());
    registry.registerFixForRule(ContextInSelectorRule.code, UseSelectorParameter.new);

    registry.registerWarningRule(SelectOutsideBuildRule());
    registry.registerFixForRule(SelectOutsideBuildRule.code, ReplaceSelectWithRead.new);
    registry.registerFixForRule(SelectOutsideBuildRule.code, UseBuilderContext.new);

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

    registry.registerWarningRule(EqualityMissingInheritedFieldRule());
    registry.registerFixForRule(
      EqualityMissingInheritedFieldRule.code,
      AddInheritedFieldsToEquality.new,
    );

    registry.registerWarningRule(EquatablePropsMissingFieldRule());
    registry.registerFixForRule(
      EquatablePropsMissingFieldRule.code,
      AddMissingFieldsToProps.new,
    );

    registry.registerWarningRule(StateClassMustBeImmutableRule());

    registry.registerLintRule(ActionNameEndsWithActionRule());
    registry.registerFixForRule(
      ActionNameEndsWithActionRule.code,
      ({required context}) =>
          RenameAction(ActionNameStyle.endsWithAction, context: context),
    );

    registry.registerLintRule(ActionNameEndsWithUnderscoreActionRule());
    registry.registerFixForRule(
      ActionNameEndsWithUnderscoreActionRule.code,
      ({required context}) =>
          RenameAction(ActionNameStyle.endsWithUnderscoreAction, context: context),
    );

    registry.registerLintRule(ActionNameWithoutActionRule());
    registry.registerFixForRule(
      ActionNameWithoutActionRule.code,
      ({required context}) =>
          RenameAction(ActionNameStyle.withoutAction, context: context),
    );

    registry.registerLintRule(ActionFileNameEndsWithActionRule());
    registry.registerLintRule(ActionFileNameStartsWithActionRule());

    registry.registerWarningRule(ExtendBaseActionRule());
    registry.registerWarningRule(DependenciesCastInActionRule());
    // One fix for each base action of the package, up to `UseBaseClass.maxFixes`.
    for (var i = 0; i < UseBaseClass.maxFixes; i++) {
      registry.registerFixForRule(
        ExtendBaseActionRule.code,
        ({required context}) => UseBaseClass(i, context: context),
      );
    }

    registry.registerWarningRule(PreferReturnNullRule());
    registry.registerFixForRule(PreferReturnNullRule.code, ReturnNull.new);

    registry.registerWarningRule(StaleStateAfterAwaitRule());
    registry.registerFixForRule(StaleStateAfterAwaitRule.code, UseCurrentState.new);

    registry.registerWarningRule(AfterThrowsRule());
    registry.registerWarningRule(MissingSuperInMixinOverrideRule());

    registry.registerLintRule(AvoidAbortDispatchRule());
    registry.registerLintRule(AvoidWrapReduceRule());

    registry.registerWarningRule(UserExceptionOutsideActionRule());
    registry.registerFixForRule(
      UserExceptionOutsideActionRule.code,
      DispatchUserExceptionAction.new,
    );

    registry.registerWarningRule(UserExceptionWithoutCauseRule());
    registry.registerFixForRule(UserExceptionWithoutCauseRule.code, AddCause.new);

    registry.registerWarningRule(DispatchInGlobalErrorObserverRule());

    registry.registerWarningRule(ThrowInGlobalErrorObserverRule());
    registry.registerFixForRule(
      ThrowInGlobalErrorObserverRule.code,
      ReturnInsteadOfThrow.new,
    );

    registry.registerLintRule(GlobalErrorObserverWithoutEnvironmentRule());

    registry.registerWarningRule(RetryWithoutNonReentrantRule());
    registry.registerFixForRule(RetryWithoutNonReentrantRule.code, AddNonReentrant.new);

    registry.registerWarningRule(DispatchAndWaitUnlimitedRetriesRule());

    registry.registerWarningRule(SequentialDeadlockRule());
    registry.registerFixForRule(
      SequentialDeadlockRule.code,
      UseDispatchWithoutWaiting.new,
    );

    registry.registerWarningRule(SequentialBeforeSuperNotFirstRule());
    registry.registerWarningRule(SequentialAfterSuperNotInFinallyRule());

    registry.registerWarningRule(PollingActionRestartsPollingRule());
    registry.registerFixForRule(PollingActionRestartsPollingRule.code, UsePollOnce.new);

    registry.registerWarningRule(ServerPushAssociatedActionRule());
    registry.registerWarningRule(InternetSimulationInProductionRule());
    registry.registerLintRule(MissingKeyParamsRule());

    registry.registerWarningRule(PreferImmutableCollectionsRule());
    registry.registerFixForRule(
      PreferImmutableCollectionsRule.code,
      UseImmutableCollection.new,
    );

    registry.registerWarningRule(NonStateObjectInStateRule());
    registry.registerLintRule(RouteInStateRule());
    registry.registerWarningRule(MissingInitialStateRule());

    registry.registerWarningRule(EventNameSuffixRule());
    registry.registerFixForRule(EventNameSuffixRule.code, RenameEvent.new);

    registry.registerWarningRule(EventNotSpentInitiallyRule());
    registry.registerFixForRule(EventNotSpentInitiallyRule.code, UseSpentEvent.new);

    registry.registerWarningRule(EventPersistedRule());
    registry.registerWarningRule(EventConsumedTwiceRule());

    registry.registerWarningRule(ImplementsPersistorRule());
    registry.registerFixForRule(ImplementsPersistorRule.code, ExtendPersistor.new);

    registry.registerWarningRule(ThrowInReadStateRule());
    registry.registerFixForRule(ThrowInReadStateRule.code, AddErrorAndReturnNull.new);

    registry.registerWarningRule(InitialStateNotSavedRule());
    registry.registerFixForRule(InitialStateNotSavedRule.code, AddSaveInitialState.new);

    registry.registerWarningRule(DispatchInBuildRule());

    // Opposite styles. The first is enabled by default.
    registry.registerWarningRule(PreferDispatchWithoutContextRule());
    registry.registerFixForRule(
      PreferDispatchWithoutContextRule.code,
      RemoveContextFromDispatch.new,
    );
    registry.registerLintRule(PreferDispatchWithContextRule());
    registry.registerFixForRule(
      PreferDispatchWithContextRule.code,
      AddContextToDispatch.new,
    );

    registry.registerWarningRule(ContextReadInBuildRule());
    registry.registerFixForRule(ContextReadInBuildRule.code, UseContextSelect.new);

    registry.registerWarningRule(RefreshIndicatorWithoutWaitRule());
    registry.registerFixForRule(
      RefreshIndicatorWithoutWaitRule.code,
      WaitForDispatch.new,
    );

    registry.registerWarningRule(ThenOnDispatchAndWaitRule());
    registry.registerFixForRule(ThenOnDispatchAndWaitRule.code, UseThenIfCompletedOk.new);

    registry.registerWarningRule(StreamOrTimerInWidgetRule());

    registry.registerWarningRule(TimerOrStreamNotInPropsRule());

    registry.registerLintRule(ActionWithoutToStringRule());
    registry.registerFixForRule(ActionWithoutToStringRule.code, AddActionToString.new);

    registry.registerWarningRule(UserExceptionDialogPlacementRule());

    registry.registerWarningRule(NavigatorKeyNotSetRule());
    registry.registerFixForRule(NavigatorKeyNotSetRule.code, AddNavigatorKey.new);

    registry.registerWarningRule(DebugObserverInReleaseRule());

    registry.registerWarningRule(ExpectWithoutWaitingRule());
    registry.registerFixForRule(
      ExpectWithoutWaitingRule.code,
      UseAwaitDispatchAndWait.new,
    );

    registry.registerWarningRule(VmCreateFromReusedFactoryRule());
    registry.registerWarningRule(ActionStatusDetailsInProductionRule());
  }
}

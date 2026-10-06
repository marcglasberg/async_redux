## 0.1.0

* Initial release, with rules `reduce_return_type`, `before_return_type`,
  `wrap_reduce_return_type`, `reduce_without_await`, `dispatch_sync_async_action`,
  `wait_fail_invalid_argument`, `wait_fail_never_matches`, `incompatible_mixins`,
  `polling_with_caveat_mixin`, `avoid_context_state`, `context_state_in_init_state`,
  `context_in_dispose`, `context_in_selector`, `select_outside_build`,
  `vm_field_not_in_equals`, `copy_missing_field`,
  `state_class_must_be_immutable`, `state_class_missing_equality`,
  `equality_missing_field`, `equality_missing_inherited_field`,
  `equatable_props_missing_field`, `extend_base_action`,
  `dependencies_cast_in_action`, `prefer_return_null`, `stale_state_after_await`,
  `after_throws`, `missing_super_in_mixin_override`, `user_exception_outside_action`,
  `user_exception_without_cause`, `dispatch_in_global_error_observer`,
  `throw_in_global_error_observer`, `retry_without_non_reentrant`,
  `dispatch_and_wait_unlimited_retries`, `sequential_deadlock`,
  `sequential_before_super_not_first`, `sequential_after_super_not_in_finally`,
  `polling_action_restarts_polling`, `server_push_associated_action`,
  `internet_simulation_in_production`, `prefer_immutable_collections`,
  `non_state_object_in_state`, `missing_initial_state`, `event_name_suffix`,
  `event_not_spent_initially`, `event_persisted`, `dispatch_in_build`,
  `context_read_in_build`,
  `refresh_indicator_without_wait`, `then_on_dispatch_and_wait`,
  `stream_or_timer_in_widget`, `user_exception_dialog_placement`,
  `navigator_key_not_set`, `debug_observer_in_release`, `implements_persistor`,
  `throw_in_read_state`,
  `initial_state_not_saved`, `timer_or_stream_not_in_props`,
  `expect_without_waiting`, `vm_create_from_reused_factory`,
  `action_status_details_in_production` and `prefer_dispatch_without_context`, and
  their quick fixes.

* Opt-in rules `action_name_ends_with_action`,
  `action_name_ends_with_underscore_action`, `action_name_without_action`,
  `action_file_name_ends_with_action`, `action_file_name_starts_with_action`,
  `avoid_abort_dispatch`, `avoid_wrap_reduce`,
  `global_error_observer_without_env`, `route_in_state`,
  `missing_key_params`, `action_without_to_string` and
  `prefer_dispatch_with_context`, and the quick fixes of the action name rules, of
  `action_without_to_string` and of `prefer_dispatch_with_context`.

## Unreleased

* Remove view-model rules and fixes (`vm_field_not_in_equals` and
  `vm_create_from_reused_factory`) for AsyncRedux 31. Remove checks specific to
  `VmFactory`, `ModelObserver` and `context.getState()`. Keep checks for custom
  whole-state getters and the current context APIs.

## 1.2.0

* New `missing_state_class` lint, with a quick fix that adds `@stateClass`.

## 1.1.0

* New `async_mixin_in_sync_action` lint.

## 1.0.2

* Initial release of lint rules and quick fixes.

---
name: asyncredux-dependency-injection
description: Inject store-scoped environments, typed services, and configuration into Flutter AsyncRedux actions and tests.
---

# Inject store dependencies

Use `Store<AppState>`'s `environment` for a runtime mode, `configuration` for
immutable settings, and `dependencies` for services or repositories. Configuration
and dependency factories receive the store. Configuration is created first, so the
dependency factory can use it. In tests, create an isolated store with fake services.

Expose typed getters from the existing app base action if several actions need them.
In widgets, expose typed access to immutable settings through `getEnvironment<AppState>()`
or `getConfiguration<AppState>()`. Keep service calls in actions or the business layer.
Reading environment and configuration does not subscribe the widget.

This example uses `AppState` from the setup skill.

```dart
enum Environment { production, testing }

typedef CounterConfig = ({bool showDebugInfo});

abstract interface class CounterRepository {
  Future<int> loadAmount();
}

Store<AppState> createCounterStore({
  required Environment environment,
  required CounterRepository repository,
}) => Store<AppState>(
  initialState: const AppState(),
  environment: environment,
  configuration: (store) => (showDebugInfo: store.environment == Environment.testing),
  dependencies: (_) => repository,
);

extension CounterConfigContext on BuildContext {
  CounterConfig get counterConfig => getConfiguration<AppState>() as CounterConfig;
}

class LoadAmount extends AppAction {
  CounterRepository get repository => store.dependencies as CounterRepository;

  @override
  Future<AppState> reduce() async {
    final amount = await repository.loadAmount();
    return state.copy(counter: state.counter + amount);
  }
}
```

## References

- [Dependency injection](https://asyncredux.com/flutter/miscellaneous/dependency-injection)

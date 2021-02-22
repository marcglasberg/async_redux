import 'package:weak_map/weak_map.dart' as c;

/// Cache for 1 immutable state, and no parameters.
///
/// The first time this function is called with some state, it will calculate the result from it,
/// and then return the result. When this function is called again with the same state (compared
/// with the previous one by identity) it will return the same result, without having to calculate
/// again. When this function is called again with a different from the previous one, it will
/// evict the cache, recalculate the result, and cache it.
///
/// Example:
/// ```
/// var selector = cache1((int limit) =>
///    () =>
///    stateNames.take(limit).toList());
/// ```
Result? Function() Function(State1) cache1state<Result, State1>(
  Result Function() Function(State1) f,
) =>
    c.cache1state(f);

/// Cache for 1 immutable state, and 1 parameter.
///
/// When this function is called with some state and some parameter, it will check if it has
/// the cached result for this state/parameter combination. If so, it will return it from the cache,
/// without having to recalculate it again. If the result for this state/parameter combination is
/// not yet cached, it will calculate it, cache it, and then return it. Note: The cache has one
/// entry for each different parameter (comparing parameters by EQUALITY).
///
/// Cache eviction: Each time this function is called with some state, it will compare it (by
/// IDENTITY) with the state from the previous time the function was called. If the state is
/// different, the cache (for all parameters) will be evicted. In other words, as soon as the state
/// changes, it will clear all cached results and start all over again.
///
/// Example:
/// ```
/// var selector = cache1_1((List<String> state) =>
///    (String startString) =>
///    state.where((str) => str.startsWith(startString)).toList());
/// ```
Result? Function(Param1) Function(State1) cache1state_1param<Result, State1, Param1>(
  Result Function(Param1) Function(State1) f,
) =>
    c.cache1state_1param(f);

/// Cache for 1 immutable state, and 2 parameters.
///
/// When this function is called with some state and some parameters, it will check if it has
/// the cached result for this state/parameters combination. If so, it will return it from the
/// cache, without having to recalculate it again. If the result for this state/parameters
/// combination is not yet cached, it will calculate it, cache it, and then return it. Note: The
/// cache has one entry for each different parameter combination (comparing each parameter in the
/// combination by EQUALITY).
///
/// Cache eviction: Each time this function is called with some state, it will compare it (by
/// IDENTITY) with the state from the previous time the function was called. If the state is
/// different, the cache (for all parameters) will be evicted. In other words, as soon as the state
/// changes, it will clear all cached results and start all over again.
///
/// Example:
/// ```
/// var selector = cache1_2((List<String> state) => (String startString, String endString) {
///    return state
///       .where((str) => str.startsWith(startString) && str.endsWith(endString)).toList();
///    });
/// ```
Result? Function(Param1, Param2) Function(State1)
    cache1state_2params<Result, State1, Param1, Param2>(
  Result Function(Param1, Param2) Function(State1) f,
) =>
        c.cache1state_2params(f);

/// Cache for 2 immutable states, and no parameters.
///
/// The first time this function is called with some states, it will calculate the result from them,
/// and then return the result. When this function is called again with the same states (compared
/// with the previous ones by IDENTITY) it will return the same result, without having to calculate
/// again. When this function is called again with any of the states (or both) different from the
/// previous ones, it will evict the cache, recalculate the result, and cache it.
///
/// Example:
/// ```
/// var selector = cache2((List<String> names, int limit) =>
///        () => names.where((str) => str.startsWith("A")).take(limit).toList());
/// ```
Result? Function() Function(State1, State2) cache2states<Result, State1, State2>(
  Result Function() Function(State1, State2) f,
) =>
    c.cache2states(f);

/// Cache for 2 immutable states, and 1 parameter.
///
/// When this function is called with some states and a parameter, it will check if it has
/// the cached result for this states/parameter combination. If so, it will return it from the
/// cache, without having to recalculate it again. If the result for this states/parameter
/// combination is not yet cached, it will calculate it, cache it, and then return it. Note: The
/// cache has one entry for each different parameter (comparing parameters by EQUALITY).
///
/// Cache eviction: Each time this function is called with some states, it will compare them (by
/// IDENTITY) with the states from the previous time the function was called. If any of the states
/// is different, the cache (for all parameters) will be evicted. In other words, as soon as one
/// of the states (or both) change, it will clear all cached results and start all over again.
///
/// Example:
/// ```
/// var selector = cache2states_1param((List<String> names, int limit) => (String searchString) {
///    return names.where((str) => str.startsWith(searchString)).take(limit).toList();
///    });
/// ```
Result? Function(Param1) Function(State1, State2)
    cache2states_1param<Result, State1, State2, Param1>(
  Result Function(Param1) Function(State1, State2) f,
) =>
        c.cache2states_1param(f);

/// Cache for 2 immutable states, and 2 parameters.
///
/// When this function is called with some states and parameters, it will check if it has
/// the cached result for this states/parameters combination. If so, it will return it from the
/// cache, without having to recalculate it again. If the result for this states/parameters
/// combination is not yet cached, it will calculate it, cache it, and then return it. Note: The
/// cache has one entry for each different parameter combination (comparing the parameters in the
/// combination by EQUALITY).
///
/// Cache eviction: Each time this function is called with some states, it will compare them (by
/// IDENTITY) with the states from the previous time the function was called. If any of the states
/// is different, the cache (for all parameters) will be evicted. In other words, as soon as one
/// of the states (or both) change, it will clear all cached results and start all over again.
///
/// Example:
/// ```
/// var selector =
///    cache2states_2params((List<String> names, int limit) => (String startString, String endString) {
///       return names
///          .where((str) => str.startsWith(startString) && str.endsWith(endString))
///          .take(limit).toList();
///    });
/// ```
Result? Function(Param1, Param2) Function(State1, State2)
    cache2states_2params<Result, State1, State2, Param1, Param2>(
  Result Function(Param1, Param2) Function(State1, State2) f,
) =>
        c.cache2states_2params(f);

/// Cache for 3 immutable states, and no parameters.
/// Example:
///
/// The first time this function is called with some states, it will calculate the result from them,
/// and then return the result. When this function is called again with the same states (compared
/// with the previous ones by IDENTITY) it will return the same result, without having to calculate
/// again. When this function is called again with any of the states (or both) different from the
/// previous ones, it will evict the cache, recalculate the result, and cache it.
///
/// ```
/// var selector = cache3states((List<String> names, int limit, String prefix) =>
///        () => names.where((str) => str.startsWith(prefix)).take(limit).toList());
/// ```
Result? Function() Function(State1, State2, State3) cache3states<Result, State1, State2, State3>(
  Result Function() Function(State1, State2, State3) f,
) =>
    c.cache3states(f);

/// Cache for 1 immutable state, no parameters, and some extra information. This is the same
/// as [cache1state] but with an extra information. Note: The extra information is not used in
/// any way to decide whether the cache should be used/recalculated/evicted. It's just passed down
/// to the [f] function to be used during the result calculation.
Result? Function() Function(State1, Extra) cache1state_0params_x<Result, State1, Extra>(
  Result Function() Function(State1, Extra) f,
) =>
    c.cache1state_0params_x(f);

/// Cache for 2 immutable states, no parameters, and some extra information. This is the same
/// as [cache1state] but with an extra information. Note: The extra information is not used in
/// any way to decide whether the cache should be used/recalculated/evicted. It's just passed down
/// to the [f] function to be used during the result calculation.
Result? Function() Function(State1, State2, Extra)
    cache2states_0params_x<Result, State1, State2, Extra>(
  Result Function() Function(State1, State2, Extra) f,
) =>
        c.cache2states_0params_x(f);

/// Cache for 3 immutable states, no parameters, and some extra information.This is the same
/// as [cache1state] but with an extra information. Note: The extra information is not used in
/// any way to decide whether the cache should be used/recalculated/evicted. It's just passed down
/// to the [f] function to be used during the result calculation.
Result? Function() Function(State1, State2, State3, Extra)
    cache3states_0params_x<Result, State1, State2, State3, Extra>(
  Result Function() Function(State1, State2, State3, Extra) f,
) =>
        c.cache3states_0params_x(f);

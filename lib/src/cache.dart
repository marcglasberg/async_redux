import 'package:weak_map/weak_map.dart' as c;

/// Example:
/// ```
/// var selector = cache1((int limit) =>
///    () =>
///    stateNames.take(limit).toList());
/// ```
R Function() Function(S1) cache1<R, S1>(
  R Function() Function(S1) f,
) =>
    c.cache1_0(f);

/// Example:
/// ```
/// var selector = cache1_1((List<String> state) =>
///    (String startString) =>
///    state.where((str) => str.startsWith(startString)).toList());
/// ```
R Function(P1) Function(S1) cache1_1<R, S1, P1>(
  R Function(P1) Function(S1) f,
) =>
    c.cache1_1(f);

/// Example:
/// ```
/// var selector = cache1_2((List<String> state) => (String startString, String endString) {
///    return state
///       .where((str) => str.startsWith(startString) && str.endsWith(endString)).toList();
///    });
/// ```
R Function(P1, P2) Function(S1) cache1_2<R, S1, P1, P2>(
  R Function(P1, P2) Function(S1) f,
) =>
    c.cache1_2(f);

/// Example:
/// ```
/// var selector = cache2((List<String> names, int limit) =>
///        () => names.where((str) => str.startsWith("A")).take(limit).toList());
/// ```
R Function() Function(S1, S2) cache2<R, S1, S2>(
  R Function() Function(S1, S2) f,
) =>
    c.cache2_0(f);

/// Example:
/// ```
/// var selector = cache2_1((List<String> names, int limit) => (String searchString) {
///    return names.where((str) => str.startsWith(searchString)).take(limit).toList();
///    });
/// ```
R Function(P1) Function(S1, S2) cache2_1<R, S1, S2, P1>(
  R Function(P1) Function(S1, S2) f,
) =>
    c.cache2_1(f);

/// Example:
/// ```
/// var selector =
///    cache2_2((List<String> names, int limit) => (String startString, String endString) {
///       return names
///          .where((str) => str.startsWith(startString) && str.endsWith(endString))
///          .take(limit).toList();
///    });
/// ```
R Function(P1, P2) Function(S1, S2) cache2_2<R, S1, S2, P1, P2>(
  R Function(P1, P2) Function(S1, S2) f,
) =>
    c.cache2_2(f);

/// Example:
/// ```
/// var selector = cache3((List<String> names, int limit, String prefix) =>
///        () => names.where((str) => str.startsWith(prefix)).take(limit).toList());
/// ```
R Function() Function(S1, S2, S3) cache3<R, S1, S2, S3>(
  R Function() Function(S1, S2, S3) f,
) =>
    c.cache3_0(f);

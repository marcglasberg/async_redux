import 'dart:collection';
import 'package:weak_map/weak_map.dart';

// /////////////////////////////////////////////////////////////////////////////////////////////////

typedef R1_1<R, P1> = R Function(P1);
typedef F1_1<R, S1, P1> = R1_1<R, P1> Function(S1);

F1_1<R, S1, P1> createSelector1_1<R, S1, P1>(F1_1<R, S1, P1> f) {
  WeakContainer _s1;
  WeakMap<S1, Map<P1, R>> weakMap;

  return (S1 s1) {
    return (P1 p1) {
      if (_s1 == null || !_s1.contains(s1)) {
        weakMap = WeakMap();
        Map<P1, R> map = HashMap();
        weakMap[s1] = map;
        _s1 = WeakContainer(s1);
        var result = f(s1)(p1);
        map[p1] = result;
        return result;
      }
      //
      else {
        Map<P1, R> map = weakMap[s1];
        assert(map != null);
        if (!map.containsKey(p1)) {
          var result = f(s1)(p1);
          map[p1] = result;
          return result;
        }
        //
        else
          return map[p1];
      }
    };
  };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////

typedef R1_2<R, P1, P2> = R Function(P1, P2);
typedef F1_2<R, S1, P1, P2> = R1_2<R, P1, P2> Function(S1);

F1_2<R, S1, P1, P2> createSelector1_2<R, S1, P1, P2>(F1_2<R, S1, P1, P2> f) {
  WeakContainer _s1;
  WeakMap<S1, Map<_Pair<P1, P2>, R>> weakMap;

  return (S1 s1) {
    return (P1 p1, P2 p2) {
      var parP = _Pair(p1, p2);
      if (_s1 == null || !_s1.contains(s1)) {
        weakMap = WeakMap();
        Map<_Pair<P1, P2>, R> map = HashMap();
        weakMap[s1] = map;
        _s1 = WeakContainer(s1);
        var result = f(s1)(p1, p2);
        map[parP] = result;
        return result;
      }
      //
      else {
        Map<_Pair<P1, P2>, R> map = weakMap[s1];
        assert(map != null);
        if (!map.containsKey(parP)) {
          var result = f(s1)(p1, p2);
          map[parP] = result;
          return result;
        }
        return map[parP];
      }
    };
  };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////

typedef R2_1<R, P1> = R Function(P1);
typedef F2_1<R, S1, S2, P1> = R2_1<R, P1> Function(S1, S2);

F2_1<R, S1, S2, P1> createSelector2_1<R, S1, S2, P1>(F2_1<R, S1, S2, P1> f) {
  WeakContainer _s1, _s2;
  WeakMap<_PairIdentical, Map<P1, R>> weakMap;

  return (S1 s1, S2 s2) {
    var parS = _PairIdentical(s1, s2);
    return (P1 p1) {
      if (_s1 == null || _s2 == null || !_s1.contains(s1) || !_s2.contains(s2)) {
        weakMap = WeakMap();
        Map<P1, R> map = HashMap();
        weakMap[parS] = map;
        _s1 = WeakContainer(s1);
        _s2 = WeakContainer(s2);
        var result = f(s1, s2)(p1);
        map[p1] = result;
        return result;
      }
      //
      else {
        Map<P1, R> map = weakMap[parS];
        assert(map != null);
        if (!map.containsKey(p1)) {
          var result = f(s1, s2)(p1);
          map[p1] = result;
          return result;
        }

        return map[p1];
      }
    };
  };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////

typedef R2_2<R, P1, P2> = R Function(P1, P2);
typedef F2_2<R, S1, S2, P1, P2> = R2_2<R, P1, P2> Function(S1, S2);

F2_2<R, S1, S2, P1, P2> createSelector2_2<R, S1, S2, P1, P2>(F2_2<R, S1, S2, P1, P2> f) {
  WeakContainer _s1, _s2;
  WeakMap<_PairIdentical, Map<_Pair, R>> weakMap;

  return (S1 s1, S2 s2) {
    var parS = _PairIdentical(s1, s2);
    return (P1 p1, P2 p2) {
      var par = _Pair(p1, p2);
      if (_s1 == null || !_s1.contains(s1) || !_s2.contains(s2)) {
        weakMap = WeakMap();
        Map<_Pair, R> map = HashMap();
        weakMap[parS] = map;
        _s1 = WeakContainer(s1);
        _s2 = WeakContainer(s2);
        var result = f(s1, s2)(p1, p2);
        map[par] = result;
        return result;
      }
      //
      else {
        Map<_Pair, R> map = weakMap[parS];
        assert(map != null);
        if (!map.containsKey(par)) {
          var result = f(s1, s2)(p1, p2);
          map[par] = result;
          return result;
        }

        return map[par];
      }
    };
  };
}

// /////////////////////////////////////////////////////////////////////////////////////////////////

class _PairIdentical<X, Y> {
  final X x;
  final Y y;

  _PairIdentical(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PairIdentical &&
          runtimeType == other.runtimeType &&
          identical(x, other.x) &&
          identical(y, other.y);

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////

class _Pair<X, Y> {
  final X x;
  final Y y;

  _Pair(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Pair && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

// /////////////////////////////////////////////////////////////////////////////////////////////////

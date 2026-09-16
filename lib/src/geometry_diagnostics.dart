// Internal, assertion-only diagnostics. Deliberately not exported by the package.
import 'dart:async';

enum GeometryWork { fit, flatten, boolean, assembly, layer }

class GeometryDiagnostics {
  static final Object _key = Object();
  final bool forceGeneralRegions;
  final bool legacyPainter;
  final Map<GeometryWork, int> counts = {};

  GeometryDiagnostics(
      {this.forceGeneralRegions = false, this.legacyPainter = false});

  int operator [](GeometryWork work) => counts[work] ?? 0;

  T run<T>(T Function() body) => runZoned(body, zoneValues: {_key: this});

  static GeometryDiagnostics? get _current => Zone.current[_key];
}

// Call only inside assert, so recording has no release/profile overhead.
bool record(GeometryWork work) {
  final diagnostics = GeometryDiagnostics._current;
  if (diagnostics != null) {
    diagnostics.counts.update(work, (n) => n + 1, ifAbsent: () => 1);
  }
  return true;
}

bool get forceGeneralRegions {
  var result = false;
  assert(() {
    result = GeometryDiagnostics._current?.forceGeneralRegions ?? false;
    return true;
  }());
  return result;
}

bool get legacyPainter {
  var result = false;
  assert(() {
    result = GeometryDiagnostics._current?.legacyPainter ?? false;
    return true;
  }());
  return result;
}

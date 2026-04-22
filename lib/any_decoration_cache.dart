import 'dart:collection';
import 'dart:ui';

import 'any_contour.dart';

typedef AnyDecorationCacheKey = (AnyDecoration, Size, TextDirection?);

/// Small shared cache for contours.
class AnyDecorationCache {

  static int limit = 1000;

  static final LinkedHashMap<AnyDecorationCacheKey, AnyContour> _contours =
      LinkedHashMap<AnyDecorationCacheKey, AnyContour>();

  static AnyContour? get(AnyDecorationCacheKey key) {
    final contour = _contours[key];
    if (contour == null) return null;

    _contours.remove(key);
    _contours[key] = contour;
    return contour;
  }

  static void put(AnyDecorationCacheKey key, AnyContour contour) {
    _contours.remove(key);
    _contours[key] = contour;

    while (_contours.length > limit) {
      _contours.remove(_contours.keys.first);
    }
  }

  static void clear() {
    _contours.clear();
  }
}

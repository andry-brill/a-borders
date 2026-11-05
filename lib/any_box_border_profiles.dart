import 'any_edge_profile.dart';

/// Edge profiles for AnyBoxDecoration, with the same fallback order as sides.
/// Null inherits; [AnyStraightProfile] explicitly disables an inherited profile.
class AnyBoxBorderProfiles {
  final AnyEdgeProfile all;
  final AnyEdgeProfile? horizontal;
  final AnyEdgeProfile? vertical;
  final AnyEdgeProfile? top;
  final AnyEdgeProfile? right;
  final AnyEdgeProfile? bottom;
  final AnyEdgeProfile? left;

  const AnyBoxBorderProfiles({
    this.all = const AnyStraightProfile(),
    this.horizontal,
    this.vertical,
    this.top,
    this.right,
    this.bottom,
    this.left,
  });

  /// Profiles in top, right, bottom, left construction order.
  List<AnyEdgeProfile> get resolvedProfiles => List.unmodifiable([
        top ?? horizontal ?? all,
        right ?? vertical ?? all,
        bottom ?? horizontal ?? all,
        left ?? vertical ?? all,
      ]);

  @override
  bool operator ==(Object other) =>
      other is AnyBoxBorderProfiles &&
      other.all == all &&
      other.horizontal == horizontal &&
      other.vertical == vertical &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom &&
      other.left == left;

  @override
  int get hashCode =>
      Object.hash(all, horizontal, vertical, top, right, bottom, left);
}

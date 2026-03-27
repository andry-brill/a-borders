import 'package:any_borders/any_borders.dart';
import 'package:flutter/material.dart';

class AnySideBuilder {

  double width = 0.0;
  AnyAlign? align;

  Color? color;
  Gradient? gradient;
  DecorationImage? image;
  BlendMode? blendMode;

  AnySideBuilder();

  bool get isEmpty =>
      width.abs() <= 0.00001 &&
          color == null &&
          gradient == null &&
          image == null;

  AnySide? buildOrNull() {
    if (isEmpty) return null;

    return AnySide(
      width: width,
      align: align,
      color: color,
      gradient: gradient,
      image: image,
      blendMode: blendMode,
    );
  }
}

class AnyBorderBuilder {

  final AnySideBuilder left = AnySideBuilder();
  final AnySideBuilder top = AnySideBuilder();
  final AnySideBuilder right = AnySideBuilder();
  final AnySideBuilder bottom = AnySideBuilder();
  final AnySideBuilder sides = AnySideBuilder();

  IAnyCorner? topLeft;
  IAnyCorner? topRight;
  IAnyCorner? bottomRight;
  IAnyCorner? bottomLeft;
  IAnyCorner? corners;

  AnyBorderBuilder();

  AnyBorder build() {
    return AnyBorder(
      left: left.buildOrNull(),
      top: top.buildOrNull(),
      right: right.buildOrNull(),
      bottom: bottom.buildOrNull(),
      sides: sides.buildOrNull(),
      topLeft: topLeft,
      topRight: topRight,
      bottomRight: bottomRight,
      bottomLeft: bottomLeft,
      corners: corners,
    );
  }
}

class AnyDecorationBuilder {

  final AnyBorderBuilder border = AnyBorderBuilder();

  List<IAnyShadow>? shadows;

  Color? color;
  Gradient? gradient;
  DecorationImage? image;
  BlendMode? blendMode;

  AnyShapeBase? clip;
  AnyShapeBase? background;

  AnyDecorationBuilder();

  AnyDecoration build() {
    return AnyDecoration(
      border: border.build(),
      shadows: (shadows == null || shadows!.isEmpty) ? null : shadows,
      color: color,
      gradient: gradient,
      image: image,
      blendMode: blendMode,
      clip: clip,
      background: background,
    );
  }
}


class Change {
  final String name;
  final void Function(AnyDecorationBuilder) change;
  const Change(this.name, this.change);
}

class ChangeGroup {
  final String name;
  final List<Change> changes;
  const ChangeGroup(this.name, this.changes);
}

class ExampleGenerator  {

  static const groupSeparator = ' ';
  static const changeSeparator = '-';

  final List<ChangeGroup> groups;
  const ExampleGenerator(this.groups);

  // Iterable<(String,List<Change>)> changes() sync* {
  //   // TODO implement grouping groups name
  //   //  TODO like if we have [ChangeGroup('TopBorder', [Change('Width0', ..), Change('Width10', ..)], ChangeGroup('TopBorder', [Change('AlignInner', ..), Change('AlignOuter', ..)]), ...]
  //   //  TODO we will get TopBorder-Width0-AlignInner (no duplication)
  //   // TODO implement cross join for each group changes and yield to iterate over
  // }

  Iterable<(String, List<Change>)> changes() sync* {
    if (groups.isEmpty) return;

    // Group ChangeGroups by their name, preserving first appearance order.
    final orderedNames = <String>[];
    final grouped = <String, List<ChangeGroup>>{};

    for (final group in groups) {
      final bucket = grouped[group.name];
      if (bucket == null) {
        orderedNames.add(group.name);
        grouped[group.name] = [group];
      } else {
        bucket.add(group);
      }
    }

    // For each unique group name, build all combinations across all groups
    // sharing that name.
    final perNamedGroup = <List<(String, List<Change>)>>[];

    for (final groupName in orderedNames) {
      final sameNameGroups = grouped[groupName]!;

      List<(String, List<Change>)> combinations = [('', <Change>[])];

      for (final group in sameNameGroups) {
        final next = <(String, List<Change>)>[];

        for (final current in combinations) {
          for (final change in group.changes) {
            final currentName = current.$1;
            final nextName = currentName.isEmpty
                ? change.name
                : '$currentName$changeSeparator${change.name}';

            next.add((
            nextName,
            [...current.$2, change],
            ));
          }
        }

        combinations = next;
      }

      perNamedGroup.add([
        for (final combo in combinations)
          (
          combo.$1.isEmpty
              ? groupName
              : groupName.isEmpty
              ? combo.$1
              : '$groupName$changeSeparator${combo.$1}',
          combo.$2,
          ),
      ]);
    }

    // Cross join across unique named groups.
    List<(String, List<Change>)> result = [('', <Change>[])];

    for (final namedGroupVariants in perNamedGroup) {
      final next = <(String, List<Change>)>[];

      for (final current in result) {
        for (final variant in namedGroupVariants) {
          final currentName = current.$1;
          final variantName = variant.$1;

          final nextName = currentName.isEmpty
              ? variantName
              : variantName.isEmpty
              ? currentName
              : '$currentName$groupSeparator$variantName';

          next.add((
          nextName,
          [...current.$2, ...variant.$2],
          ));
        }
      }

      result = next;
    }

    yield* result;
  }

  List<(String,AnyDecoration)> build() {

    int total = 0;
    Set<AnyDecoration> unique = {};
    List<(String,AnyDecoration)> result = [];

    for (var (name, changes) in changes()) {
      AnyDecorationBuilder builder = AnyDecorationBuilder();
      for (var change in changes) {
        change.change(builder);
      }

      final decoration = builder.build();
      total++;

      if (!unique.contains(decoration)) {
        result.add((name, decoration));
        unique.add(decoration);
      }
    }

    debugPrint('Built ${result.length} examples from $total total builds');

    return result;
  }
}
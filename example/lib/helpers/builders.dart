
import 'package:flutter/material.dart';

import '../polygon_stroke_regions_rounded.dart';

class AnySideBuilder {
  double width = 0.0;
  double align = AnySide.alignCenter;

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

class AnyDecorationBuilder {
  final AnySideBuilder left = AnySideBuilder();
  final AnySideBuilder top = AnySideBuilder();
  final AnySideBuilder right = AnySideBuilder();
  final AnySideBuilder bottom = AnySideBuilder();
  final AnySideBuilder sides = AnySideBuilder();

  List<AnyShadow> shadows = [];

  Color? color;
  Gradient? gradient;
  DecorationImage? image;
  BlendMode? blendMode;

  AnyShapeBase? clip;
  AnyShapeBase? background;

  AnyDecorationBuilder();

  AnyDecoration build() {
    return AnyBoxDecoration(
      left: left.buildOrNull(),
      top: top.buildOrNull(),
      right: right.buildOrNull(),
      bottom: bottom.buildOrNull(),
      sides: sides.buildOrNull(),
      topRight: AnyCorner(Radius.elliptical(10, 0)),
      shadows: shadows,
      color: color,
      gradient: gradient,
      image: image,
      blendMode: blendMode,
      clip: clip ?? AnyShapeBase.zeroBorder,
      background: background ?? AnyShapeBase.zeroBorder,
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

class ExampleGenerator {
  static const groupSeparator = ' ';
  static const changeSeparator = '-';

  final List<ChangeGroup> groups;
  const ExampleGenerator(this.groups);

  Iterable<(String, List<Change>)> changes() sync* {
    if (groups.isEmpty) return;

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

  List<(String, AnyDecoration)> build() {
    final result = <(String, AnyDecoration)>[];

    for (final (name, changes) in changes()) {
      final builder = AnyDecorationBuilder();
      for (final change in changes) {
        change.change(builder);
      }

      final decoration = builder.build();
      result.add((name, decoration));
    }

    debugPrint('Built ${result.length} examples');

    return result;
  }
}


import 'package:flutter/material.dart';

import 'package:any_borders/any_borders.dart';


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
      topRight: BevelCorner(radius: Radius.circular(10)),
      shadows: shadows,
      clipBase: clip ?? AnyShapeBase.zeroBorder,
      background: AnyBackground(
        color: color,
        gradient: gradient,
        image: image,
        blendMode: blendMode,
        shapeBase: background ?? AnyShapeBase.zeroBorder,
      ),
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



final c = Colors.blue[400];
final cl = Colors.amber[200];
final ct = Colors.purple[300];
final cr = Colors.red[300];
final cb = Colors.green[400];

const w0 = 00.0;
const w1 = 10.0;
const w2 = 20.0;
const w3 = 30.0;
const w4 = 40.0;

final generator = ExampleGenerator([

  ChangeGroup('BACK', [Change('N', (d) => d.color = null), Change('C', (d) => d.color = c)]),

  ChangeGroup('TOP', [
    Change('INN', (d) => d.top.align = AnySide.alignInside),
    Change('CEN', (d) => d.top.align = AnySide.alignCenter),
    Change('OUT', (d) => d.top.align = AnySide.alignOutside),
  ]),
  ChangeGroup('TOP', [
    Change('W0', (d) => d.top.width = w0),
    Change('W1', (d) => d.top.width = w1),
  ]),
  ChangeGroup('TOP', [
    Change('C', (d) => d.top.color = c),
    Change('CT', (d) => d.top.color = ct),
  ]),

  ChangeGroup('RIGHT', [
    Change('INN', (d) => d.right.align = AnySide.alignInside),
    Change('CEN', (d) => d.right.align = AnySide.alignCenter),
    Change('OUT', (d) => d.right.align = AnySide.alignOutside),
  ]),
  ChangeGroup('RIGHT', [
    Change('W0', (d) => d.right.width = w0),
    Change('W1', (d) => d.right.width = w1),
    Change('W2', (d) => d.right.width = w2),
  ]),
  ChangeGroup('RIGHT', [
    Change('C', (d) => d.right.color = c),
    Change('CT', (d) => d.right.color = ct),
    Change('CR', (d) => d.right.color = cr),
  ]),
]);
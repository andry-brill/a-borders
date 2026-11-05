part of '../any_contour.dart';

/// An owned, reusable recording of an [AnyDecoration] at a fixed configuration.
///
/// Obtain one with [AnyDecoration.resolveRenderer], retain it across paints,
/// and call [dispose] when finished. Positions are not part of the cache: each
/// [paint] translates the canvas and replays the same picture. Shadows and
/// outward borders are preserved outside the configured layout size.
///
/// This caches drawing commands, not pixels; the engine still rasterizes them.
/// Image loading and animation invalidate the recording and call [onChanged].
/// The next paint records the latest content once for all subsequent instances.
final class AnyDecorationRenderer {
  AnyDecorationRenderer._(
    this.decoration,
    this.configuration,
    this.onChanged,
  ) {
    final size = configuration.size;
    if (size == null ||
        !size.width.isFinite ||
        !size.height.isFinite ||
        size.width < 0 ||
        size.height < 0) {
      throw ArgumentError.value(
        size,
        'configuration.size',
        'Must be a finite, nonnegative size',
      );
    }
    _painter = decoration.createBoxPainter(_handleChanged);
    try {
      _record();
    } catch (_) {
      dispose();
      rethrow;
    }
  }

  final AnyDecoration decoration;
  final ImageConfiguration configuration;

  /// Requests a repaint after an image loads or advances to its next frame.
  final VoidCallback? onChanged;

  late final BoxPainter _painter;
  Picture? _picture;
  bool _dirty = true;
  bool _disposed = false;

  void _handleChanged() {
    if (_disposed) return;
    _dirty = true;
    onChanged?.call();
  }

  void _record() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    // A notification during recording must not be overwritten afterwards.
    _dirty = false;
    try {
      _painter.paint(canvas, Offset.zero, configuration);
      final picture = recorder.endRecording();
      if (_disposed) {
        picture.dispose();
        throw StateError(
            'AnyDecorationRenderer was disposed during recording.');
      }
      _picture?.dispose();
      _picture = picture;
    } catch (_) {
      _dirty = true;
      if (recorder.isRecording) recorder.endRecording().dispose();
      rethrow;
    }
  }

  /// Draws the decoration with its layout origin at [offset].
  ///
  /// Preserves the caller's canvas transform and clip. It does not clip to the
  /// layout bounds or add a compositing layer, so overflow and blend modes keep
  /// their normal painting behavior. Throws after [dispose].
  void paint(Canvas canvas, Offset offset) {
    if (_disposed) {
      throw StateError('Cannot paint a disposed AnyDecorationRenderer.');
    }
    if (_dirty) _record();
    canvas.save();
    try {
      canvas.translate(offset.dx, offset.dy);
      canvas.drawPicture(_picture!);
    } finally {
      canvas.restore();
    }
  }

  /// Releases the recorded picture and image listeners. Safe to call again.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _picture?.dispose();
    _picture = null;
    _painter.dispose();
  }
}

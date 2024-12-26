import 'dart:ui';

import 'package:flutter/material.dart' hide Image;

import 'controller.dart';

///Handles all the painting ongoing on the canvas.
class DrawImage extends CustomPainter {
  ///The background for signature painting.
  final Color? backgroundColor;

  //Controller is a listenable with all of the paint details.
  late ImagePainterController _controller;

  ///Constructor for the canvas
  DrawImage({
    required ImagePainterController controller,
    this.backgroundColor,
  }) : super(repaint: controller) {
    _controller = controller;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final _offset = _controller.offsets;

    ///paints [ui.Image] on the canvas for reference to draw over it.
    paintImage(
      canvas: canvas,
      image: _controller.image!,
      filterQuality: FilterQuality.high,
      rect: Rect.fromPoints(
        const Offset(0, 0),
        Offset(size.width, size.height),
      ),
    );

    ///paints all the previoud paintInfo history recorded on [PaintHistory]
    //final _offset = item.offsets;
    final _painter = _controller.paintHistory[0].paint;
    switch (_controller.mode) {
      case PaintMode.rect:
        canvas.drawRect(Rect.fromPoints(_offset[0]!, _offset[1]!), _painter);
        break;
      case PaintMode.line:
        canvas.drawLine(_offset[0]!, _offset[1]!, _painter);
        break;
      case PaintMode.circle:
        final path = Path();
        path.addOval(
          Rect.fromCircle(
              center: _offset[1]!,
              radius: (_offset[0]! - _offset[1]!).distance),
        );
        canvas.drawPath(path, _painter);
        break;
      case PaintMode.arrow:
        drawArrow(canvas, _offset[0]!, _offset[1]!, _painter);
        break;
      case PaintMode.dashLine:
        final path = Path()
          ..moveTo(_offset[0]!.dx, _offset[0]!.dy)
          ..lineTo(_offset[1]!.dx, _offset[1]!.dy);
        canvas.drawPath(_dashPath(path, _painter.strokeWidth), _painter);
        break;
      case PaintMode.freeStyle:
        final newPaint = Paint()
          ..color = Colors.blue.withValues(alpha: 0.2)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        for (int i = 0; i < _offset.length - 1; i++) {
          if (_offset[i] != null && _offset[i + 1] != null) {
            final path = Path()
              ..moveTo(_offset[i]!.dx, _offset[i]!.dy)
              ..lineTo(_offset[i + 1]!.dx, _offset[i + 1]!.dy);

            // Use the consistent 'newPaint' object
            canvas.drawPath(path, newPaint);
          }
        }
        break;
      default:
    }

    ///Draws ongoing action on the canvas while indrag.
    if (_controller.busy) {
      final _start = _controller.start;
      final _end = _controller.end;
      final _paint = _controller.brush;
      switch (_controller.mode) {
        case PaintMode.rect:
          canvas.drawRect(Rect.fromPoints(_start!, _end!), _paint);
          break;
        case PaintMode.line:
          canvas.drawLine(_start!, _end!, _paint);
          break;
        case PaintMode.circle:
          final path = Path();
          path.addOval(Rect.fromCircle(
              center: _end!, radius: (_end - _start!).distance));
          canvas.drawPath(path, _paint);
          break;
        case PaintMode.arrow:
          drawArrow(canvas, _start!, _end!, _paint);
          break;
        case PaintMode.dashLine:
          final path = Path()
            ..moveTo(_start!.dx, _start.dy)
            ..lineTo(_end!.dx, _end.dy);
          canvas.drawPath(_dashPath(path, _paint.strokeWidth), _paint);
          break;
        case PaintMode.freeStyle:
          final newPaint = Paint()
            ..color = Colors.blue.withValues(alpha: 0.2)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;

          for (int i = 0; i < _offset.length - 1; i++) {
            if (_offset[i] != null && _offset[i + 1] != null) {
              final path = Path()
                ..moveTo(_offset[i]!.dx, _offset[i]!.dy)
                ..lineTo(_offset[i + 1]!.dx, _offset[i + 1]!.dy);

              // Use the consistent 'newPaint' object
              canvas.drawPath(path, newPaint);
            }
          }
          break;
        default:
      }
    }

    ///Draws all the completed actions of painting on the canvas.
  }

  ///Draws line as well as the arrowhead on top of it.
  ///Uses [strokeWidth] of the painter for sizing.
  void drawArrow(Canvas canvas, Offset start, Offset end, Paint painter) {
    final arrowPainter = Paint()
      ..color = painter.color
      ..strokeWidth = painter.strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, end, painter);
    final _pathOffset = painter.strokeWidth / 15;
    final path = Path()
      ..lineTo(-15 * _pathOffset, 10 * _pathOffset)
      ..lineTo(-15 * _pathOffset, -10 * _pathOffset)
      ..close();
    canvas.save();
    canvas.translate(end.dx, end.dy);
    canvas.rotate((end - start).direction);
    canvas.drawPath(path, arrowPainter);
    canvas.restore();
  }

  ///Draws dashed path.
  ///It depends on [strokeWidth] for space to line proportion.
  Path _dashPath(Path path, double width) {
    final dashPath = Path();
    final dashWidth = 10.0 * width / 5;
    final dashSpace = 10.0 * width / 5;
    var distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth;
        distance += dashSpace;
      }
    }
    return dashPath;
  }

  @override
  bool shouldRepaint(DrawImage oldInfo) {
    return oldInfo._controller != _controller;
  }
}

///All the paint method available for use.

enum PaintMode {
  ///Prefer using [None] while doing scaling operations.
  none,

  ///Allows for drawing freehand shapes or text.
  freeStyle,

  ///Allows to draw line between two points.
  line,

  ///Allows to draw rectangle.
  rect,

  ///Allows to write texts over an image.
  text,

  ///Allows us to draw line with arrow at the end point.
  arrow,

  ///Allows to draw circle from a point.
  circle,

  ///Allows to draw dashed line between two point.
  dashLine
}

///[PaintInfo] keeps track of a single unit of shape, whichever selected.
class PaintInfo {
  ///Mode of the paint method.
  final PaintMode mode;

  //Used to save color
  final Color color;

  //Used to store strokesize of the mode.
  final double strokeWidth;

  ///Used to save offsets.
  ///Two point in case of other shapes and list of points for [FreeStyle].
  List<Offset?> offsets;

  ///Used to save text in case of text type.
  String text;

  //To determine whether the drawn shape is filled or not.
  bool fill;

  Paint get paint => Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..style = shouldFill ? PaintingStyle.fill : PaintingStyle.stroke;

  bool get shouldFill {
    if (mode == PaintMode.circle || mode == PaintMode.rect) {
      return fill;
    } else {
      return false;
    }
  }

  ///In case of string, it is used to save string value entered.
  PaintInfo({
    required this.mode,
    required this.offsets,
    required this.color,
    required this.strokeWidth,
    this.text = '',
    this.fill = false,
  });
}

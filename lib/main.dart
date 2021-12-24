import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void main() {
  runApp(const MyApp());
}

const backgroundColor = Color(0xFF000033);

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool useFill = false;
  List<Color>? gradient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: backgroundColor,
              height: 300,
              child: GraphWidget(
                fill: useFill,
                gradientColors: gradient,
                values: List.generate(
                  15,
                  (index) => GraphPoint(
                    y: math.Random().nextDouble() * 100,
                    x: 50.0 * (index),
                  ),
                ),
              ),
            ),
            Padding(
              padding: _buttonPadding.copyWith(top: 12),
              child: TextButton(
                style: _buttonStyle,
                onPressed: () {
                  setState(() {
                    useFill = true;
                  });
                },
                child: _buttonText("Use fill"),
              ),
            ),
            Padding(
              padding: _buttonPadding,
              child: TextButton(
                style: _buttonStyle,
                onPressed: () {
                  setState(() {
                    gradient = [
                      Colors.green.withOpacity(.5),
                      Colors.greenAccent,
                      Colors.lime
                    ];
                  });
                },
                child: _buttonText("Use different gradient"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  EdgeInsets get _buttonPadding =>
      const EdgeInsets.symmetric(horizontal: 32, vertical: 8);

  Text _buttonText(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  ButtonStyle get _buttonStyle {
    return ButtonStyle(
      backgroundColor: MaterialStateProperty.all(Colors.grey),
    );
  }
}

class GraphPoint {
  final double x;
  final double y;
  final bool fill;

  GraphPoint({required this.x, required this.y, this.fill = false});

  GraphPoint operator +(covariant GraphPoint other) {
    return GraphPoint(x: x + other.x, y: y + other.y, fill: fill);
  }

  GraphPoint operator /(covariant GraphPoint other) {
    return GraphPoint(x: x / other.x, y: y / other.y, fill: fill);
  }

  @override
  bool operator ==(covariant GraphPoint other) {
    return other.x == x && other.y == y;
  }

  // @override
  // int get hashCode => hash(x.hashCode, y.hashCode);

  @override
  String toString() {
    return 'GraphPoint(x: $x, y: $y,)';
  }
}

class GraphWidget extends ScrollView {
  GraphWidget({
    Key? key,
    required this.values,
    this.fill = false,
    this.gradientColors,
  }) : super(key: key) {
    if (gradientColors != null) assert(gradientColors?.length == 3);
  }

  final List<GraphPoint> values;
  final bool fill;
  final List<Color>? gradientColors;
  @override
  List<Widget> buildSlivers(BuildContext context) {
    return [
      _RenderGraph(
        values: values,
        fill: fill,
        gradientColors: gradientColors,
      ),
    ];
  }

  @override
  Axis get scrollDirection => Axis.horizontal;
}

class _RenderGraph extends LeafRenderObjectWidget {
  const _RenderGraph({
    Key? key,
    required this.values,
    this.fill = false,
    this.gradientColors,
  }) : super(key: key);

  final List<GraphPoint> values;
  final bool fill;
  final List<Color>? gradientColors;
  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderGraphSliver(
      graphPoints: values,
      fill: fill,
      gradientColors: gradientColors,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderGraphSliver renderObject) {
    renderObject
      ..graphPoints = values
      ..gradientColors = gradientColors
      ..fill = fill;
  }
}

class _RenderGraphSliver extends RenderSliver with MathsHelperMixin {
  _RenderGraphSliver(
      {required List<GraphPoint> graphPoints,
      required bool fill,
      List<Color>? gradientColors}) {
    tapGestureRecognizer = TapGestureRecognizer()..onTapDown = _tapDown;
    _graphPoints = graphPoints;
    _fill = fill;
    _gradientColors = gradientColors;
  }

  void _tapDown(TapDownDetails details) {
    currentlySelectedPoint =
        _translateOffsetToGraphOffset(details.localPosition);

    markNeedsPaint();
  }

  set graphPoints(List<GraphPoint> values) {
    if (values == _graphPoints) return;
    _graphPoints = values;
    markNeedsPaint();
  }

  bool _fill = false;

  bool get fill => _fill;

  set fill(bool value) {
    if (_fill == value) return;
    _fill = value;
    markNeedsPaint();
  }

  List<Color>? _gradientColors;

  List<Color>? get gradientColors => _gradientColors;

  set gradientColors(List<Color>? value) {
    if (value == gradientColors) return;
    _gradientColors = value;

    markNeedsPaint();
  }

  static const double gapWidth = 50;
  static const double padding = 32;

  late Path _lineTouchAreaPath;
  late final TapGestureRecognizer tapGestureRecognizer;
  Offset? currentlySelectedPoint;

  int backgroundLinePadding = 12;

  var origin = Offset.zero;

  @override
  void performLayout() {
    final maxExtent = _maxXExtent + padding * 2;

    final double paintExtent =
        calculatePaintOffset(constraints, from: 0.0, to: maxExtent);

    final double cacheExtent =
        calculateCacheOffset(constraints, from: 0.0, to: maxExtent);

    geometry = SliverGeometry(
      scrollExtent: maxExtent,
      paintExtent: paintExtent,
      cacheExtent: cacheExtent,
      maxPaintExtent: maxExtent,
      hitTestExtent: paintExtent,
      hasVisualOverflow: maxExtent > constraints.remainingPaintExtent ||
          constraints.scrollOffset > 0.0,
    );
  }

  @override
  bool hitTestSelf(
      {required double mainAxisPosition, required double crossAxisPosition}) {
    var translatedOffset = _translateOffsetToGraphOffset(
        Offset(mainAxisPosition, crossAxisPosition));

    return _lineTouchAreaPath.contains(translatedOffset);
  }

  Offset _translateOffsetToGraphOffset(Offset offset) {
    if (verticalMinIsNegative) {
      return Offset(
          ((offset.dx - padding) + constraints.scrollOffset), -offset.dy / 2);
    }
    return Offset(
        ((offset.dx - padding) + constraints.scrollOffset), -offset.dy)
      ..translate(0, -origin.dy);
  }

  @override
  void handleEvent(PointerEvent event, SliverHitTestEntry entry) {
    if (event is PointerDownEvent) {
      tapGestureRecognizer.addPointer(event);
    }
  }

  Size get viewport =>
      Size(constraints.viewportMainAxisExtent, constraints.crossAxisExtent);

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final viewportRect = offset & viewport;

    final startOffset =
        verticalMinIsNegative ? viewport.height / 2 : viewport.height - padding;

    origin = Offset(0, startOffset);

    origin = origin.translate(-constraints.scrollOffset + padding,
        verticalMinIsNegative ? 0 : -padding);

    canvas.translate(origin.dx, origin.dy);

    /// DRAW LINE
    _drawDashedVerticalLine(canvas);

    _drawGraphLine(canvas, viewportRect);

    _drawIntersectionPoint(canvas, viewportRect);

    _drawText(canvas);
  }

  void _drawDashedVerticalLine(Canvas canvas) {
    final linePath = Path();
    _lineTouchAreaPath = Path();
    double dashHeight = viewport.height.toInt() - padding.toInt() * 2;

    for (int index = 0; index < _graphPoints.length; index++) {
      int gap = index * gapWidth.toInt();

      final isSelected = currentlySelectedPoint == null
          ? false
          : _isSelectedPoint(_graphPoints[index]);

      final double lineStart =
          verticalMinIsNegative ? -viewport.height / 2 : padding;

      final double lineEnd = verticalMinIsNegative
          ? (viewport.height / 2) - padding
          : -viewport.height + padding;

      const backgroundRad = Radius.circular(5);
      final singleLineBackgroundPath = Path()
        ..moveTo(gap.toDouble() - backgroundLinePadding, lineStart)
        ..addRRect(
          RRect.fromRectAndCorners(
            Rect.fromPoints(
              Offset(gap.toDouble() - backgroundLinePadding, lineStart),
              Offset(gap.toDouble() + backgroundLinePadding, lineEnd),
            ),
            topLeft: backgroundRad,
            topRight: backgroundRad,
            bottomLeft: backgroundRad,
            bottomRight: backgroundRad,
          ),
        );

      _lineTouchAreaPath.addPath(singleLineBackgroundPath, Offset.zero);

      canvas.drawPath(
        singleLineBackgroundPath,
        Paint()
          ..strokeWidth = 25
          ..style = PaintingStyle.stroke
          ..color = isSelected ? const Color(0xff000026) : Colors.transparent
          ..strokeCap = StrokeCap.butt,
      );
      var startIndex = 0;

      if (verticalMinIsNegative) {
        startIndex = -dashHeight.toInt() ~/ 2;
      }

      for (int j = startIndex; j < dashHeight.toInt(); j += 3) {
        linePath
          ..moveTo(gap.toDouble(), -j.toDouble())
          ..lineTo(gap.toDouble(), -j.toDouble() - 3);
        j = j + 3;
      }
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..strokeWidth = 0.7
        ..style = PaintingStyle.stroke
        ..color = Colors.grey[800]!
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawText(Canvas canvas) {
    for (int index = 0; index < _graphPoints.length; index++) {
      int gap = index * gapWidth.toInt();
      canvas.save();
      bool isSelected = _isSelectedPoint(_graphPoints[index]);

      final textStyle = TextStyle(
        color: isSelected ? Colors.white : Colors.white38,
        fontSize: isSelected ? 15 : 14,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      );
      final textSpan = TextSpan(
        text: '${_graphPoints[index].x.toInt()}',
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout(maxWidth: 50);

      final verticalEnd =
          verticalMinIsNegative ? (viewport.height / 2) - padding : padding;

      textPainter.paint(canvas, Offset(gap.toDouble() - 10, verticalEnd));
      canvas.restore();
    }
  }

  void _drawGraphLine(Canvas canvas, Rect viewportRect) {
    var path = Path();

    final values = CatmullRomSpline(
      _graphPoints
          .map(
            (e) => Offset(
              e.x,
              viewportYValue(
                value: e.y,
                viewportHeight: viewport.height,
                padding: padding,
              ),
            ),
          )
          .toList(),
    );

    var samples = values.generateSamples();

    path.moveTo(samples.first.value.dx, fill ? 0 : -samples.first.value.dy);

    for (var sample in samples) {
      final value = sample.value;
      path.lineTo(value.dx, -value.dy);

      if (fill && samples.last.value == value) {
        path.lineTo(value.dx, 0);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..shader = _gradientShader(viewportRect)
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round
        ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke,
    );
  }

  void _drawIntersectionPoint(Canvas canvas, Rect viewportRect) {
    if (currentlySelectedPoint == null) return;

    final point =
        _graphPoints.where((element) => _isSelectedPoint(element)).first;

    final y = -viewportYValue(
      value: point.y,
      viewportHeight: viewport.height,
      padding: padding,
    );

    canvas.drawCircle(
      pointToOffset(GraphPoint(y: y, x: point.x)),
      20,
      Paint()..color = backgroundColor,
    );

    canvas.drawCircle(
      pointToOffset(GraphPoint(y: y, x: point.x)),
      10,
      Paint()..shader = _gradientShader(viewportRect),
    );

    canvas.drawCircle(
      pointToOffset(GraphPoint(y: y, x: point.x)),
      5,
      Paint()..color = backgroundColor,
    );
  }

  Shader _gradientShader(Rect viewportRect) {
    return LinearGradient(
      colors: gradientColors ?? [Colors.amber, Colors.orange, Colors.red],
      stops: const [0.32, 0.64, 0.96],
    ).createShader(viewportRect);
  }

  bool _isSelectedPoint(GraphPoint point) {
    return currentlySelectedPoint == null
        ? false
        : numberIsBetween(
            currentlySelectedPoint!.dx - backgroundLinePadding,
            currentlySelectedPoint!.dx + backgroundLinePadding,
            point.x,
          );
  }
}

mixin MathsHelperMixin {
  List<GraphPoint> _graphPoints = [];

  double viewportYValue({
    required double value,
    required double viewportHeight,
    required double padding,
  }) {
    if (minY.isNegative) {
      viewportHeight = viewportHeight / 2;
    }
    return ((viewportHeight - padding * 3) * value) / maxY;
  }

  double get minX =>
      _graphPoints.map((e) => e.x.abs()).toList().reduce(math.min);

  double get _maxXExtent =>
      _graphPoints.map((e) => e.x.abs()).toList().reduce(math.max);

  bool get verticalMinIsNegative => minY.isNegative;

  double get minY => _graphPoints.map((e) => e.y).toList().reduce(math.min);

  double get maxY => _graphPoints.map((e) => e.y).toList().reduce(math.max);

  bool numberIsBetween(num first, num end, num value) {
    return value >= first && value <= end;
  }

  Offset pointToOffset(GraphPoint point) => Offset(point.x, point.y);

  GraphPoint offsetToGraphPoint(Offset offset) =>
      GraphPoint(y: offset.dy, x: offset.dx);
}

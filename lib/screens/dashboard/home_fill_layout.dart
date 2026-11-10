import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// HUB2 (3): lays [top] out at its own height, then [fill] [gap] under it, as
/// tall as what is left of [viewportHeight] allows, never more than
/// [maxHeight]. With less than [minHeight] left, [fill] is laid out at no
/// height (build it through a LayoutBuilder that draws nothing then), so the
/// top never shrinks and Home scrolls only when the top alone does not fit.
///
/// The height is decided from the room alone, before any data, so the
/// region keeps its place while its pages load. A scroll view around it
/// gives no height of its own, hence [viewportHeight].
class HomeFillLayout extends MultiChildRenderObjectWidget {
  final double viewportHeight;
  final double minHeight;
  final double maxHeight;
  final double gap;

  HomeFillLayout({
    super.key,
    required this.viewportHeight,
    required this.minHeight,
    required this.maxHeight,
    required this.gap,
    required Widget top,
    required Widget fill,
  }) : super(children: [top, fill]);

  @override
  RenderHomeFill createRenderObject(BuildContext context) =>
      RenderHomeFill(viewportHeight: viewportHeight, minHeight: minHeight, maxHeight: maxHeight, gap: gap);

  @override
  void updateRenderObject(BuildContext context, RenderHomeFill renderObject) => renderObject
    ..viewportHeight = viewportHeight
    ..minHeight = minHeight
    ..maxHeight = maxHeight
    ..gap = gap;
}

class _FillParentData extends ContainerBoxParentData<RenderBox> {}

class RenderHomeFill extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _FillParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _FillParentData> {
  RenderHomeFill({required double viewportHeight, required double minHeight, required double maxHeight, required double gap})
      : _viewportHeight = viewportHeight,
        _minHeight = minHeight,
        _maxHeight = maxHeight,
        _gap = gap;

  double _viewportHeight, _minHeight, _maxHeight, _gap;

  set viewportHeight(double v) => _set(_viewportHeight, v, () => _viewportHeight = v);
  set minHeight(double v) => _set(_minHeight, v, () => _minHeight = v);
  set maxHeight(double v) => _set(_maxHeight, v, () => _maxHeight = v);
  set gap(double v) => _set(_gap, v, () => _gap = v);

  void _set(double old, double v, VoidCallback assign) {
    if (old == v) return;
    assign();
    markNeedsLayout();
  }

  /// Whether the region was given room at the last layout.
  bool fillShown = false;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _FillParentData) child.parentData = _FillParentData();
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final top = firstChild!;
    final fill = childAfter(top)!;
    top.layout(BoxConstraints(minWidth: width, maxWidth: width), parentUsesSize: true);
    (top.parentData! as _FillParentData).offset = Offset.zero;
    final room = _viewportHeight - top.size.height - _gap;
    fillShown = room >= _minHeight;
    final height = fillShown ? math.min(room, _maxHeight) : 0.0;
    fill.layout(BoxConstraints.tightFor(width: width, height: height), parentUsesSize: true);
    (fill.parentData! as _FillParentData).offset = Offset(0, top.size.height + (fillShown ? _gap : 0));
    size = constraints.constrain(Size(width, top.size.height + (fillShown ? _gap + height : 0)));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

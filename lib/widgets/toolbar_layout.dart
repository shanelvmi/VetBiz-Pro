import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_dimens.dart';
import '../theme/polish_metrics.dart';

/// LAY6a: a record screen's toolbar: the search field and its filters and
/// buttons. While the filters fit beside a search of at least
/// [DetailsLayoutMetrics.searchMinWidth] they share one line, the search
/// taking the rest (as the Row it replaces); otherwise the search takes the
/// whole first line and the filters wrap under it (LAYOUT_DEFECTS #14, #15:
/// the Row overflowed a narrow list and at text 1.3). Layout only: the same
/// children in the same order.
class ToolbarLayout extends StatelessWidget {
  const ToolbarLayout({super.key, required this.search, required this.filters});

  final Widget search;
  final List<Widget> filters;

  @override
  Widget build(BuildContext context) => _Toolbar(children: [
        search,
        Wrap(
          spacing: AppSpacing.s10,
          runSpacing: AppSpacing.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: filters,
        ),
      ]);
}

class _Toolbar extends MultiChildRenderObjectWidget {
  const _Toolbar({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderToolbar();
}

class _ToolbarParentData extends ContainerBoxParentData<RenderBox> {}

/// Children: the search, then the filters (a Wrap). The filters are laid out
/// first at their natural width (wrapping only past the whole width); the
/// search then takes the rest of the line, or the whole first line.
class _RenderToolbar extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _ToolbarParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _ToolbarParentData> {
  static const double _gap = AppSpacing.s10;
  static const double _lineGap = AppSpacing.s8;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ToolbarParentData) child.parentData = _ToolbarParentData();
  }

  @override
  void performLayout() {
    final search = firstChild!;
    final filters = childAfter(search)!;
    final width = constraints.maxWidth;
    filters.layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
    final room = width - filters.size.width - _gap;
    final searchData = search.parentData! as _ToolbarParentData;
    final filtersData = filters.parentData! as _ToolbarParentData;
    if (filters.size.width > 0 && room >= DetailsLayoutMetrics.searchMinWidth) {
      search.layout(BoxConstraints.tightFor(width: room), parentUsesSize: true);
      final h = search.size.height > filters.size.height ? search.size.height : filters.size.height;
      searchData.offset = Offset(0, (h - search.size.height) / 2);
      filtersData.offset = Offset(width - filters.size.width, (h - filters.size.height) / 2);
      size = constraints.constrain(Size(width, h));
    } else {
      search.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
      searchData.offset = Offset.zero;
      filtersData.offset = Offset(0, search.size.height + _lineGap);
      size = constraints.constrain(Size(width, search.size.height + _lineGap + filters.size.height));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

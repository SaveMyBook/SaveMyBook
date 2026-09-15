import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// 需放在捲動內容最上方且高度被撐滿（例如 Stack 內的 Positioned(top: 0, bottom: 0)），位移才會與捲動量一致。
class StickyPane extends SingleChildRenderObjectWidget {
  final ScrollController controller;

  const StickyPane({super.key, required this.controller, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStickyPane(controller);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderStickyPane).controller = controller;
  }
}

class _RenderStickyPane extends RenderShiftedBox {
  _RenderStickyPane(this._controller) : super(null);

  ScrollController _controller;

  set controller(ScrollController value) {
    if (value == _controller) return;
    if (attached) _controller.removeListener(_reposition);
    _controller = value;
    if (attached) _controller.addListener(_reposition);
    _reposition();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(_reposition);
  }

  @override
  void detach() {
    _controller.removeListener(_reposition);
    super.detach();
  }

  double get _shift {
    final child = this.child;
    if (child == null || !hasSize || !_controller.hasClients || _controller.positions.length != 1) return 0;
    final room = math.max(0.0, size.height - child.size.height);
    return _controller.offset.clamp(0.0, room);
  }

  void _reposition() {
    final child = this.child;
    if (child == null || !hasSize) return;
    final data = child.parentData! as BoxParentData;
    final next = Offset(0, _shift);
    if (data.offset == next) return;
    data.offset = next;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(BoxConstraints.tightFor(width: constraints.maxWidth), parentUsesSize: true);
    size = constraints.constrain(Size(constraints.maxWidth, child.size.height));
    (child.parentData! as BoxParentData).offset = Offset(0, _shift);
  }
}

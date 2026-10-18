import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';

/// 마우스를 올리거나 손가락을 대고 있는 동안 [child] 위에 [detail] 말풍선을 띄운다. 떼거나 벗어나면 닫힌다.
/// 그래프 툴팁과 같은 느낌으로, 누르기(탭)를 따로 하지 않아도 된다.
/// 손가락을 대고 위아래로 끌면 목록 스크롤로 보고 닫는다.
class HoverDetail extends StatefulWidget {
  const HoverDetail({super.key, required this.child, required this.detail});

  final Widget child;
  final Widget detail;

  @override
  State<HoverDetail> createState() => _HoverDetailState();
}

class _HoverDetailState extends State<HoverDetail> {
  final _controller = OverlayPortalController();
  final _link = LayerLink();
  Offset? _downAt;

  void _show() {
    if (!_controller.isShowing) _controller.show();
  }

  void _hide() {
    _downAt = null;
    if (_controller.isShowing) _controller.hide();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (context) => Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _link,
            // 손가락에 가리지 않게 위쪽에 띄운다.
            targetAnchor: Alignment.topCenter,
            followerAnchor: Alignment.bottomCenter,
            offset: const Offset(0, -6),
            child: IgnorePointer(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: DefaultTextStyle(
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      child: widget.detail,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child: MouseRegion(
          onEnter: (_) => _show(),
          onExit: (_) => _hide(),
          child: Listener(
            onPointerDown: (event) {
              _downAt = event.position;
              _show();
            },
            onPointerMove: (event) {
              final start = _downAt;
              if (start != null && (event.position.dy - start.dy).abs() > 12) _hide();
            },
            onPointerUp: (event) {
              // 마우스는 올려 둔 동안 계속 보인다. 손가락은 떼면 닫는다.
              if (event.kind != PointerDeviceKind.mouse) _hide();
            },
            onPointerCancel: (_) => _hide(),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

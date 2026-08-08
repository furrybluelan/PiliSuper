import 'package:PiliPlus/utils/device_utils.dart';
import 'package:flutter/gestures.dart' show kBackMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent;

class BackDetector extends StatelessWidget {
  const BackDetector({
    super.key,
    required this.onBack,
    required this.child,
  });

  final Widget child;

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        behavior: .translucent,
        onPointerDown: _onPointerDown,
        child: child,
      ),
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event.logicalKey == .escape && event is KeyDownEvent) {
      // TV 上系统返回键也上报为 escape。若当前焦点在输入框里，优先 unfocus
      // 退出编辑模式，而不是 pop 页面——否则遥控器用户无法从输入框离开。
      if (DeviceUtils.isTV) {
        final focused = FocusManager.instance.primaryFocus;
        if (focused != null && focused.context?.widget is EditableText) {
          focused.unfocus();
          return .handled;
        }
      }
      onBack();
      return .handled;
    }
    return .ignored;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons == kBackMouseButton) {
      onBack();
    }
  }
}

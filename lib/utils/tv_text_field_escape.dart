import 'package:PiliPlus/common/widgets/flutter/text_field/editable_text.dart'
    as rich show EditableText;
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyRepeatEvent, LogicalKeyboardKey;

/// 让遥控器的方向键能把焦点移出输入框。
///
/// 输入框获焦后四个方向键全部失效，根因在 framework：`EditableText` 把
/// `DirectionalFocusIntent` 绑到了 `DirectionalFocusAction.forTextField()`
/// (editable_text.dart)，而该 Intent 的 `ignoreTextFields` 默认为 true
/// (focus_traversal.dart:2382)，于是 `invoke` 里
/// `!intent.ignoreTextFields || !_isForTextField` 恒为假，
/// `focusInDirection` 永远不会被调用 (focus_traversal.dart:2420-2424)。
/// 方向键既没有移动焦点、也没有落到任何祖先，静默消失。
///
/// 触屏/物理键盘上这是合理设计（方向键移动光标，Tab 切焦点），但遥控器没有 Tab
/// 键，方向键是唯一的导航手段，用户会被永久困在输入框里。
///
/// 为什么用 [FocusManager.addEarlyKeyEventHandler] 而不是包一层 `Focus`：
/// `FocusManager.handleKeyMessage` 先跑 early handler，之后才从
/// `[primaryFocus, ...ancestors]` 由叶到根遍历 `onKeyEvent`
/// (focus_manager.dart:2233, 2258-2264)。而 `Shortcuts` 自身只是这条链上一个
/// `canRequestFocus: false` 的 `Focus` 节点 (shortcuts.dart:1139-1142)，任何
/// 位于 `WidgetsApp` 之上的包装都比它更靠根、更晚执行，拦不住已经查表命中的
/// 快捷键。early handler 是唯一先于整条链的公开钩子，因此也是唯一能一处覆盖
/// 全部输入框（评论、弹幕、搜索及各类对话框）的位置。
abstract final class TvTextFieldEscape {
  static bool _installed = false;

  /// 仅在 TV 上安装；重复调用是安全的。
  static void install() {
    if (!DeviceUtils.isTV || _installed) return;
    FocusManager.instance.addEarlyKeyEventHandler(_handle);
    _installed = true;
  }

  /// 取出当前聚焦输入框的 controller，非输入框返回 null。
  ///
  /// 本项目把 framework 的 `EditableText` fork 成了
  /// `common/widgets/flutter/text_field/editable_text.dart`，两者同名但**是不同
  /// 类型**：评论、弹幕、私信等富文本输入走 fork 版，搜索框与各类设置对话框走
  /// 原版。只认其中一种会漏掉另一半输入框，因此两种都要匹配。
  static ({TextEditingController controller, bool isMultiline})? _inputOf(
    Widget? widget,
  ) => switch (widget) {
    EditableText(:final controller, :final maxLines) => (
      controller: controller,
      isMultiline: maxLines != 1,
    ),
    rich.EditableText(:final controller, :final maxLines) => (
      controller: controller,
      isMultiline: maxLines != 1,
    ),
    _ => null,
  };

  static KeyEventResult _handle(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;

    final focused = FocusManager.instance.primaryFocus;
    // 只在焦点确实落在输入框里时介入，其余场景保持 framework 默认行为。
    final input = _inputOf(focused?.context?.widget);
    if (input == null) return KeyEventResult.ignored;

    // 光标还能在文本内移动时不跳出，否则用户无法在已输入的内容里定位。
    // 单行框纵向无处可去，直接交还遍历；多行框（如 maxLines: 8 的评论框）需要
    // 上下键换行，只有停在首/末行时才跳出。
    final selection = input.controller.selection;
    final text = input.controller.text;
    if (selection.isCollapsed) {
      final offset = selection.baseOffset;
      final bool atEdge = switch (direction) {
        TraversalDirection.left => offset <= 0,
        TraversalDirection.right => offset >= text.length,
        TraversalDirection.up =>
          !input.isMultiline ||
              offset <= 0 ||
              text.lastIndexOf('\n', offset - 1) < 0,
        TraversalDirection.down =>
          !input.isMultiline || offset < 0 || text.indexOf('\n', offset) < 0,
      };
      if (!atEdge) return KeyEventResult.ignored;
    } else if (direction == TraversalDirection.left ||
        direction == TraversalDirection.right) {
      // 有选区时左右键用于收起选区，交给输入框自己处理。
      return KeyEventResult.ignored;
    }

    focused!.focusInDirection(direction);
    return KeyEventResult.handled;
  }
}

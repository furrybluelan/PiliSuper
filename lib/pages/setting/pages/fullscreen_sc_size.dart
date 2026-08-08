import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/common/widgets/extra_hittest_stack.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models_new/live/live_superchat/item.dart';
import 'package:PiliPlus/pages/live_room/superchat/superchat_card.dart';
import 'package:PiliPlus/plugin/pl_player/utils/fullscreen.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyRepeatEvent, LogicalKeyboardKey;

const kFullScreenSCWidth = 255.0;

class FullScreenScSize extends StatefulWidget {
  const FullScreenScSize({super.key});

  @override
  State<FullScreenScSize> createState() => _FullScreenScSizeState();
}

class _FullScreenScSizeState extends State<FullScreenScSize> {
  double _width = Pref.fullScreenSCWidth;
  final _randomSC = SuperChatItem.random;
  late EdgeInsets _padding;
  late double _maxWidth;
  late ColorScheme _colorScheme;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      landscapeLeftMode();
    } else if (Platform.isIOS) {
      landscapeRightMode();
    }
  }

  @override
  void dispose() {
    if (PlatformUtils.isMobile) {
      if (Pref.horizontalScreen) {
        fullMode();
      } else {
        portraitUpMode();
      }
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final padding = MediaQuery.viewPaddingOf(context);
    _padding = .only(
      right: padding.right + 17,
      left: padding.left + 25,
      bottom: padding.bottom + 25,
    );
    _colorScheme = ColorScheme.of(context);
    // 拖拽路径的上界由手指离开屏幕自然形成，按键路径没有这个物理约束，需要显式
    // 取可用宽度作为上限，否则长按右键会把卡片撑出屏幕。
    _maxWidth = MediaQuery.sizeOf(context).width - _padding.horizontal;
  }

  void _onReset() {
    _width = kFullScreenSCWidth;
    GStorage.setting.delete(SettingBoxKey.fullScreenSCWidth);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('全屏 SC 大小设置'),
        actions: [
          TextButton(onPressed: _onReset, child: const Text('重置')),
        ],
      ),
      body: Padding(padding: _padding, child: _buildBody),
    );
  }

  Widget get _buildBody {
    return Align(
      alignment: .bottomLeft,
      child: ExtraHitTestStack(
        clipBehavior: .none,
        children: [
          SizedBox(
            width: _width,
            child: IgnorePointer(
              child: SuperChatCard(
                item: _randomSC,
                persistentSC: true,
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: -17,
            width: 34,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeRight,
              child: GestureDetector(
                behavior: .opaque,
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                child: Focus(
                  // 拖拽手柄原本只响应指针拖动，遥控器没有指针，TV 上完全无法
                  // 调整。这里给它一个焦点节点，左右键按步长增减宽度；上下键返回
                  // ignored 交还焦点遍历，避免困在手柄上出不去。
                  autofocus: DeviceUtils.isTV,
                  onKeyEvent: DeviceUtils.isTV ? _onHandleKey : null,
                  child: Builder(
                    builder: (context) {
                      final hasFocus = Focus.of(context).hasFocus;
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          shape: .circle,
                          color: _colorScheme.secondaryContainer.withValues(
                            alpha: .8,
                          ),
                          border: hasFocus
                              ? Border.all(
                                  color: _colorScheme.primary,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Icon(
                          size: 18,
                          CustomIcons.open_in_full_rotate_45,
                          color: _colorScheme.onSecondaryContainer,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _width = math.max(25.0, _width + details.delta.dx);
    setState(() {});
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    GStorage.setting.put(SettingBoxKey.fullScreenSCWidth, _width);
  }

  static const _kStep = 10.0;

  KeyEventResult _onHandleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final isLeft = key == LogicalKeyboardKey.arrowLeft;
    if (isLeft || key == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _width = (_width + (isLeft ? -_kStep : _kStep)).clamp(25.0, _maxWidth);
      });
      GStorage.setting.put(SettingBoxKey.fullScreenSCWidth, _width);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

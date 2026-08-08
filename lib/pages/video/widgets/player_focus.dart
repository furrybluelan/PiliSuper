import 'dart:async';
import 'dart:io' show exit, Platform;
import 'dart:math' as math;

import 'package:PiliPlus/pages/common/common_intro_controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyUpEvent, LogicalKeyboardKey, HardwareKeyboard;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class PlayerFocus extends StatelessWidget {
  const PlayerFocus({
    super.key,
    required this.child,
    required this.plPlayerController,
    this.introController,
    required this.onSendDanmaku,
    this.canPlay,
    this.onSkipSegment,
    this.onRefresh,
  });

  final Widget child;
  final PlPlayerController plPlayerController;
  final CommonIntroController? introController;
  final VoidCallback onSendDanmaku;
  final ValueGetter<bool>? canPlay;
  final ValueGetter<bool>? onSkipSegment;
  final VoidCallback? onRefresh;

  static bool _isDirectional(LogicalKeyboardKey logicalKey) {
    return logicalKey == LogicalKeyboardKey.arrowLeft ||
        logicalKey == LogicalKeyboardKey.arrowRight ||
        logicalKey == LogicalKeyboardKey.arrowUp ||
        logicalKey == LogicalKeyboardKey.arrowDown;
  }

  static bool _isVertical(LogicalKeyboardKey logicalKey) {
    return logicalKey == LogicalKeyboardKey.arrowUp ||
        logicalKey == LogicalKeyboardKey.arrowDown;
  }

  static bool _shouldHandle(LogicalKeyboardKey logicalKey) {
    return logicalKey == LogicalKeyboardKey.tab ||
        _isDirectional(logicalKey);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      // TV 上非全屏时不抢焦点，否则遥控器无法移动到简介/评论等区域。
      autofocus: !DeviceUtils.isTV,
      // TV 横屏下简介区和播放器是同一 Row 的兄弟节点，D-pad 可以导航到播放器
      // 区域。获焦时强制显示控制栏，让遥控器能看到并操作播放/暂停等按钮；
      // 失焦时若播放中则隐藏控制栏（恢复正常隐藏逻辑）。
      onFocusChange: DeviceUtils.isTV
          ? (hasFocus) {
              if (hasFocus && !isFullScreen) {
                plPlayerController.controls = true;
              } else if (!hasFocus &&
                  !isFullScreen &&
                  plPlayerController.playerStatus.value.isPlaying) {
                plPlayerController.controls = false;
              }
            }
          : null,
      onKeyEvent: (node, event) {
        // 该 widget 包裹的是整个视频页（含简介、评论、播放列表），而非仅播放器
        // 画面。在 TV 上方向键同时是 D-pad 导航键，若一律吞掉，遥控器将无法移出
        // 播放器，整页陷入死锁。
        if (DeviceUtils.isTV) {
          final key = event.logicalKey;
          // 上下键：任何情况（含全屏）都放行给焦点遍历。遥控器有独立音量键，
          // 上下键专职纵向导航 —— 画面 → 顶栏（返回/主页/听视频）、画面 → 底栏。
          if (_isVertical(key)) {
            // 顶/底栏虽始终 mounted，但控件隐藏时被 SlideTransition 滑出屏幕，
            // 焦点落上去用户看不见。放行前先显示控制栏。
            if (event is KeyDownEvent) {
              plPlayerController.controls = true;
            }
            return KeyEventResult.ignored;
          }
          // 左右键：非全屏时放行给 D-pad 导航；全屏时保留快进/快退。
          if (!isFullScreen && _isDirectional(key)) {
            return KeyEventResult.ignored;
          }
        }
        final handled = _handleKey(event);
        if (handled || _shouldHandle(event.logicalKey)) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }

  bool get isFullScreen => plPlayerController.isFullScreen.value;
  bool get hasPlayer => plPlayerController.videoPlayerController != null;

  void _setVolume({required bool isIncrease}) {
    final volume = isIncrease
        ? math.min(
            plPlayerController.maxVolume,
            plPlayerController.volume.value + 0.1,
          )
        : math.max(0.0, plPlayerController.volume.value - 0.1);
    plPlayerController.setVolume(volume);
  }

  void _updateVolume(KeyEvent event, {required bool isIncrease}) {
    if (event is KeyDownEvent) {
      if (hasPlayer) {
        _setVolume(isIncrease: isIncrease);
        plPlayerController
          ..longPressTimer?.cancel()
          ..longPressTimer = Timer.periodic(
            const Duration(milliseconds: 150),
            (_) => _setVolume(isIncrease: isIncrease),
          );
      }
    } else if (event is KeyUpEvent) {
      plPlayerController.cancelLongPressTimer();
    }
  }

  bool _handleKey(KeyEvent event) {
    final key = event.logicalKey;

    final isKeyQ = key == LogicalKeyboardKey.keyQ;
    if (isKeyQ || key == LogicalKeyboardKey.keyR) {
      if (HardwareKeyboard.instance.isMetaPressed) {
        if (isKeyQ && Platform.isMacOS) {
          exit(0);
        }
        return true;
      }
      if (event is KeyDownEvent) {
        if (plPlayerController.isLive) {
          onRefresh?.call();
        } else {
          introController!.onStartTriple();
        }
      } else if (event is KeyUpEvent && !plPlayerController.isLive) {
        introController!.onCancelTriple(isKeyQ);
      }
      return true;
    } else if (event is KeyDownEvent) {
      if (introController?.isTripling ?? false) {
        introController!.onCancelTriple();
      }
    }

    final isArrowUp = key == LogicalKeyboardKey.arrowUp;
    if (isArrowUp || key == LogicalKeyboardKey.arrowDown) {
      _updateVolume(event, isIncrease: isArrowUp);
      return true;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (!plPlayerController.isLive) {
        if (event is KeyDownEvent) {
          if (hasPlayer && !plPlayerController.longPressStatus.value) {
            plPlayerController
              ..longPressTimer?.cancel()
              ..longPressTimer = Timer(
                const Duration(milliseconds: 200),
                () => plPlayerController
                  ..cancelLongPressTimer()
                  ..setLongPressStatus(true),
              );
          }
        } else if (event is KeyUpEvent) {
          plPlayerController.cancelLongPressTimer();
          if (hasPlayer) {
            if (plPlayerController.longPressStatus.value) {
              plPlayerController.setLongPressStatus(false);
            } else {
              plPlayerController.onForward(
                plPlayerController.fastForBackwardDuration,
              );
            }
          }
        }
      }
      return true;
    }

    if (event is KeyDownEvent) {
      final isDigit1 = key == LogicalKeyboardKey.digit1;
      if (isDigit1 || key == LogicalKeyboardKey.digit2) {
        if (HardwareKeyboard.instance.isShiftPressed && hasPlayer) {
          final speed = isDigit1 ? 1.0 : 2.0;
          if (speed != plPlayerController.playbackSpeed) {
            plPlayerController.setPlaybackSpeed(speed);
          }
          SmartDialog.showToast('${speed}x播放');
        }
        return true;
      }

      switch (key) {
        case LogicalKeyboardKey.space:
          if (plPlayerController.isLive || canPlay!()) {
            if (hasPlayer) {
              plPlayerController.onDoubleTapCenter();
            }
          }
          return true;

        case LogicalKeyboardKey.keyF:
          final isFullScreen = this.isFullScreen;
          if (isFullScreen && plPlayerController.controlsLock.value) {
            plPlayerController
              ..controlsLock.value = false
              ..showControls.value = false;
          }
          plPlayerController.triggerFullScreen(
            status: !isFullScreen,
            inAppFullScreen: HardwareKeyboard.instance.isShiftPressed,
          );
          return true;

        case LogicalKeyboardKey.keyD:
          final newVal = !plPlayerController.enableShowDanmakuAdaptive.value;
          plPlayerController.enableShowDanmakuAdaptive.value = newVal;
          if (!plPlayerController.tempPlayerConf) {
            GStorage.setting.put(
              plPlayerController.isLive
                  ? SettingBoxKey.enableShowLiveDanmaku
                  : SettingBoxKey.enableShowDanmaku,
              newVal,
            );
          }
          return true;

        case LogicalKeyboardKey.keyP:
          if (PlatformUtils.isDesktop && hasPlayer && !isFullScreen) {
            plPlayerController
              ..toggleDesktopPip()
              ..controlsLock.value = false
              ..showControls.value = false;
          }
          return true;

        case LogicalKeyboardKey.keyM:
          if (hasPlayer) {
            final isMuted = !plPlayerController.isMuted;
            plPlayerController.videoPlayerController!.setVolume(
              isMuted ? 0 : plPlayerController.volume.value * 100,
            );
            plPlayerController.isMuted = isMuted;
            SmartDialog.showToast('${isMuted ? '' : '取消'}静音');
          }
          return true;

        case LogicalKeyboardKey.keyS:
          if (hasPlayer && isFullScreen) {
            plPlayerController.takeScreenshot();
          }
          return true;

        case LogicalKeyboardKey.keyL:
          if (isFullScreen || plPlayerController.isDesktopPip) {
            plPlayerController.onLockControl(
              !plPlayerController.controlsLock.value,
            );
          }
          return true;

        case LogicalKeyboardKey.enter:
          if (onSkipSegment?.call() ?? false) {
            return true;
          }
          onSendDanmaku();
          return true;

        // 遥控器「确定」键上报为 select 而非 enter。
        // 全屏时：直接触发播放/暂停。
        // 非全屏时：若焦点在播放器内（无其他可激活的 InkWell 获焦），触发播放/暂停；
        //   否则放行让 Flutter 的 ActivateAction 处理当前聚焦的控件。
        case LogicalKeyboardKey.select:
          if (onSkipSegment?.call() ?? false) {
            return true;
          }
          if (isFullScreen || DeviceUtils.isTV) {
            // 非全屏 TV 模式：只在焦点在播放器画面区（无 InkWell 获焦）时暂停；
            // 通过判断 primaryFocus 的祖先是否含有 InkWell 来放行。
            if (!isFullScreen) {
              final focused = FocusManager.instance.primaryFocus;
              // 若当前焦点节点是 InkWell/按钮类型，放行让 ActivateAction 处理。
              if (focused != null) {
                bool hasInkWell = false;
                focused.context?.visitAncestorElements((el) {
                  if (el.widget is InkWell ||
                      el.widget is TextButton ||
                      el.widget is IconButton ||
                      el.widget is FilledButton ||
                      el.widget is OutlinedButton) {
                    hasInkWell = true;
                    return false;
                  }
                  return true;
                });
                if (hasInkWell) return false;
              }
            }
            if (plPlayerController.isLive || canPlay!()) {
              if (hasPlayer) {
                plPlayerController.onDoubleTapCenter();
              }
            }
            return true;
          }
          return false;

        // 遥控器上的独立播放/暂停键，任何时候都应生效。
        case LogicalKeyboardKey.mediaPlayPause:
          if (plPlayerController.isLive || canPlay!()) {
            if (hasPlayer) {
              plPlayerController.onDoubleTapCenter();
            }
          }
          return true;
      }

      if (!plPlayerController.isLive) {
        switch (key) {
          case LogicalKeyboardKey.arrowLeft:
            if (hasPlayer) {
              plPlayerController.onBackward(
                plPlayerController.fastForBackwardDuration,
              );
            }
            return true;

          case LogicalKeyboardKey.keyW:
            if (HardwareKeyboard.instance.isMetaPressed) {
              return true;
            }
            introController?.actionCoinVideo();
            return true;

          case LogicalKeyboardKey.keyE:
            introController?.actionFavVideo(isQuick: true);
            return true;

          case LogicalKeyboardKey.keyT || LogicalKeyboardKey.keyV:
            introController?.viewLater();
            return true;

          case LogicalKeyboardKey.keyG:
            if (introController case final UgcIntroController ugcCtr) {
              ugcCtr.actionRelationMod(Get.context!);
            }
            return true;

          case LogicalKeyboardKey.bracketLeft:
            if (introController case final introController?) {
              if (!introController.prevPlay()) {
                SmartDialog.showToast('已经是第一集了');
              }
            }
            return true;

          case LogicalKeyboardKey.bracketRight:
            if (introController case final introController?) {
              if (!introController.nextPlay()) {
                SmartDialog.showToast('已经是最后一集了');
              }
            }
            return true;
        }
      }
    }

    return false;
  }
}

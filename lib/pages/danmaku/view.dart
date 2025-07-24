import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/pages/danmaku/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/utils/danmaku_utils.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 传入播放器控制器，监听播放进度，加载对应弹幕
class PlDanmaku extends StatefulWidget {
  final int cid;
  final PlPlayerController playerController;
  final bool? isPipMode;

  const PlDanmaku({
    super.key,
    required this.cid,
    required this.playerController,
    this.isPipMode,
  });

  @override
  State<PlDanmaku> createState() => _PlDanmakuState();
}

class _PlDanmakuState extends State<PlDanmaku> {
  PlPlayerController get playerController => widget.playerController;

  late PlDanmakuController _plDanmakuController;
  DanmakuController? _controller;
  int latestAddedPosition = -1;
  bool? _isFullScreen;
  StreamSubscription? _listenerFS;

  @override
  void initState() {
    super.initState();
    _plDanmakuController = PlDanmakuController(
      widget.cid,
      playerController,
    );
    if (playerController.enableShowDanmaku.value) {
      _plDanmakuController.queryDanmaku(
        _plDanmakuController.calcSegment(
          playerController.position.value.inMilliseconds,
        ),
      );
    }
    playerController
      ..addStatusLister(playerListener)
      ..addPositionListener(videoPositionListen);
    _listenerFS = playerController.isFullScreen.listen((isFullScreen) {
      if (isFullScreen != _isFullScreen) {
        _isFullScreen = isFullScreen;
        if (_controller != null) {
          _controller!.updateOption(
            _controller!.option.copyWith(
              fontSize: _getFontSize(isFullScreen),
            ),
          );
        }
      }
    });
  }

  // 播放器状态监听
  void playerListener(PlayerStatus? status) {
    if (status == PlayerStatus.playing) {
      _controller?.resume();
    } else {
      _controller?.pause();
    }
  }

  void videoPositionListen(Duration position) {
    if (!playerController.enableShowDanmaku.value) {
      return;
    }

    if (_controller == null) {
      return;
    }

    if (!playerController.showDanmaku && widget.isPipMode != true) {
      return;
    }

    if (playerController.playerStatus.status.value != PlayerStatus.playing) {
      return;
    }

    int currentPosition = position.inMilliseconds;
    currentPosition -= currentPosition % 100; //取整百的毫秒数
    if (currentPosition == latestAddedPosition) {
      return;
    }
    latestAddedPosition = currentPosition;

    List<DanmakuElem>? currentDanmakuList = _plDanmakuController
        .getCurrentDanmaku(currentPosition);
    if (currentDanmakuList != null) {
      for (DanmakuElem e in currentDanmakuList) {
        if (e.mode == 7) {
          try {
            _controller!.addDanmaku(
              SpecialDanmakuContentItem.fromList(
                DmUtils.decimalToColor(e.color),
                e.fontsize.toDouble(),
                jsonDecode(e.content.replaceAll('\n', '\\n')),
              ),
            );
          } catch (_) {}
        } else {
          _controller!.addDanmaku(
            DanmakuContentItem(
              e.content,
              color: playerController.blockTypes.contains(6)
                  ? Colors.white
                  : DmUtils.decimalToColor(e.color),
              type: DmUtils.getPosition(e.mode),
              isColorful:
                  playerController.showVipDanmaku &&
                      e.colorful == DmColorfulType.VipGradualColor
                  ? true
                  : null,
              count: e.hasCount() ? e.count : null,
              selfSend: e.isSelf,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _listenerFS?.cancel();
    playerController
      ..removePositionListener(videoPositionListen)
      ..removeStatusLister(playerListener);
    _plDanmakuController.dispose();
    super.dispose();
  }

  double _getFontSize(bool isFullScreen) =>
      !isFullScreen || widget.isPipMode == true
      ? 15 * playerController.danmakuFontScale
      : 15 * playerController.danmakuFontScaleFS;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // double initDuration = box.maxWidth / 12;
        return Obx(
          () => AnimatedOpacity(
            opacity: playerController.enableShowDanmaku.value ? 1 : 0,
            duration: const Duration(milliseconds: 100),
            child: DanmakuScreen(
              createdController: (DanmakuController e) {
                playerController.danmakuController = _controller = e;
              },
              option: DanmakuOption(
                fontSize: _getFontSize(playerController.isFullScreen.value),
                fontWeight: playerController.fontWeight,
                area: playerController.showArea,
                opacity: playerController.danmakuOpacity,
                hideTop: playerController.blockTypes.contains(5),
                hideScroll: playerController.blockTypes.contains(2),
                hideBottom: playerController.blockTypes.contains(4),
                duration:
                    playerController.danmakuDuration /
                    playerController.playbackSpeed,
                staticDuration:
                    playerController.danmakuStaticDuration /
                    playerController.playbackSpeed,
                strokeWidth: playerController.strokeWidth,
                lineHeight: playerController.danmakuLineHeight,
              ),
            ),
          ),
        );
      },
    );
  }
}

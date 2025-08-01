import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/models_new/live/live_room_info_h5/data.dart';
import 'package:PiliPlus/pages/live_room/controller.dart';
import 'package:PiliPlus/pages/live_room/send_danmaku/view.dart';
import 'package:PiliPlus/pages/live_room/widgets/bottom_control.dart';
import 'package:PiliPlus/pages/live_room/widgets/chat.dart';
import 'package:PiliPlus/pages/live_room/widgets/header_control.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/plugin/pl_player/view.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, SystemUiOverlayStyle;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:screen_brightness/screen_brightness.dart';

class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({super.key});

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage>
    with WidgetsBindingObserver {
  late final int _roomId;
  late final LiveRoomController _liveRoomController;
  late final PlPlayerController plPlayerController;
  late Future? _futureBuilderFuture;
  bool get isFullScreen => plPlayerController.isFullScreen.value;

  bool isShowCover = true;
  bool isPlay = true;

  StreamSubscription? _listener;

  int latestAddedPosition = -1;
  bool? _isFullScreen;
  bool? _isPipMode;

  void playCallBack() {
    plPlayerController.play();
  }

  late final String heroTag;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _roomId = int.parse(Get.parameters['roomid'] ?? '-1');
    heroTag = Utils.makeHeroTag(_roomId);
    _liveRoomController = Get.put(
      LiveRoomController(heroTag),
      tag: heroTag,
    );
    PlPlayerController.setPlayCallBack(playCallBack);
    videoSourceInit();
    _futureBuilderFuture = _liveRoomController.queryLiveInfo();
    plPlayerController
      ..autoEnterFullscreen()
      ..addStatusLister(playerListener);
    _listener = plPlayerController.isFullScreen.listen((isFullScreen) {
      if (isFullScreen != _isFullScreen) {
        _isFullScreen = isFullScreen;
        _updateFontSize();
      }
    });
  }

  void playerListener(PlayerStatus? status) {
    if (status != PlayerStatus.playing) {
      plPlayerController.danmakuController?.pause();
      _liveRoomController
        ..msgStream?.close()
        ..msgStream = null;
    } else {
      plPlayerController.danmakuController?.resume();
      _liveRoomController.liveMsg();
    }
  }

  Future<void> _updateFontSize() async {
    if (Platform.isAndroid) {
      _isPipMode = await const MethodChannel(
        "floating",
      ).invokeMethod('inPipAlready');
    }
    if (_liveRoomController.controller != null) {
      _liveRoomController.controller!.updateOption(
        _liveRoomController.controller!.option.copyWith(
          fontSize: _getFontSize(isFullScreen),
        ),
      );
    }
  }

  double _getFontSize(bool isFullScreen) {
    return isFullScreen == false || _isPipMode == true
        ? 15 * plPlayerController.danmakuFontScale
        : 15 * plPlayerController.danmakuFontScaleFS;
  }

  void videoSourceInit() {
    plPlayerController = _liveRoomController.plPlayerController;
  }

  @override
  void dispose() {
    videoPlayerServiceHandler.onVideoDetailDispose(heroTag);
    _listener?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    ScreenBrightness.instance.resetApplicationScreenBrightness();
    PlPlayerController.setPlayCallBack(null);
    _liveRoomController
      ..msgStream?.close()
      ..msgStream = null;
    plPlayerController
      ..removeStatusLister(playerListener)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _liveRoomController.showDanmaku = true;
    } else if (state == AppLifecycleState.paused) {
      _liveRoomController.showDanmaku = false;
      plPlayerController.danmakuController?.clear();
    }
  }

  final GlobalKey videoPlayerKey = GlobalKey();
  final GlobalKey playerKey = GlobalKey();

  Widget videoPlayerPanel({Color? fill, Alignment? alignment}) {
    return PopScope(
      canPop: !isFullScreen,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (isFullScreen) {
          plPlayerController.triggerFullScreen(status: false);
        }
      },
      child: FutureBuilder(
        key: videoPlayerKey,
        future: _futureBuilderFuture,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData && snapshot.data['status']) {
            final roomInfoH5 = _liveRoomController.roomInfoH5.value;
            return PLVideoPlayer(
              key: playerKey,
              fill: fill,
              alignment: alignment,
              plPlayerController: plPlayerController,
              headerControl: LiveHeaderControl(
                title: roomInfoH5?.roomInfo?.title,
                upName: roomInfoH5?.anchorInfo?.baseInfo?.uname,
                plPlayerController: plPlayerController,
                onSendDanmaku: onSendDanmaku,
                onPlayAudio: _liveRoomController.queryLiveInfo,
              ),
              bottomControl: BottomControl(
                plPlayerController: plPlayerController,
                liveRoomCtr: _liveRoomController,
                onRefresh: () {
                  _futureBuilderFuture = _liveRoomController.queryLiveInfo();
                },
              ),
              danmuWidget: Obx(
                () => AnimatedOpacity(
                  opacity: plPlayerController.enableShowDanmaku.value ? 1 : 0,
                  duration: const Duration(milliseconds: 100),
                  child: DanmakuScreen(
                    createdController: (DanmakuController e) {
                      plPlayerController.danmakuController =
                          _liveRoomController.controller = e;
                    },
                    option: DanmakuOption(
                      fontSize: _getFontSize(isFullScreen),
                      fontWeight: plPlayerController.fontWeight,
                      area: plPlayerController.showArea,
                      opacity: plPlayerController.danmakuOpacity,
                      hideTop: plPlayerController.blockTypes.contains(5),
                      hideScroll: plPlayerController.blockTypes.contains(2),
                      hideBottom: plPlayerController.blockTypes.contains(4),
                      duration:
                          plPlayerController.danmakuDuration /
                          plPlayerController.playbackSpeed,
                      staticDuration:
                          plPlayerController.danmakuStaticDuration /
                          plPlayerController.playbackSpeed,
                      strokeWidth: plPlayerController.strokeWidth,
                      lineHeight: plPlayerController.danmakuLineHeight,
                    ),
                  ),
                ),
              ),
            );
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  SystemUiOverlayStyle _systemOverlayStyleForBrightness(
    Brightness brightness, [
    Color? backgroundColor,
  ]) {
    final SystemUiOverlayStyle style = brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    // For backward compatibility, create an overlay style without system navigation bar settings.
    return SystemUiOverlayStyle(
      statusBarColor: backgroundColor,
      statusBarBrightness: style.statusBarBrightness,
      statusBarIconBrightness: style.statusBarIconBrightness,
      systemStatusBarContrastEnforced: style.systemStatusBarContrastEnforced,
    );
  }

  Widget childWhenDisabled(bool isPortrait) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemOverlayStyleForBrightness(
        Brightness.dark,
        Theme.of(context).useMaterial3 ? const Color(0x00000000) : null,
      ),
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Obx(
              () {
                if (isFullScreen) {
                  return const SizedBox.shrink();
                }
                final appBackground = _liveRoomController
                    .roomInfoH5
                    .value
                    ?.roomInfo
                    ?.appBackground;
                return Positioned.fill(
                  child: Opacity(
                    opacity: 0.6,
                    child: appBackground?.isNotEmpty == true
                        ? CachedNetworkImage(
                            fit: BoxFit.cover,
                            width: Get.width,
                            height: Get.height,
                            imageUrl: appBackground!.http2https,
                          )
                        : Image.asset(
                            'assets/images/live/default_bg.webp',
                            fit: BoxFit.cover,
                          ),
                  ),
                );
              },
            ),
            SafeArea(
              top: !isFullScreen,
              left: !isFullScreen,
              right: !isFullScreen,
              bottom: false,
              child: isPortrait
                  ? Obx(
                      () {
                        if (_liveRoomController.isPortrait.value) {
                          return _buildPP;
                        }
                        return _buildPH;
                      },
                    )
                  : Column(
                      children: [
                        Obx(() => _buildAppBar),
                        _buildBodyH,
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget get _buildPH => Column(
    children: [
      _buildAppBar,
      ..._buildBodyP,
    ],
  );

  Widget get _buildPP => Stack(
    clipBehavior: Clip.none,
    children: [
      _buildAppBar,
      Column(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Obx(
                  () => Container(
                    margin: isFullScreen
                        ? null
                        : const EdgeInsets.only(top: 56),
                    color: Colors.black,
                    child: videoPlayerPanel(
                      alignment: isFullScreen ? null : Alignment.topCenter,
                    ),
                  ),
                ),
                Obx(
                  () => isFullScreen
                      ? const SizedBox.shrink()
                      : Positioned(
                          left: 0,
                          right: 0,
                          bottom: 55,
                          child: SizedBox(
                            height: 125,
                            child: _buildChatWidget(true),
                          ),
                        ),
                ),
              ],
            ),
          ),
          Obx(() => isFullScreen ? const SizedBox.shrink() : _buildInputWidget),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateFontSize();
    });
    return OrientationBuilder(
      builder: (BuildContext context, Orientation orientation) {
        if (Platform.isAndroid) {
          return Floating().isPipMode
              ? videoPlayerPanel()
              : childWhenDisabled(orientation == Orientation.portrait);
        } else {
          return childWhenDisabled(orientation == Orientation.portrait);
        }
      },
    );
  }

  final Color _color = const Color(0xFFEEEEEE);

  PreferredSizeWidget get _buildAppBar {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      toolbarHeight: isFullScreen ? 0 : null,
      titleTextStyle: const TextStyle(color: Colors.white),
      title: Obx(
        () {
          RoomInfoH5Data? roomInfoH5 = _liveRoomController.roomInfoH5.value;
          return roomInfoH5 == null
              ? const SizedBox.shrink()
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      Get.toNamed('/member?mid=${roomInfoH5.roomInfo?.uid}'),
                  child: Row(
                    spacing: 10,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NetworkImgLayer(
                        width: 34,
                        height: 34,
                        type: ImageType.avatar,
                        src: roomInfoH5.anchorInfo!.baseInfo!.face,
                      ),
                      Column(
                        spacing: 1,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            roomInfoH5.anchorInfo!.baseInfo!.uname!,
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (roomInfoH5.watchedShow?.textLarge?.isNotEmpty ==
                              true)
                            Text(
                              roomInfoH5.watchedShow!.textLarge!,
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
        },
      ),
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: () =>
              _futureBuilderFuture = _liveRoomController.queryLiveInfo(),
          icon: const Icon(Icons.refresh, size: 20),
        ),
        PopupMenuButton(
          icon: const Icon(Icons.more_vert, size: 20),
          itemBuilder: (BuildContext context) => <PopupMenuEntry>[
            PopupMenuItem(
              onTap: () => PageUtils.inAppWebview(
                'https://live.bilibili.com/h5/${_liveRoomController.roomId}',
                off: true,
              ),
              child: Row(
                spacing: 10,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.open_in_browser,
                    size: 19,
                    color: color,
                  ),
                  const Text('浏览器打开'),
                ],
              ),
            ),
            if (_liveRoomController.roomInfoH5.value != null)
              PopupMenuItem(
                onTap: () {
                  try {
                    RoomInfoH5Data roomInfo =
                        _liveRoomController.roomInfoH5.value!;
                    PageUtils.pmShare(
                      this.context,
                      content: {
                        "cover": roomInfo.roomInfo!.cover!,
                        "sourceID": _liveRoomController.roomId.toString(),
                        "title": roomInfo.roomInfo!.title!,
                        "url":
                            "https://live.bilibili.com/${_liveRoomController.roomId}",
                        "authorID": roomInfo.roomInfo!.uid.toString(),
                        "source": "直播",
                        "desc": roomInfo.roomInfo!.title!,
                        "author": roomInfo.anchorInfo!.baseInfo!.uname,
                      },
                    );
                  } catch (e) {
                    SmartDialog.showToast(e.toString());
                  }
                },
                child: Row(
                  spacing: 10,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.forward_to_inbox,
                      size: 19,
                      color: color,
                    ),
                    const Text('分享至消息'),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget get _buildBodyH {
    double videoWidth =
        clampDouble(context.height / context.width * 1.08, 0.58, 0.75) *
        context.width;
    return Expanded(
      child: Row(
        children: [
          Obx(
            () => Container(
              margin: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              color: isFullScreen ? Colors.black : null,
              width: isFullScreen ? Get.size.width : videoWidth,
              height: isFullScreen ? Get.size.height : Get.size.width * 9 / 16,
              child: videoPlayerPanel(fill: Colors.transparent),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildBottomWidget,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> get _buildBodyP => [
    Obx(
      () => Container(
        color: Colors.black,
        width: Get.size.width,
        height: isFullScreen ? Get.size.height : Get.size.width * 9 / 16,
        child: videoPlayerPanel(),
      ),
    ),
    ..._buildBottomWidget,
  ];

  final GlobalKey chatKey = GlobalKey();

  List<Widget> get _buildBottomWidget => [
    Expanded(child: _buildChatWidget()),
    _buildInputWidget,
  ];

  Widget _buildChatWidget([bool? isPP]) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: LiveRoomChat(
      key: chatKey,
      isPP: isPP,
      roomId: _roomId,
      liveRoomController: _liveRoomController,
    ),
  );

  Widget get _buildInputWidget => Container(
    padding: EdgeInsets.only(
      top: 5,
      left: 10,
      right: 10,
      bottom: 15 + MediaQuery.paddingOf(context).bottom,
    ),
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      border: Border(
        top: BorderSide(color: Color(0x1AFFFFFF)),
      ),
      color: Color(0x1AFFFFFF),
    ),
    child: GestureDetector(
      onTap: onSendDanmaku,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 5, bottom: 10),
        child: Row(
          children: [
            Obx(
              () {
                final enableShowDanmaku =
                    plPlayerController.enableShowDanmaku.value;
                return IconButton(
                  onPressed: () {
                    final newVal = !enableShowDanmaku;
                    plPlayerController.enableShowDanmaku.value = newVal;
                    GStorage.setting.put(
                      SettingBoxKey.enableShowDanmaku,
                      newVal,
                    );
                  },
                  icon: Icon(
                    enableShowDanmaku
                        ? Icons.subtitles_outlined
                        : Icons.subtitles_off_outlined,
                    color: _color,
                  ),
                );
              },
            ),
            Expanded(
              child: Text(
                '发送弹幕',
                style: TextStyle(color: _color),
              ),
            ),
            IconButton(
              onPressed: () => onSendDanmaku(true),
              icon: Icon(Icons.emoji_emotions_outlined, color: _color),
            ),
          ],
        ),
      ),
    ),
  );

  void onSendDanmaku([bool fromEmote = false]) {
    if (!_liveRoomController.accountService.isLogin.value) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    Get.generalDialog(
      barrierLabel: '',
      barrierDismissible: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return LiveSendDmPanel(
          fromEmote: fromEmote,
          liveRoomController: _liveRoomController,
          items: _liveRoomController.savedDanmaku,
          onSave: (msg) {
            if (msg.isEmpty) {
              _liveRoomController
                ..savedDanmaku?.clear()
                ..savedDanmaku = null;
            } else {
              _liveRoomController.savedDanmaku = msg.toList();
            }
          },
        );
      },
      transitionDuration: const Duration(milliseconds: 500),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        var tween = Tween(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.linear));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
}

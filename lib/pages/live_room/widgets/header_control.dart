import 'dart:io';

import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class LiveHeaderControl extends StatelessWidget {
  const LiveHeaderControl({
    super.key,
    required this.title,
    required this.upName,
    required this.plPlayerController,
    required this.onSendDanmaku,
    required this.onPlayAudio,
  });

  final String? title;
  final String? upName;
  final PlPlayerController plPlayerController;
  final VoidCallback onSendDanmaku;
  final VoidCallback onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final isFullScreen = plPlayerController.isFullScreen.value;
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      primary: false,
      automaticallyImplyLeading: false,
      titleSpacing: 14,
      title: Row(
        spacing: 10,
        children: [
          if (isFullScreen)
            SizedBox(
              width: 35,
              height: 35,
              child: IconButton(
                tooltip: '返回',
                icon: const Icon(
                  FontAwesomeIcons.arrowLeft,
                  size: 15,
                ),
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                ),
                onPressed: () =>
                    plPlayerController.triggerFullScreen(status: false),
              ),
            ),
          if (title != null)
            Expanded(
              child: Column(
                spacing: 5,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title!,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1,
                      color: Colors.white,
                    ),
                  ),
                  if (isFullScreen && upName != null)
                    Text(
                      upName!,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            )
          else
            const Spacer(),
          SizedBox(
            width: 35,
            height: 35,
            child: IconButton(
              tooltip: '发弹幕',
              style: ButtonStyle(
                padding: WidgetStateProperty.all(EdgeInsets.zero),
              ),
              onPressed: onSendDanmaku,
              icon: const Icon(
                Icons.comment_outlined,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
          Obx(
            () {
              final onlyPlayAudio = plPlayerController.onlyPlayAudio.value;
              return SizedBox(
                width: 35,
                height: 35,
                child: IconButton(
                  onPressed: () {
                    plPlayerController.onlyPlayAudio.value = !onlyPlayAudio;
                    onPlayAudio();
                  },
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                  icon: onlyPlayAudio
                      ? const Icon(
                          size: 18,
                          MdiIcons.musicCircle,
                          color: Colors.white,
                        )
                      : const Icon(
                          size: 18,
                          MdiIcons.musicCircleOutline,
                          color: Colors.white,
                        ),
                ),
              );
            },
          ),
          if (Platform.isAndroid)
            SizedBox(
              width: 35,
              height: 35,
              child: IconButton(
                tooltip: '画中画',
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                ),
                onPressed: () async {
                  try {
                    var floating = Floating();
                    if ((await floating.isPipAvailable) == true) {
                      plPlayerController.hiddenControls(false);
                      floating.enable(
                        plPlayerController.isVertical
                            ? const EnableManual(
                                aspectRatio: Rational.vertical(),
                              )
                            : const EnableManual(),
                      );
                    }
                  } catch (_) {}
                },
                icon: const Icon(
                  Icons.picture_in_picture_outlined,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          SizedBox(
            width: 35,
            height: 35,
            child: IconButton(
              tooltip: '定时关闭',
              style: ButtonStyle(
                padding: WidgetStateProperty.all(EdgeInsets.zero),
              ),
              onPressed: () => PageUtils.scheduleExit(
                context,
                plPlayerController.isFullScreen.value,
                true,
              ),
              icon: const Icon(
                size: 18,
                Icons.schedule,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

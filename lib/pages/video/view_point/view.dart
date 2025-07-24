import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/progress_bar/segment_progress_bar.dart';
import 'package:PiliPlus/pages/common/common_collapse_slide_page.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/duration_util.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ViewPointsPage extends CommonCollapseSlidePage {
  const ViewPointsPage({
    super.key,
    super.enableSlide,
    required this.videoDetailController,
    required this.plPlayerController,
  });

  final VideoDetailController videoDetailController;
  final PlPlayerController? plPlayerController;

  @override
  State<ViewPointsPage> createState() => _ViewPointsPageState();
}

class _ViewPointsPageState
    extends CommonCollapseSlidePageState<ViewPointsPage> {
  VideoDetailController get videoDetailController =>
      widget.videoDetailController;
  PlPlayerController? get plPlayerController => widget.plPlayerController;

  int currentIndex = -1;

  @override
  Widget buildPage(ThemeData theme) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: const Text('分段信息'),
        toolbarHeight: 45,
        actions: [
          const Text(
            '分段进度条',
            style: TextStyle(fontSize: 16),
          ),
          Obx(
            () => Transform.scale(
              alignment: Alignment.centerLeft,
              scale: 0.8,
              child: Switch(
                thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                  if (states.isNotEmpty &&
                      states.first == WidgetState.selected) {
                    return const Icon(Icons.done);
                  }
                  return null;
                }),
                value: videoDetailController.plPlayerController.showVP.value,
                onChanged: (value) {
                  videoDetailController.plPlayerController.showVP.value = value;
                },
              ),
            ),
          ),
          iconButton(
            context: context,
            size: 30,
            icon: Icons.clear,
            tooltip: '关闭',
            onPressed: Get.back,
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: theme.dividerColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      body: enableSlide ? slideList(theme) : buildList(theme),
    );
  }

  @override
  Widget buildList(ThemeData theme) {
    final divider = Divider(
      height: 1,
      color: theme.dividerColor.withValues(alpha: 0.1),
    );
    return ListView.separated(
      controller: ScrollController(),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 80,
      ),
      itemCount: videoDetailController.viewPointList.length,
      itemBuilder: (context, index) {
        Segment segment = videoDetailController.viewPointList[index];
        if (currentIndex == -1 && segment.from != null && segment.to != null) {
          final positionSeconds =
              videoDetailController.plPlayerController.positionSeconds.value;
          if (positionSeconds >= segment.from! &&
              positionSeconds < segment.to!) {
            currentIndex = index;
          }
        }
        return ListTile(
          dense: true,
          onTap: segment.from != null
              ? () {
                  currentIndex = index;
                  plPlayerController?.danmakuController?.clear();
                  plPlayerController?.videoPlayerController?.seek(
                    Duration(seconds: segment.from!),
                  );
                  Get.back();
                }
              : null,
          leading: segment.url?.isNotEmpty == true
              ? Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: currentIndex == index
                      ? BoxDecoration(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(6),
                          ),
                          border: Border.all(
                            width: 1.8,
                            strokeAlign: BorderSide.strokeAlignOutside,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : null,
                  child: LayoutBuilder(
                    builder: (context, constraints) => NetworkImgLayer(
                      radius: 6,
                      src: segment.url,
                      width: constraints.maxHeight * StyleString.aspectRatio,
                      height: constraints.maxHeight,
                    ),
                  ),
                )
              : null,
          title: Text(
            segment.title ?? '',
            style: TextStyle(
              fontSize: 14,
              fontWeight: currentIndex == index ? FontWeight.bold : null,
              color: currentIndex == index ? theme.colorScheme.primary : null,
            ),
          ),
          subtitle: Text(
            '${segment.from != null ? DurationUtil.formatDuration(segment.from) : ''} - ${segment.to != null ? DurationUtil.formatDuration(segment.to) : ''}',
            style: TextStyle(
              fontSize: 13,
              color: currentIndex == index
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
        );
      },
      separatorBuilder: (context, index) => divider,
    );
  }
}

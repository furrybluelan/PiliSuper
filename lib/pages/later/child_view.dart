import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/skeleton/video_card_h.dart';
import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/refresh_indicator.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/later_view_type.dart';
import 'package:PiliPlus/models_new/later/list.dart';
import 'package:PiliPlus/pages/later/controller.dart';
import 'package:PiliPlus/pages/later/widgets/video_card_h_later.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LaterViewChildPage extends StatefulWidget {
  const LaterViewChildPage({
    super.key,
    required this.laterViewType,
  });

  final LaterViewType laterViewType;

  @override
  State<LaterViewChildPage> createState() => _LaterViewChildPageState();
}

class _LaterViewChildPageState extends State<LaterViewChildPage>
    with AutomaticKeepAliveClientMixin {
  late final LaterController _laterController = Get.put(
    LaterController(widget.laterViewType),
    tag: widget.laterViewType.type.toString(),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return refreshIndicator(
      onRefresh: _laterController.onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _laterController.scrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: 7,
              bottom: MediaQuery.paddingOf(context).bottom + 85,
            ),
            sliver: Obx(
              () => _buildBody(_laterController.loadingState.value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(LoadingState<List<LaterItemModel>?> loadingState) {
    final theme = Theme.of(context);
    return switch (loadingState) {
      Loading() => SliverGrid(
        gridDelegate: Grid.videoCardHDelegate(context),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return const VideoCardHSkeleton();
          },
          childCount: 10,
        ),
      ),
      Success(:var response) =>
        response?.isNotEmpty == true
            ? SliverGrid(
                gridDelegate: Grid.videoCardHDelegate(context),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == response.length - 1) {
                      _laterController.onLoadMore();
                    }
                    var videoItem = response[index];
                    final enableMultiSelect =
                        _laterController.baseCtr.enableMultiSelect.value;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        VideoCardHLater(
                          videoItem: videoItem,
                          onViewLater: (cid) {
                            PageUtils.toVideoPage(
                              'bvid=${videoItem.bvid}&cid=$cid',
                              arguments: {
                                'videoItem': videoItem,
                                'oid': videoItem.aid,
                                'heroTag': Utils.makeHeroTag(videoItem.bvid),
                                'sourceType': 'watchLater',
                                'count': _laterController
                                    .baseCtr
                                    .counts[LaterViewType.all],
                                'favTitle': '稍后再看',
                                'mediaId': _laterController.accountService.mid,
                                'desc': false,
                                'isContinuePlaying': index != 0,
                              },
                            );
                          },
                          onTap: !enableMultiSelect
                              ? null
                              : () => _laterController.onSelect(videoItem),
                          onLongPress: () {
                            if (!enableMultiSelect) {
                              _laterController.baseCtr.enableMultiSelect.value =
                                  true;
                              _laterController.onSelect(videoItem);
                            }
                          },
                        ),
                        Positioned(
                          top: 5,
                          left: 12,
                          bottom: 5,
                          child: IgnorePointer(
                            child: LayoutBuilder(
                              builder: (context, constraints) => AnimatedOpacity(
                                opacity: videoItem.checked == true ? 1 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  alignment: Alignment.center,
                                  height: constraints.maxHeight,
                                  width:
                                      constraints.maxHeight *
                                      StyleString.aspectRatio,
                                  decoration: BoxDecoration(
                                    borderRadius: StyleString.mdRadius,
                                    color: Colors.black.withValues(alpha: 0.6),
                                  ),
                                  child: SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: AnimatedScale(
                                      scale: videoItem.checked == true ? 1 : 0,
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeInOut,
                                      child: IconButton(
                                        tooltip: '取消选择',
                                        style: ButtonStyle(
                                          padding: WidgetStateProperty.all(
                                            EdgeInsets.zero,
                                          ),
                                          backgroundColor:
                                              WidgetStateProperty.resolveWith(
                                                (states) {
                                                  return theme
                                                      .colorScheme
                                                      .surface
                                                      .withValues(alpha: 0.8);
                                                },
                                              ),
                                        ),
                                        onPressed: null,
                                        icon: Icon(
                                          Icons.done_all_outlined,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 0,
                          child: iconButton(
                            tooltip: '移除',
                            context: context,
                            onPressed: () => _laterController.toViewDel(
                              context,
                              index,
                              videoItem.aid,
                            ),
                            icon: Icons.clear,
                            iconColor: theme.colorScheme.outline,
                            bgColor: Colors.transparent,
                          ),
                        ),
                      ],
                    );
                  },
                  childCount: response!.length,
                ),
              )
            : HttpError(
                onReload: _laterController.onReload,
              ),
      Error(:var errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _laterController.onReload,
      ),
    };
  }

  @override
  bool get wantKeepAlive => true;
}

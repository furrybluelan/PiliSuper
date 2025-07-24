import 'package:PiliPlus/common/skeleton/video_card_h.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/refresh_indicator.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/sub/sub_detail/media.dart';
import 'package:PiliPlus/pages/subscription_detail/controller.dart';
import 'package:PiliPlus/pages/subscription_detail/widget/sub_video_card.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/num_util.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SubDetailPage extends StatefulWidget {
  const SubDetailPage({super.key});

  @override
  State<SubDetailPage> createState() => _SubDetailPageState();
}

class _SubDetailPageState extends State<SubDetailPage> {
  late final SubDetailController _subDetailController = Get.put(
    SubDetailController(),
    tag: Utils.makeHeroTag(Get.parameters['id']),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: refreshIndicator(
          onRefresh: _subDetailController.onRefresh,
          child: CustomScrollView(
            controller: _subDetailController.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildAppBar(theme),
              SliverPadding(
                padding: EdgeInsets.only(
                  top: 7,
                  bottom: MediaQuery.paddingOf(context).bottom + 80,
                ),
                sliver: Obx(
                  () => _buildBody(_subDetailController.loadingState.value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(LoadingState<List<SubDetailItemModel>?> loadingState) {
    return switch (loadingState) {
      Loading() => SliverGrid(
        gridDelegate: Grid.videoCardHDelegate(context),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const VideoCardHSkeleton(),
          childCount: 10,
        ),
      ),
      Success(:var response) =>
        response?.isNotEmpty == true
            ? SliverGrid(
                gridDelegate: Grid.videoCardHDelegate(context),
                delegate: SliverChildBuilderDelegate(
                  childCount: response!.length,
                  (context, index) {
                    if (index == response.length - 1) {
                      _subDetailController.onLoadMore();
                    }
                    return SubVideoCardH(
                      videoItem: response[index],
                    );
                  },
                ),
              )
            : HttpError(
                onReload: _subDetailController.onReload,
              ),
      Error(:var errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _subDetailController.onReload,
      ),
    };
  }

  Widget _buildAppBar(ThemeData theme) {
    final style = TextStyle(
      fontSize: 12.5,
      color: theme.colorScheme.outline,
    );
    return SliverAppBar.medium(
      expandedHeight: kToolbarHeight + 132,
      pinned: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _subDetailController.subInfo.title!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          Obx(
            () => Text(
              '共${_subDetailController.mediaCount.value}条视频',
              style: theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.2),
              ),
            ),
          ),
          padding: EdgeInsets.only(
            top: kToolbarHeight + MediaQuery.paddingOf(context).top + 10,
            left: 12,
            right: 12,
            bottom: 12,
          ),
          child: Row(
            spacing: 12,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: _subDetailController.heroTag,
                child: NetworkImgLayer(
                  width: 176,
                  height: 110,
                  src: _subDetailController.subInfo.cover,
                ),
              ),
              Expanded(
                child: Column(
                  spacing: 4,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _subDetailController.subInfo.title!,
                      style: TextStyle(
                        fontSize: theme.textTheme.titleMedium!.fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Get.toNamed(
                          '/member?mid=${_subDetailController.subInfo.upper!.mid}',
                        );
                      },
                      child: Text(
                        _subDetailController.subInfo.upper!.name!,
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ),
                    const Spacer(),
                    Obx(
                      () {
                        final mediaCount =
                            _subDetailController.mediaCount.value;
                        return mediaCount == 0
                            ? const SizedBox.shrink()
                            : Text(
                                '共$mediaCount条视频',
                                style: style,
                              );
                      },
                    ),
                    Obx(
                      () => Text(
                        '${NumUtil.numFormat(_subDetailController.playCount.value)}次播放',
                        style: style,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:PiliPlus/models/common/fav_order_type.dart';
import 'package:PiliPlus/models/common/video/source_type.dart';
import 'package:PiliPlus/models_new/fav/fav_detail/data.dart';
import 'package:PiliPlus/models_new/fav/fav_detail/media.dart';
import 'package:PiliPlus/pages/common/common_search_page.dart';
import 'package:PiliPlus/pages/fav_detail/widget/fav_video_card.dart';
import 'package:PiliPlus/pages/fav_search/controller.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FavSearchPage extends CommonSearchPage {
  const FavSearchPage({super.key});

  @override
  State<FavSearchPage> createState() => _FavSearchPageState();
}

class _FavSearchPageState
    extends
        CommonSearchPageState<
          FavSearchPage,
          FavDetailData,
          FavDetailItemModel
        > {
  @override
  final FavSearchController controller = Get.put(
    FavSearchController(),
    tag: Utils.generateRandomString(8),
  );

  @override
  List<Widget>? get extraActions => [
    Obx(
      () {
        return PopupMenuButton<FavOrderType>(
          icon: const Icon(Icons.sort),
          requestFocus: false,
          initialValue: controller.order.value,
          tooltip: '排序方式',
          onSelected: (value) => controller
            ..order.value = value
            ..onReload(),
          itemBuilder: (context) => FavOrderType.values
              .map(
                (e) => PopupMenuItem(
                  value: e,
                  child: Text(e.label),
                ),
              )
              .toList(),
        );
      },
    ),
  ];

  @override
  Widget buildList(List<FavDetailItemModel> list) {
    return SliverGrid(
      gridDelegate: Grid.videoCardHDelegate(context, minHeight: 110),
      delegate: SliverChildBuilderDelegate(
        childCount: list.length,
        (context, index) {
          if (index == list.length - 1) {
            controller.onLoadMore();
          }
          final item = list[index];
          return FavVideoCardH(
            item: item,
            onDelFav: controller.isOwner == true
                ? () => controller.onCancelFav(
                    index,
                    item.id!,
                    item.type,
                  )
                : null,
            onViewFav: () => PageUtils.toVideoPage(
              'bvid=${item.bvid}&cid=${item.ugc?.firstCid}',
              arguments: {
                'videoItem': item,
                'heroTag': Utils.makeHeroTag(item.bvid),
                'sourceType': SourceType.fav,
                'mediaId': controller.mediaId,
                'oid': item.id,
                'favTitle': controller.title,
                'count': controller.count,
                'desc': true,
                'isContinuePlaying': true,
              },
            ),
          );
        },
      ),
    );
  }
}

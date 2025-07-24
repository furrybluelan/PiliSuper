import 'package:PiliPlus/common/widgets/custom_sliver_persistent_header_delegate.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search_panel/article/controller.dart';
import 'package:PiliPlus/pages/search_panel/article/widgets/item.dart';
import 'package:PiliPlus/pages/search_panel/view.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SearchArticlePanel extends CommonSearchPanel {
  const SearchArticlePanel({
    super.key,
    required super.keyword,
    required super.tag,
    required super.searchType,
  });

  @override
  State<SearchArticlePanel> createState() => _SearchArticlePanelState();
}

class _SearchArticlePanelState
    extends
        CommonSearchPanelState<
          SearchArticlePanel,
          SearchArticleData,
          SearchArticleItemModel
        > {
  @override
  late final SearchArticleController controller = Get.put(
    SearchArticleController(
      keyword: widget.keyword,
      searchType: widget.searchType,
      tag: widget.tag,
    ),
    tag: widget.searchType.name + widget.tag,
  );

  @override
  Widget buildHeader(ThemeData theme) {
    return SliverPersistentHeader(
      pinned: false,
      floating: true,
      delegate: CustomSliverPersistentHeaderDelegate(
        extent: 40,
        bgColor: theme.colorScheme.surface,
        child: Container(
          height: 40,
          padding: const EdgeInsets.only(left: 25, right: 12),
          child: Row(
            children: [
              Obx(
                () => Text(
                  '排序: ${controller.orderFiltersList[controller.currentOrderFilterval.value]['label']}',
                  maxLines: 1,
                  style: TextStyle(color: theme.colorScheme.outline),
                ),
              ),
              const Spacer(),
              Obx(
                () => Text(
                  '分区: ${controller.zoneFiltersList[controller.currentZoneFilterval.value]['label']}',
                  maxLines: 1,
                  style: TextStyle(color: theme.colorScheme.outline),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  tooltip: '筛选',
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () => controller.onShowFilterDialog(context),
                  icon: Icon(
                    Icons.filter_list_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget buildList(ThemeData theme, List<SearchArticleItemModel> list) {
    return SliverGrid(
      gridDelegate: Grid.videoCardHDelegate(context),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          if (index == list.length - 1) {
            controller.onLoadMore();
          }
          return SearchArticleItem(item: list[index]);
        },
        childCount: list.length,
      ),
    );
  }
}

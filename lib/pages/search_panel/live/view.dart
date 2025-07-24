import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search_panel/controller.dart';
import 'package:PiliPlus/pages/search_panel/live/widgets/item.dart';
import 'package:PiliPlus/pages/search_panel/view.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SearchLivePanel extends CommonSearchPanel {
  const SearchLivePanel({
    super.key,
    required super.keyword,
    required super.tag,
    required super.searchType,
  });

  @override
  State<SearchLivePanel> createState() => _SearchLivePanelState();
}

class _SearchLivePanelState
    extends
        CommonSearchPanelState<
          SearchLivePanel,
          SearchLiveData,
          SearchLiveItemModel
        > {
  @override
  late final controller = Get.put(
    SearchPanelController<SearchLiveData, SearchLiveItemModel>(
      keyword: widget.keyword,
      searchType: widget.searchType,
      tag: widget.tag,
    ),
    tag: widget.searchType.name + widget.tag,
  );

  @override
  Widget buildList(ThemeData theme, List<SearchLiveItemModel> list) {
    return SliverPadding(
      padding: const EdgeInsets.only(
        left: StyleString.safeSpace,
        right: StyleString.safeSpace,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithExtentAndRatio(
          maxCrossAxisExtent: Grid.smallCardWidth,
          crossAxisSpacing: StyleString.safeSpace,
          mainAxisSpacing: StyleString.safeSpace,
          childAspectRatio: StyleString.aspectRatio,
          mainAxisExtent: MediaQuery.textScalerOf(context).scale(80),
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == list.length - 1) {
              controller.onLoadMore();
            }
            return LiveItem(liveItem: list[index]);
          },
          childCount: list.length,
        ),
      ),
    );
  }
}

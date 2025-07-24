import 'package:PiliPlus/common/widgets/custom_sliver_persistent_header_delegate.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
import 'package:PiliPlus/pages/search_panel/video/controller.dart';
import 'package:PiliPlus/pages/search_panel/view.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class SearchVideoPanel extends CommonSearchPanel {
  const SearchVideoPanel({
    super.key,
    required super.keyword,
    required super.tag,
    required super.searchType,
  });

  @override
  State<SearchVideoPanel> createState() => _SearchVideoPanelState();
}

class _SearchVideoPanelState
    extends
        CommonSearchPanelState<
          SearchVideoPanel,
          SearchVideoData,
          SearchVideoItemModel
        > {
  @override
  late final SearchVideoController controller = Get.put(
    SearchVideoController(
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
        extent: 34,
        bgColor: theme.colorScheme.surface,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    children: [
                      for (var i in controller.filterList) ...[
                        Obx(
                          () => SearchText(
                            fontSize: 13,
                            text: i['label'],
                            bgColor: Colors.transparent,
                            textColor:
                                controller.selectedType.value == i['type']
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                            onTap: (value) async {
                              controller.selectedType.value = i['type'];
                              controller.order.value = i['type']
                                  .toString()
                                  .split('.')
                                  .last;
                              SmartDialog.showLoading(msg: 'loading');
                              await controller.onReload();
                              SmartDialog.dismiss();
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const VerticalDivider(indent: 7, endIndent: 8),
              const SizedBox(width: 3),
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
  Widget buildList(ThemeData theme, List<SearchVideoItemModel> list) {
    return SliverGrid(
      gridDelegate: Grid.videoCardHDelegate(context),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == list.length - 1) {
            controller.onLoadMore();
          }
          return VideoCardH(
            videoItem: list[index],
            onRemove: () => controller.loadingState
              ..value.data!.removeAt(index)
              ..refresh(),
          );
        },
        childCount: list.length,
      ),
    );
  }
}

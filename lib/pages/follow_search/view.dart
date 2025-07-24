import 'package:PiliPlus/models_new/follow/data.dart';
import 'package:PiliPlus/models_new/follow/list.dart';
import 'package:PiliPlus/pages/common/common_search_page.dart';
import 'package:PiliPlus/pages/follow/widgets/follow_item.dart';
import 'package:PiliPlus/pages/follow_search/controller.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FollowSearchPage extends CommonSearchPage {
  const FollowSearchPage({
    super.key,
    this.mid,
    this.isFromSelect,
  });

  final int? mid;
  final bool? isFromSelect;

  @override
  State<FollowSearchPage> createState() => _FollowSearchPageState();
}

class _FollowSearchPageState
    extends
        CommonSearchPageState<FollowSearchPage, FollowData, FollowItemModel> {
  @override
  late final FollowSearchController controller = Get.put(
    FollowSearchController(widget.mid ?? Get.arguments['mid']),
    tag: Utils.generateRandomString(8),
  );

  @override
  Widget buildList(List<FollowItemModel> list) {
    return SliverList.builder(
      itemCount: list.length,
      itemBuilder: ((context, index) {
        if (index == list.length - 1) {
          controller.onLoadMore();
        }
        return FollowItem(
          item: list[index],
          onSelect: widget.mid != null && widget.isFromSelect != false
              ? (userModel) => Get.back(result: userModel)
              : null,
        );
      }),
    );
  }
}

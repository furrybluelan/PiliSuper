import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/fav_order_type.dart';
import 'package:PiliPlus/models_new/fav/fav_detail/data.dart';
import 'package:PiliPlus/models_new/fav/fav_detail/media.dart';
import 'package:PiliPlus/pages/common/common_search_controller.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class FavSearchController
    extends CommonSearchController<FavDetailData, FavDetailItemModel> {
  int type = Get.arguments['type'];
  int mediaId = Get.arguments['mediaId'];
  bool isOwner = Get.arguments['isOwner'];
  dynamic count = Get.arguments['count'];
  dynamic title = Get.arguments['title'];

  final Rx<FavOrderType> order = FavOrderType.mtime.obs;

  @override
  Future<LoadingState<FavDetailData>> customGetData() =>
      FavHttp.userFavFolderDetail(
        pn: page,
        ps: 20,
        mediaId: mediaId,
        keyword: editController.text,
        type: type,
        order: order.value,
      );

  @override
  List<FavDetailItemModel>? getDataList(FavDetailData response) {
    if (response.hasMore == false) {
      isEnd = true;
    }
    return response.medias;
  }

  Future<void> onCancelFav(int index, int id, int? type) async {
    var result = await FavHttp.favVideo(
      resources: '$id:$type',
      addIds: '',
      delIds: mediaId.toString(),
    );
    if (result['status']) {
      loadingState
        ..value.data!.removeAt(index)
        ..refresh();
      SmartDialog.showToast('取消收藏');
    }
  }
}

import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/data.dart';
import 'package:PiliPlus/models_new/video/video_tag/data.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

abstract class CommonIntroController extends GetxController {
  String bvid = Get.parameters['bvid']!;

  // 是否点赞
  final RxBool hasLike = false.obs;
  // 投币数量
  final RxNum coinNum = RxNum(0);
  // 是否投币
  bool get hasCoin => coinNum.value != 0;
  // 是否收藏
  final RxBool hasFav = false.obs;

  final Rx<List<VideoTagItem>?> videoTags = Rx<List<VideoTagItem>?>(null);

  Set? favIds;
  final Rx<FavFolderData> favFolderData = FavFolderData().obs;

  AccountService accountService = Get.find<AccountService>();

  Future queryVideoInFolder();

  Future<void> actionFavVideo({String type = 'choose'});

  late final enableQuickFav = Pref.enableQuickFav;
  int? quickFavId;

  int get favFolderId {
    if (this.quickFavId != null) {
      return this.quickFavId!;
    }
    final quickFavId = Pref.quickFavId;
    final list = favFolderData.value.list!;
    if (quickFavId != null) {
      final folderInfo = list.firstWhereOrNull((e) => e.id == quickFavId);
      if (folderInfo != null) {
        return this.quickFavId = quickFavId;
      } else {
        GStorage.setting.delete(SettingBoxKey.quickFavId);
      }
    }
    return this.quickFavId = list.first.id;
  }

  // 收藏
  void showFavBottomSheet(BuildContext context, {type = 'tap'}) {
    if (!accountService.isLogin.value) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    // 快速收藏 &
    // 点按 收藏至默认文件夹
    // 长按选择文件夹
    if (enableQuickFav) {
      if (type == 'tap') {
        actionFavVideo(type: 'default');
      } else {
        PageUtils.showFavBottomSheet(context: context, ctr: this);
      }
    } else if (type != 'longPress') {
      PageUtils.showFavBottomSheet(context: context, ctr: this);
    }
  }

  Future<void> queryVideoTags() async {
    var result = await UserHttp.videoTags(bvid: bvid);
    if (result['status']) {
      videoTags.value = result['data'];
    } else {
      videoTags.value = null;
    }
  }
}

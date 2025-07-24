import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show MainListReply, ReplyInfo;
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/dynamics.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/pages/common/reply_controller.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class DynamicDetailController extends ReplyController<MainListReply> {
  late int oid;
  late int replyType;
  late DynamicItemModel dynItem;

  late final horizontalPreview = Pref.horizontalPreview;
  late final showDynActionBar = Pref.showDynActionBar;

  @override
  dynamic get sourceId => replyType == 1 ? IdUtils.av2bv(oid) : oid;

  @override
  void onInit() {
    super.onInit();
    dynItem = Get.arguments['item'];
    var commentType = dynItem.basic?.commentType;
    var commentIdStr = dynItem.basic?.commentIdStr;
    if (commentType != null &&
        commentType != 0 &&
        commentIdStr?.isNotEmpty == true) {
      _init(commentIdStr!, commentType);
    } else {
      DynamicsHttp.dynamicDetail(id: dynItem.idStr).then((res) {
        if (res['status']) {
          DynamicItemModel data = res['data'];
          _init(data.basic!.commentIdStr!, data.basic!.commentType!);
        } else {
          SmartDialog.showToast(res['msg']);
        }
      });
    }
  }

  void _init(String commentIdStr, int commentType) {
    oid = int.parse(commentIdStr);
    replyType = commentType;
    queryData();
  }

  @override
  List<ReplyInfo>? getDataList(MainListReply response) {
    return response.replies;
  }

  @override
  Future<LoadingState<MainListReply>> customGetData() => ReplyGrpc.mainList(
    type: replyType,
    oid: oid,
    mode: mode.value,
    cursorNext: cursorNext,
    offset: paginationReply?.nextOffset,
  );
}

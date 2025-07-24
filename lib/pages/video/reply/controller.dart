import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show MainListReply, ReplyInfo;
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/common/reply_controller.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_ticket_provider_mixin.dart';

class VideoReplyController extends ReplyController<MainListReply>
    with GetSingleTickerProviderStateMixin {
  VideoReplyController({required this.aid});
  // 视频aid 请求时使用的oid
  int aid;

  @override
  dynamic get sourceId => IdUtils.av2bv(aid);

  bool _isFabVisible = true;
  late final AnimationController fabAnimationCtr = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  )..forward();

  late final anim =
      Tween<Offset>(
        begin: const Offset(0, 2),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: fabAnimationCtr,
          curve: Curves.easeInOut,
        ),
      );

  void showFab() {
    if (!_isFabVisible) {
      _isFabVisible = true;
      fabAnimationCtr.forward();
    }
  }

  void hideFab() {
    if (_isFabVisible) {
      _isFabVisible = false;
      fabAnimationCtr.reverse();
    }
  }

  @override
  List<ReplyInfo>? getDataList(MainListReply response) {
    return response.replies;
  }

  @override
  Future<LoadingState<MainListReply>> customGetData() => ReplyGrpc.mainList(
    oid: aid,
    mode: mode.value,
    cursorNext: cursorNext,
    offset: paginationReply?.nextOffset,
  );

  @override
  void onClose() {
    fabAnimationCtr.dispose();
    super.onClose();
  }
}

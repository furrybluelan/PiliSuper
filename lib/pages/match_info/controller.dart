import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/match.dart';
import 'package:PiliPlus/models_new/match/match_info/contest.dart';
import 'package:PiliPlus/pages/common/reply_controller.dart';
import 'package:get/get.dart';

class MatchInfoController extends ReplyController<MainListReply> {
  final int cid = int.parse(Get.parameters['cid']!);

  int get replyType => 27;

  @override
  dynamic get sourceId => cid.toString();

  final Rx<LoadingState<MatchContest?>> infoState =
      LoadingState<MatchContest?>.loading().obs;

  @override
  void onInit() {
    super.onInit();
    getMatchInfo();
  }

  Future<void> getMatchInfo() async {
    var res = await MatchHttp.matchInfo(cid);
    if (res.isSuccess) {
      queryData();
    }
    infoState.value = res;
  }

  @override
  List<ReplyInfo>? getDataList(MainListReply response) {
    return response.replies;
  }

  @override
  Future<LoadingState<MainListReply>> customGetData() => ReplyGrpc.mainList(
    type: replyType,
    oid: cid,
    mode: mode.value,
    cursorNext: cursorNext,
    offset: paginationReply?.nextOffset,
  );
}

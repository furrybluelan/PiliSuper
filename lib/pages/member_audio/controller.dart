import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/member.dart';
import 'package:PiliPlus/models_new/space/space_audio/data.dart';
import 'package:PiliPlus/models_new/space/space_audio/item.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';

class MemberAudioController
    extends CommonListController<SpaceAudioData, SpaceAudioItem> {
  MemberAudioController(this.mid);

  final int mid;
  int? totalSize;

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  void checkIsEnd(int length) {
    if (totalSize != null && length >= totalSize!) {
      isEnd = true;
    }
  }

  @override
  List<SpaceAudioItem>? getDataList(SpaceAudioData response) {
    totalSize = response.totalSize;
    return response.items;
  }

  @override
  Future<LoadingState<SpaceAudioData>> customGetData() => MemberHttp.spaceAudio(
    page: page,
    mid: mid,
  );
}

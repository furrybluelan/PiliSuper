import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models_new/video/video_note_list/data.dart';
import 'package:PiliPlus/models_new/video/video_note_list/list.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:get/get.dart';

class NoteListPageCtr
    extends CommonListController<VideoNoteData, VideoNoteItemModel> {
  NoteListPageCtr({this.oid, this.upperMid});
  final dynamic oid;
  final dynamic upperMid;

  RxInt count = (-1).obs;

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  List<VideoNoteItemModel>? getDataList(VideoNoteData response) {
    count.value = response.page?.total ?? -1;
    return response.list;
  }

  @override
  void checkIsEnd(int length) {
    final count = this.count.value;
    if (count != -1 && length >= count) {
      isEnd = true;
    }
  }

  @override
  Future<LoadingState<VideoNoteData>> customGetData() =>
      VideoHttp.getVideoNoteList(
        oid: oid,
        uperMid: upperMid,
        page: page,
      );
}

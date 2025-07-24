import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/fav/fav_note/list.dart';
import 'package:PiliPlus/pages/common/multi_select_controller.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class FavNoteController
    extends MultiSelectController<List<FavNoteItemModel>?, FavNoteItemModel> {
  FavNoteController(this.isPublish);

  final bool isPublish;

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  void onSelect(FavNoteItemModel item, [bool disableSelect = true]) {
    super.onSelect(item, false);
  }

  @override
  void handleSelect([bool checked = false, bool disableSelect = true]) {
    allSelected.value = checked;
    super.handleSelect(checked, false);
  }

  @override
  Future<LoadingState<List<FavNoteItemModel>?>> customGetData() {
    return isPublish
        ? FavHttp.userNoteList(page: page)
        : FavHttp.noteList(page: page);
  }

  Future<void> onRemove() async {
    List<FavNoteItemModel> dataList = loadingState.value.data!;
    Set<FavNoteItemModel> removeList = dataList
        .where((item) => item.checked == true)
        .toSet();
    final res = await FavHttp.delNote(
      isPublish: isPublish,
      noteIds: removeList
          .map((item) => isPublish ? item.cvid : item.noteId)
          .toList(),
    );
    if (res['status']) {
      List<FavNoteItemModel> remainList = dataList
          .toSet()
          .difference(removeList)
          .toList();
      loadingState.value = Success(remainList);
      enableMultiSelect.value = false;
      SmartDialog.showToast('删除成功');
    } else {
      SmartDialog.showToast(res['msg']);
    }
  }

  void onDisable() {
    if (checkedCount.value != 0) {
      handleSelect();
    }
    enableMultiSelect.value = false;
  }
}

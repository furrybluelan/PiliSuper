import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/history/data.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/models_new/history/tab.dart';
import 'package:PiliPlus/pages/common/multi_select_controller.dart';
import 'package:PiliPlus/pages/history/base_controller.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class HistoryController
    extends MultiSelectController<HistoryData, HistoryItemModel>
    with GetSingleTickerProviderStateMixin {
  HistoryController(this.type);

  late final baseCtr = Get.put(HistoryBaseController());

  final String? type;
  TabController? tabController;
  late RxList<HistoryTab> tabs = <HistoryTab>[].obs;

  int? max;
  int? viewAt;

  @override
  void onInit() {
    super.onInit();
    historyStatus();
    queryData();
  }

  @override
  Future<void> onRefresh() {
    max = null;
    viewAt = null;
    return super.onRefresh();
  }

  @override
  void onSelect(HistoryItemModel item, [bool disableSelect = true]) {
    List<HistoryItemModel> list = loadingState.value.data!;
    item.checked = !(item.checked ?? false);
    baseCtr.checkedCount.value = list
        .where((item) => item.checked == true)
        .length;
    loadingState.refresh();
    if (baseCtr.checkedCount.value == 0) {
      baseCtr.enableMultiSelect.value = false;
    }
  }

  @override
  void handleSelect([bool checked = false, bool disableSelect = true]) {
    if (loadingState.value.isSuccess) {
      List<HistoryItemModel>? list = loadingState.value.data;
      if (list?.isNotEmpty == true) {
        for (HistoryItemModel item in list!) {
          item.checked = checked;
        }
        baseCtr.checkedCount.value = checked ? list.length : 0;
        loadingState.refresh();
      }
    }
    if (!checked) {
      baseCtr.enableMultiSelect.value = false;
    }
  }

  @override
  List<HistoryItemModel>? getDataList(HistoryData response) {
    return response.list;
  }

  @override
  bool customHandleResponse(bool isRefresh, Success<HistoryData> response) {
    HistoryData data = response.response;
    isEnd = data.list.isNullOrEmpty;
    max = data.list?.lastOrNull?.history.oid;
    viewAt = data.list?.lastOrNull?.viewAt;

    if (isRefresh && type == null) {
      if (tabs.isEmpty && data.tab?.isNotEmpty == true) {
        tabs.value = data.tab!;
        tabController = TabController(
          length: data.tab!.length + 1,
          vsync: this,
        );
      }
    }

    return false;
  }

  // 观看历史暂停状态
  Future<void> historyStatus() async {
    var res = await UserHttp.historyStatus();
    if (res['status']) {
      baseCtr.pauseStatus.value = res['data'];
      GStorage.localCache.put(LocalCacheKey.historyPause, res['data']);
    } else {
      SmartDialog.showToast(res['msg']);
    }
  }

  // 删除某条历史记录
  void delHistory(HistoryItemModel item) {
    _onDelete([item]);
  }

  // 删除已看历史记录
  void onDelHistory() {
    if (loadingState.value.isSuccess) {
      List<HistoryItemModel> list = loadingState.value.data!
          .where((e) => e.progress == -1)
          .toList();
      if (list.isNotEmpty) {
        _onDelete(list);
      } else {
        SmartDialog.showToast('无已看记录');
      }
    }
  }

  Future<void> _onDelete(List<HistoryItemModel> result) async {
    SmartDialog.showLoading(msg: '请求中');
    List<String> kidList = result.map((item) {
      return '${item.history.business}_${item.kid}';
    }).toList();
    var response = await UserHttp.delHistory(kidList);
    if (response['status']) {
      List<HistoryItemModel> remainList = loadingState.value.data!
          .toSet()
          .difference(result.toSet())
          .toList();
      if (remainList.isNotEmpty) {
        loadingState.value = Success(remainList);
      } else {
        onReload();
      }
      if (baseCtr.enableMultiSelect.value) {
        baseCtr.checkedCount.value = 0;
        baseCtr.enableMultiSelect.value = false;
      }
    }
    SmartDialog.dismiss();
    SmartDialog.showToast(response['msg']);
  }

  // 删除选中的记录
  void onDelCheckedHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('提示'),
          content: const Text('确认删除所选历史记录吗？'),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text(
                '取消',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                if (loadingState.value.isSuccess) {
                  _onDelete(
                    loadingState.value.data!
                        .where((e) => e.checked == true)
                        .toList(),
                  );
                }
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  @override
  Future<LoadingState<HistoryData>> customGetData() =>
      UserHttp.historyList(type: type ?? 'all', max: max, viewAt: viewAt);

  @override
  void onClose() {
    tabController?.dispose();
    super.onClose();
  }

  @override
  Future<void> onReload() {
    scrollController.jumpToTop();
    return super.onReload();
  }
}

import 'package:PiliPlus/http/fan.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models_new/fans/data.dart';
import 'package:PiliPlus/models_new/fans/list.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class FansController extends CommonListController<FansData, FansItemModel> {
  FansController(this.mid);
  int ps = 20;
  int total = 0;
  int mid;

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  List<FansItemModel>? getDataList(FansData response) {
    return response.list;
  }

  @override
  Future<LoadingState<FansData>> customGetData() => FanHttp.fans(
    vmid: mid,
    pn: page,
    ps: ps,
    orderType: 'attention',
  );

  Future<void> onRemoveFan(int index, int mid) async {
    final res = await VideoHttp.relationMod(
      mid: mid,
      act: 7,
      reSrc: 11,
    );
    if (res['status']) {
      loadingState
        ..value.data!.removeAt(index)
        ..refresh();
      SmartDialog.showToast('移除成功');
    } else {
      SmartDialog.showToast(res['msg']);
    }
  }
}

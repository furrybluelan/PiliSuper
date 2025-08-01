import 'dart:async';
import 'dart:math';

import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/models/common/home_tab_type.dart';
import 'package:PiliPlus/pages/common/common_controller.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeController extends GetxController
    with GetSingleTickerProviderStateMixin, ScrollOrRefreshMixin {
  late List<HomeTabType> tabs;
  late TabController tabController;

  StreamController<bool>? searchBarStream;
  final bool hideSearchBar = Pref.hideSearchBar;
  final bool useSideBar = Pref.useSideBar;

  bool enableSearchWord = Pref.enableSearchWord;
  late RxString defaultSearch = ''.obs;
  late int lateCheckSearchAt = 0;

  ScrollOrRefreshMixin get controller => tabs[tabController.index].ctr();

  @override
  ScrollController get scrollController => controller.scrollController;

  AccountService accountService = Get.find<AccountService>();

  @override
  void onInit() {
    super.onInit();

    if (hideSearchBar) {
      searchBarStream = StreamController<bool>.broadcast();
    }

    if (enableSearchWord) {
      lateCheckSearchAt = DateTime.now().millisecondsSinceEpoch;
      querySearchDefault();
    }

    setTabConfig();
  }

  @override
  Future<void> onRefresh() {
    return controller.onRefresh().catchError((e) {
      if (kDebugMode) debugPrint(e.toString());
    });
  }

  void setTabConfig() {
    tabs =
        Pref.tabbarSort?.map((i) => HomeTabType.values[i]).toList() ??
        HomeTabType.values;

    tabController = TabController(
      initialIndex: max(0, tabs.indexOf(HomeTabType.rcmd)),
      length: tabs.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> querySearchDefault() async {
    try {
      var res = await Request().get(Api.searchDefault);
      if (res.data['code'] == 0) {
        defaultSearch.value = res.data['data']?['name'] ?? '';
      }
    } catch (_) {}
  }

  @override
  void onClose() {
    searchBarStream?.close();
    super.onClose();
  }
}

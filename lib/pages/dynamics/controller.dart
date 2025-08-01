import 'dart:async';

import 'package:PiliPlus/http/dynamics.dart';
import 'package:PiliPlus/http/follow.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/dynamics/up.dart';
import 'package:PiliPlus/models_new/follow/data.dart';
import 'package:PiliPlus/pages/common/common_controller.dart';
import 'package:PiliPlus/pages/dynamics_tab/controller.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DynamicsController extends GetxController
    with GetSingleTickerProviderStateMixin, ScrollOrRefreshMixin {
  @override
  final ScrollController scrollController = ScrollController();
  late final TabController tabController = TabController(
    length: DynamicsTabType.values.length,
    vsync: this,
    initialIndex: Pref.defaultDynamicType,
  );

  late final RxInt mid = (-1).obs;
  late int currentMid = -1;

  Set<int> tempBannedList = <int>{};

  final Rx<LoadingState<FollowUpModel>> upState =
      LoadingState<FollowUpModel>.loading().obs;
  late int _upPage = 1;
  late bool _upEnd = false;
  List<UpItem>? _cacheUpList;
  late final showAllUp = Pref.dynamicsShowAllFollowedUp;
  late bool showLiveUp = Pref.expandDynLivePanel;

  final upPanelPosition = Pref.upPanelPosition;

  AccountService accountService = Get.find<AccountService>();

  DynamicsTabController? get controller {
    try {
      return Get.find<DynamicsTabController>(
        tag: DynamicsTabType.values[tabController.index].name,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    if (showAllUp) {
      scrollController.addListener(listener);
    }
    queryFollowUp();
  }

  void listener() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 300) {
      EasyThrottle.throttle(
        'following',
        const Duration(seconds: 1),
        queryFollowing2,
      );
    }
  }

  Future<void> queryFollowing2() async {
    if (isQuerying) return;
    isQuerying = true;
    if (_upEnd) {
      isQuerying = false;
      return;
    }

    final res = await FollowHttp.followings(
      vmid: accountService.mid,
      pn: _upPage,
      orderType: 'attention',
      ps: 50,
    );

    if (res.isSuccess) {
      _upPage++;
      final list = res.data.list;
      if (list.isEmpty) {
        _upEnd = true;
      }
      upState
        ..value.data.upList.addAll(
          list..removeWhere((e) => _cacheUpList?.contains(e) == true),
        )
        ..refresh();
    }

    isQuerying = false;
  }

  late bool isQuerying = false;
  Future<void> queryFollowUp() async {
    if (isQuerying) return;
    isQuerying = true;

    if (!accountService.isLogin.value) {
      upState.value = const Error(null);
      isQuerying = false;
      return;
    }

    final res = await Future.wait([
      DynamicsHttp.followUp(),
      if (showAllUp)
        FollowHttp.followings(
          vmid: accountService.mid,
          pn: _upPage,
          orderType: 'attention',
          ps: 50,
        ),
    ]);

    final first = res.first;
    final second = res.getOrNull(1);
    if (first.isSuccess) {
      FollowUpModel data = first.data as FollowUpModel;
      if (second != null && second.isSuccess) {
        _cacheUpList = List<UpItem>.from(data.upList);
        FollowData data1 = second.data as FollowData;
        final list1 = data1.list;

        _upPage++;
        if (list1.isEmpty || list1.length >= (data1.total ?? 0)) {
          _upEnd = true;
        }

        final list = data.upList;
        list.addAll(list1..removeWhere((e) => list.contains(e)));
      }
      upState.value = Success(data);
    } else {
      upState.value = const Error(null);
    }

    isQuerying = false;
  }

  void onSelectUp(int mid) {
    if (this.mid.value == mid) {
      tabController.index = (mid == -1 ? 0 : 4);
      if (mid == -1) {
        queryFollowUp();
      }
      controller?.onReload();
      return;
    }

    this.mid.value = mid;
    tabController.index = (mid == -1 ? 0 : 4);
  }

  @override
  Future<void> onRefresh() async {
    if (showAllUp) {
      _upPage = 1;
      _cacheUpList = null;
    }
    queryFollowUp();
    await controller?.onRefresh();
  }

  @override
  void animateToTop() {
    controller?.animateToTop();
    scrollController.animToTop();
  }

  @override
  void toTopOrRefresh() {
    final ctr = controller;
    if (ctr?.scrollController.hasClients == true) {
      if (ctr!.scrollController.position.pixels == 0) {
        if (scrollController.hasClients &&
            scrollController.position.pixels != 0) {
          scrollController.animToTop();
        }
        EasyThrottle.throttle(
          'topOrRefresh',
          const Duration(milliseconds: 500),
          onRefresh,
        );
      } else {
        animateToTop();
      }
    } else {
      super.toTopOrRefresh();
    }
  }

  @override
  void onClose() {
    tabController.dispose();
    scrollController
      ..removeListener(listener)
      ..dispose();
    super.onClose();
  }
}

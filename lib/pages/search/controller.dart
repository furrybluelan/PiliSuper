import 'dart:async';

import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/search/suggest.dart';
import 'package:PiliPlus/models_new/search/search_rcmd/data.dart';
import 'package:PiliPlus/models_new/search/search_trending/data.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_transform/stream_transform.dart';

class SSearchController extends GetxController {
  SSearchController(this.tag);
  final String tag;

  final searchFocusNode = FocusNode();
  final controller = TextEditingController();

  String? hintText;

  int initIndex = 0;

  // uid
  final RxBool showUidBtn = false.obs;

  // history
  final RxBool recordSearchHistory = Pref.recordSearchHistory.obs;
  late final RxList<String> historyList;

  // suggestion
  final bool searchSuggestion = Pref.searchSuggestion;
  StreamController<String>? _ctr;
  StreamSubscription<String>? _sub;
  late final RxList<SearchSuggestItem> searchSuggestList;

  // trending
  final bool enableHotKey = Pref.enableHotKey;
  late final Rx<LoadingState<SearchTrendingData>> loadingState;

  // rcmd
  final bool enableSearchRcmd = Pref.enableSearchRcmd;
  late final Rx<LoadingState<SearchRcmdData>> recommendData;

  @override
  void onInit() {
    super.onInit();
    final params = Get.parameters;
    hintText = params['hintText'];
    final text = params['text'];
    if (text != null) {
      controller.text = text;
    }

    historyList = List<String>.from(
      GStorage.historyWord.get('cacheList') ?? [],
    ).obs;

    if (searchSuggestion) {
      _ctr = StreamController<String>();
      _sub = _ctr!.stream
          .debounce(const Duration(milliseconds: 200), trailing: true)
          .listen(querySearchSuggest);
      searchSuggestList = <SearchSuggestItem>[].obs;
    }

    if (enableHotKey) {
      loadingState = LoadingState<SearchTrendingData>.loading().obs;
      queryHotSearchList();
    }

    if (enableSearchRcmd) {
      recommendData = LoadingState<SearchRcmdData>.loading().obs;
      queryRecommendList();
    }
  }

  void validateUid() {
    showUidBtn.value = IdUtils.digitOnlyRegExp.hasMatch(controller.text);
  }

  void onChange(String value) {
    validateUid();
    if (searchSuggestion) {
      if (value.isEmpty) {
        searchSuggestList.clear();
      } else {
        _ctr!.add(value);
      }
    }
  }

  void onClear() {
    if (controller.value.text != '') {
      controller.clear();
      searchSuggestList.clear();
      searchFocusNode.requestFocus();
      showUidBtn.value = false;
    } else {
      Get.back();
    }
  }

  // 搜索
  Future<void> submit() async {
    if (controller.text.isEmpty) {
      if (hintText.isNullOrEmpty) {
        return;
      }
      controller.text = hintText!;
      validateUid();
    }

    if (recordSearchHistory.value) {
      historyList
        ..remove(controller.text)
        ..insert(0, controller.text);
      GStorage.historyWord.put('cacheList', historyList);
    }

    searchFocusNode.unfocus();
    await Get.toNamed(
      '/searchResult',
      parameters: {
        'tag': tag,
        'keyword': controller.text,
      },
      arguments: {
        'initIndex': initIndex,
        'fromSearch': true,
      },
    );
    searchFocusNode.requestFocus();
  }

  // 获取热搜关键词
  Future<void> queryHotSearchList() async {
    loadingState.value = await SearchHttp.searchTrending(limit: 10);
  }

  Future<void> queryRecommendList() async {
    recommendData.value = await SearchHttp.searchRecommend();
  }

  void onClickKeyword(String keyword) {
    controller.text = keyword;
    validateUid();

    searchSuggestList.clear();
    submit();
  }

  Future<void> querySearchSuggest(String value) async {
    var res = await SearchHttp.searchSuggest(term: value);
    if (res['status']) {
      SearchSuggestModel data = res['data'];
      if (data.tag?.isNotEmpty == true) {
        searchSuggestList.value = data.tag!;
      }
    }
  }

  void onLongSelect(String word) {
    historyList.remove(word);
    GStorage.historyWord.put('cacheList', historyList);
  }

  void onClearHistory() {
    showConfirmDialog(
      context: Get.context!,
      title: '确定清空搜索历史？',
      onConfirm: () {
        historyList.clear();
        GStorage.historyWord.put('cacheList', []);
      },
    );
  }

  @override
  void onClose() {
    searchFocusNode.dispose();
    controller.dispose();
    _sub?.cancel();
    _ctr?.close();
    super.onClose();
  }
}

import 'package:PiliPlus/common/widgets/text_field/controller.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show MainListReply, ReplyInfo, SubjectControl, Mode;
import 'package:PiliPlus/grpc/bilibili/pagination.pb.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/reply.dart';
import 'package:PiliPlus/models/common/reply/reply_sort_type.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/pages/video/reply_new/view.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/reply_utils.dart';
import 'package:PiliPlus/utils/request_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/dialog/dialog_route.dart';

abstract class ReplyController<R> extends CommonListController<R, ReplyInfo> {
  RxInt count = (-1).obs;

  late Rx<ReplySortType> sortType;
  late Rx<Mode> mode;

  late final savedReplies = <Object, List<RichTextItem>?>{};

  AccountService accountService = Get.find<AccountService>();

  Int64? upMid;
  Int64? cursorNext;
  SubjectControl? subjectControl;
  FeedPaginationReply? paginationReply;
  late bool hasUpTop = false;

  @override
  bool? get hasFooter => true;

  // comment antifraud
  late final _enableCommAntifraud = Pref.enableCommAntifraud;
  late final _biliSendCommAntifraud = Pref.biliSendCommAntifraud;
  bool get enableCommAntifraud =>
      _enableCommAntifraud || _biliSendCommAntifraud;
  dynamic get sourceId;

  @override
  void onInit() {
    super.onInit();
    int replySortType = Pref.replySortType;
    sortType = ReplySortType.values[replySortType].obs;
    mode = (replySortType == 0 ? Mode.MAIN_LIST_TIME : Mode.MAIN_LIST_HOT).obs;
  }

  @override
  void checkIsEnd(int length) {
    final count = this.count.value;
    if (count != -1 && length >= count) {
      isEnd = true;
    }
  }

  @override
  bool customHandleResponse(bool isRefresh, Success response) {
    MainListReply data = response.response;
    cursorNext = data.cursor.next;
    paginationReply = data.paginationReply;
    count.value = data.subjectControl.count.toInt();
    if (isRefresh) {
      subjectControl = data.subjectControl;
      upMid ??= data.subjectControl.upMid;
      hasUpTop = data.hasUpTop();
      if (data.hasUpTop()) {
        data.replies.insert(0, data.upTop);
      }
    }
    isEnd = data.cursor.isEnd;
    return false;
  }

  @override
  Future<void> onRefresh() {
    cursorNext = null;
    paginationReply = null;
    subjectControl = null;
    return super.onRefresh();
  }

  // 排序搜索评论
  void queryBySort() {
    EasyThrottle.throttle('queryBySort', const Duration(seconds: 1), () {
      feedBack();
      switch (sortType.value) {
        case ReplySortType.time:
          sortType.value = ReplySortType.hot;
          mode.value = Mode.MAIN_LIST_HOT;
          break;
        case ReplySortType.hot:
          sortType.value = ReplySortType.time;
          mode.value = Mode.MAIN_LIST_TIME;
          break;
      }
      onReload();
    });
  }

  void onReply(
    BuildContext context, {
    int? oid,
    ReplyInfo? replyItem,
    int? replyType,
  }) {
    assert(replyItem != null || (oid != null && replyType != null));
    String? hint;
    try {
      if (subjectControl != null && subjectControl!.hasRootText()) {
        if (subjectControl!.inputDisable) {
          SmartDialog.showToast(subjectControl!.rootText);
          return;
        }
        if ((subjectControl!.hasSwitcherType() &&
                subjectControl!.switcherType != 1) ||
            subjectControl!.rootText.contains('可发评论')) {
          hint = subjectControl!.rootText;
        }
      }
    } catch (_) {}
    dynamic key = oid ?? replyItem!.oid + replyItem.id;
    Navigator.of(context)
        .push(
          GetDialogRoute(
            pageBuilder: (buildContext, animation, secondaryAnimation) {
              return ReplyPage(
                oid: oid ?? replyItem!.oid.toInt(),
                root: oid != null ? 0 : replyItem!.id.toInt(),
                parent: oid != null ? 0 : replyItem!.id.toInt(),
                replyType: replyItem?.type.toInt() ?? replyType!,
                replyItem: replyItem,
                items: savedReplies[key],
                onSave: (reply) {
                  if (reply.isEmpty) {
                    savedReplies.remove(key);
                  } else {
                    savedReplies[key] = reply.toList();
                  }
                },
                hint: hint,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
            transitionBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.linear;

              var tween = Tween(
                begin: begin,
                end: end,
              ).chain(CurveTween(curve: curve));

              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
            settings: RouteSettings(arguments: Get.arguments),
          ),
        )
        .then(
          (res) {
            if (res != null) {
              savedReplies.remove(key);
              ReplyInfo replyInfo = RequestUtils.replyCast(res);
              if (loadingState.value.isSuccess) {
                List<ReplyInfo>? list = loadingState.value.data;
                if (list == null) {
                  loadingState.value = Success([replyInfo]);
                } else {
                  if (oid != null) {
                    list.insert(hasUpTop ? 1 : 0, replyInfo);
                  } else {
                    replyItem!
                      ..count += 1
                      ..replies.add(replyInfo);
                  }
                  loadingState.refresh();
                }
              } else {
                loadingState.value = Success([replyInfo]);
              }
              count.value += 1;

              // check reply
              if (enableCommAntifraud) {
                onCheckReply(replyInfo, isManual: false);
              }
            }
          },
        );
  }

  void onRemove(int index, ReplyInfo item, int? subIndex) {
    List<ReplyInfo> list = loadingState.value.data!;
    if (subIndex == null) {
      list.removeAt(index);
    } else {
      item
        ..count -= 1
        ..replies.removeAt(subIndex);
    }
    count.value -= 1;
    loadingState.refresh();
  }

  void onCheckReply(ReplyInfo replyInfo, {required bool isManual}) {
    ReplyUtils.onCheckReply(
      replyInfo: replyInfo,
      biliSendCommAntifraud: _biliSendCommAntifraud,
      sourceId: sourceId,
      isManual: isManual,
    );
  }

  Future<void> onToggleTop(
    ReplyInfo item,
    int index,
    oid,
    int type,
  ) async {
    bool isUpTop = item.replyControl.isUpTop;
    final res = await ReplyHttp.replyTop(
      oid: oid,
      type: type,
      rpid: item.id,
      isUpTop: isUpTop,
    );
    if (res['status']) {
      List<ReplyInfo> list = loadingState.value.data!;
      item.replyControl.isUpTop = !isUpTop;
      if (!isUpTop && index != 0) {
        list[0].replyControl.isUpTop = false;
        final item = list.removeAt(index);
        list.insert(0, item);
      }
      loadingState.refresh();
      SmartDialog.showToast('${isUpTop ? '取消' : ''}置顶成功');
    } else {
      SmartDialog.showToast(res['msg']);
    }
  }

  @override
  void onClose() {
    savedReplies.clear();
    super.onClose();
  }
}

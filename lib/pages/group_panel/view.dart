import 'package:PiliPlus/common/widgets/loading_widget/loading_widget.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/member.dart';
import 'package:PiliPlus/models/member/tags.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class GroupPanel extends StatefulWidget {
  final int? mid;
  final List? tags;
  final ScrollController? scrollController;
  const GroupPanel({
    super.key,
    this.mid,
    this.tags,
    this.scrollController,
  });

  @override
  State<GroupPanel> createState() => _GroupPanelState();
}

class _GroupPanelState extends State<GroupPanel> {
  LoadingState<List<MemberTagItemModel>> loadingState =
      LoadingState<List<MemberTagItemModel>>.loading();
  RxBool showDefaultBtn = true.obs;

  @override
  void initState() {
    super.initState();
    _query();
  }

  void _query() {
    MemberHttp.followUpTags().then((res) {
      if (mounted) {
        if (res['status']) {
          List<MemberTagItemModel> tagsList =
              (res['data'] as List<MemberTagItemModel>)
                ..removeWhere((item) => item.tagid == 0)
                ..map((item) {
                  return item.checked =
                      widget.tags?.contains(item.tagid) == true;
                }).toList();
          showDefaultBtn.value = !tagsList.any((e) => e.checked == true);
          loadingState = Success(tagsList);
        } else {
          loadingState = Error(res['msg']);
        }
        setState(() {});
      }
    });
  }

  Future<void> onSave() async {
    if (!loadingState.isSuccess) {
      Get.back();
      return;
    }
    feedBack();
    // 是否有选中的 有选中的带id，没选使用默认0
    List<MemberTagItemModel> tagsList = loadingState.data;
    final bool anyHasChecked = tagsList.any(
      (MemberTagItemModel e) => e.checked == true,
    );
    late List<int> tagidList;
    if (anyHasChecked) {
      final List<MemberTagItemModel> checkedList = tagsList
          .where((MemberTagItemModel e) => e.checked == true)
          .toList();
      tagidList = checkedList.map<int>((e) => e.tagid!).toList();
    } else {
      tagidList = [0];
    }
    // 保存
    final res = await MemberHttp.addUsers([widget.mid], tagidList);
    SmartDialog.showToast(res['msg']);
    if (res['status']) {
      Get.back(result: tagidList);
    }
  }

  Widget get _buildBody {
    return switch (loadingState) {
      Loading() => loadingWidget,
      Success(:var response) => ListView.builder(
        controller: widget.scrollController,
        itemCount: response.length,
        itemBuilder: (context, index) {
          final item = response[index];
          return Material(
            type: MaterialType.transparency,
            child: Builder(
              builder: (context) {
                void onTap() {
                  item.checked = !item.checked!;
                  (context as Element).markNeedsBuild();
                  showDefaultBtn.value = !response.any(
                    (e) => e.checked == true,
                  );
                }

                return ListTile(
                  onTap: onTap,
                  dense: true,
                  leading: const Icon(Icons.group_outlined),
                  minLeadingWidth: 0,
                  title: Text(item.name ?? ''),
                  subtitle: item.tip?.isNotEmpty == true
                      ? Text(item.tip!)
                      : null,
                  trailing: Transform.scale(
                    scale: 0.9,
                    child: Checkbox(
                      value: item.checked,
                      onChanged: (bool? checkValue) => onTap(),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      Error(:var errMsg) => scrollErrorWidget(
        controller: widget.scrollController,
        errMsg: errMsg,
        onReload: _query,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            tooltip: '关闭',
            onPressed: Get.back,
            icon: const Icon(Icons.close_outlined),
          ),
          title: const Text('设置关注分组'),
        ),
        Expanded(child: _buildBody),
        Divider(
          height: 1,
          color: theme.disabledColor.withValues(alpha: 0.08),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.paddingOf(context).bottom + 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onSave,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(left: 30, right: 30),
                  foregroundColor: theme.colorScheme.onPrimary,
                  backgroundColor: theme.colorScheme.primary,
                ),
                child: Obx(() => Text(showDefaultBtn.value ? '保存至默认分组' : '保存')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

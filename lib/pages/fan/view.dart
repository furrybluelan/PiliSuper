import 'package:PiliPlus/common/skeleton/msg_feed_top.dart';
import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/refresh_indicator.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/models_new/fans/list.dart';
import 'package:PiliPlus/pages/fan/controller.dart';
import 'package:PiliPlus/pages/share/view.dart' show UserModel;
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FansPage extends StatefulWidget {
  const FansPage({
    super.key,
    this.mid,
    this.onSelect,
  });

  final int? mid;
  final ValueChanged<UserModel>? onSelect;

  @override
  State<FansPage> createState() => _FansPageState();
}

class _FansPageState extends State<FansPage> {
  late int mid;
  String? name;
  late bool isOwner;
  late FansController _fansController;

  @override
  void initState() {
    super.initState();
    AccountService accountService = Get.find<AccountService>();
    mid =
        widget.mid ??
        (Get.parameters['mid'] != null
            ? int.parse(Get.parameters['mid']!)
            : accountService.mid);
    isOwner = mid == accountService.mid;
    name = Get.parameters['name'] ?? accountService.name.value;
    _fansController = Get.put(FansController(mid), tag: Utils.makeHeroTag(mid));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.mid != null
          ? null
          : AppBar(title: Text(isOwner ? '我的粉丝' : '$name的粉丝')),
      body: SafeArea(
        bottom: false,
        child: refreshIndicator(
          onRefresh: _fansController.onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: _fansController.scrollController,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 80,
                ),
                sliver: Obx(
                  () => _buildBody(_fansController.loadingState.value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(LoadingState<List<FansItemModel>?> loadingState) {
    return switch (loadingState) {
      Loading() => SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: Grid.smallCardWidth * 2,
          mainAxisExtent: 66,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return const MsgFeedTopSkeleton();
          },
          childCount: 16,
        ),
      ),
      Success(:var response) =>
        response?.isNotEmpty == true
            ? SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: Grid.smallCardWidth * 2,
                  mainAxisExtent: 66,
                ),
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    if (index == response.length - 1) {
                      _fansController.onLoadMore();
                    }
                    final item = response[index];
                    return ListTile(
                      onTap: () {
                        if (widget.onSelect != null) {
                          widget.onSelect!(
                            UserModel(
                              mid: item.mid!,
                              name: item.uname!,
                              avatar: item.face!,
                            ),
                          );
                          return;
                        }
                        Get.toNamed('/member?mid=${item.mid}');
                      },
                      onLongPress: widget.onSelect != null
                          ? null
                          : isOwner
                          ? () => showConfirmDialog(
                              context: context,
                              title: '确定移除 ${item.uname} ？',
                              onConfirm: () =>
                                  _fansController.onRemoveFan(index, item.mid!),
                            )
                          : null,
                      leading: NetworkImgLayer(
                        width: 45,
                        height: 45,
                        type: ImageType.avatar,
                        src: item.face,
                      ),
                      title: Text(
                        item.uname!,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        item.sign ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      dense: true,
                      trailing: const SizedBox(width: 6),
                    );
                  },
                  childCount: response!.length,
                ),
              )
            : HttpError(
                onReload: _fansController.onReload,
              ),
      Error(:var errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _fansController.onReload,
      ),
    };
  }
}

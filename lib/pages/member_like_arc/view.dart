import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/refresh_indicator.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/member/coin_like_arc/item.dart';
import 'package:PiliPlus/pages/member_coin_arc/widgets/item.dart';
import 'package:PiliPlus/pages/member_like_arc/controller.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MemberLikeArcPage extends StatefulWidget {
  const MemberLikeArcPage({
    super.key,
    required this.mid,
    this.name,
  });

  final dynamic mid;
  final String? name;

  @override
  State<MemberLikeArcPage> createState() => _MemberLikeArcPageState();
}

class _MemberLikeArcPageState extends State<MemberLikeArcPage> {
  AccountService accountService = Get.find<AccountService>();

  late final _ctr = Get.put(
    MemberLikeArcController(mid: widget.mid),
    tag: Utils.makeHeroTag(widget.mid),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.mid == accountService.mid ? '我' : '${widget.name}'}的推荐',
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: refreshIndicator(
          onRefresh: _ctr.onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  top: StyleString.safeSpace - 5,
                  left: StyleString.safeSpace,
                  right: StyleString.safeSpace,
                  bottom: MediaQuery.paddingOf(context).bottom + 80,
                ),
                sliver: Obx(() => _buildBody(_ctr.loadingState.value)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(LoadingState<List<CoinLikeArcItem>?> loadingState) {
    return switch (loadingState) {
      Loading() => SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithExtentAndRatio(
          mainAxisSpacing: StyleString.cardSpace,
          crossAxisSpacing: StyleString.cardSpace,
          maxCrossAxisExtent: Grid.smallCardWidth,
          childAspectRatio: StyleString.aspectRatio,
          mainAxisExtent: MediaQuery.textScalerOf(context).scale(90),
        ),
        itemCount: 16,
        itemBuilder: (context, index) {
          return const VideoCardVSkeleton();
        },
      ),
      Success(:var response) =>
        response?.isNotEmpty == true
            ? SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithExtentAndRatio(
                  mainAxisSpacing: StyleString.cardSpace,
                  crossAxisSpacing: StyleString.cardSpace,
                  maxCrossAxisExtent: Grid.smallCardWidth,
                  childAspectRatio: StyleString.aspectRatio,
                  mainAxisExtent: MediaQuery.textScalerOf(context).scale(75),
                ),
                itemCount: response!.length,
                itemBuilder: (context, index) {
                  if (index == response.length - 1) {
                    _ctr.onLoadMore();
                  }
                  return MemberCoinLikeItem(item: response[index]);
                },
              )
            : HttpError(onReload: _ctr.onReload),
      Error(:var errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _ctr.onReload,
      ),
    };
  }
}

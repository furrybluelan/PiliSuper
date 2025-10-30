import 'package:PiliSuper/common/constants.dart';
import 'package:PiliSuper/common/skeleton/space_opus.dart';
import 'package:PiliSuper/common/widgets/loading_widget/http_error.dart';
import 'package:PiliSuper/common/widgets/refresh_indicator.dart';
import 'package:PiliSuper/http/loading_state.dart';
import 'package:PiliSuper/models_new/space/space_shop/item.dart';
import 'package:PiliSuper/pages/member_shop/controller.dart';
import 'package:PiliSuper/pages/member_shop/widgets/item.dart';
import 'package:PiliSuper/utils/extension.dart';
import 'package:PiliSuper/utils/grid.dart';
import 'package:PiliSuper/utils/waterfall.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waterfall_flow/waterfall_flow.dart'
    hide SliverWaterfallFlowDelegateWithMaxCrossAxisExtent;

class MemberShop extends StatefulWidget {
  const MemberShop({
    super.key,
    required this.heroTag,
    required this.mid,
  });

  final String? heroTag;
  final int mid;

  @override
  State<MemberShop> createState() => _MemberShopState();
}

class _MemberShopState extends State<MemberShop>
    with AutomaticKeepAliveClientMixin {
  late final _controller = Get.put(
    MemberShopController(widget.mid),
    tag: widget.heroTag,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return refreshIndicator(
      onRefresh: _controller.onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: 12,
              left: StyleString.safeSpace,
              right: StyleString.safeSpace,
              bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
            ),
            sliver: Obx(() => _buildBody(_controller.loadingState.value)),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  late double _maxWidth;

  late final gridDelegate = SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: Grid.smallCardWidth,
    mainAxisSpacing: StyleString.safeSpace,
    crossAxisSpacing: StyleString.safeSpace,
    callback: (value) => _maxWidth = value,
  );

  Widget _buildBody(LoadingState<List<SpaceShopItem>?> loadingState) {
    switch (loadingState) {
      case Loading():
        return SliverWaterfallFlow(
          gridDelegate: gridDelegate,
          delegate: SliverChildBuilderDelegate(
            (context, index) => const SpaceOpusSkeleton(),
            childCount: 10,
          ),
        );
      case Success(:var response):
        if (response.isNullOrEmpty) {
          return HttpError(onReload: _controller.onReload);
        }
        Widget sliver = SliverWaterfallFlow(
          gridDelegate: gridDelegate,
          delegate: SliverChildBuilderDelegate(
            (_, index) {
              return MemberShopItem(
                item: response[index],
                maxWidth: _maxWidth,
              );
            },
            childCount: response!.length,
          ),
        );
        if (_controller.showMoreTab == true) {
          sliver = SliverMainAxisGroup(
            slivers: [
              sliver,
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 25),
                  child: Center(
                    child: FilledButton.tonal(
                      onPressed: () {
                        if (_controller.clickUrl case final clickUrl?) {
                          final url = Uri.parse(
                            clickUrl,
                          ).queryParameters['url'];
                          if (url case final url?) {
                            Get.toNamed(
                              '/webview',
                              parameters: {'url': url},
                            );
                          }
                        }
                      },
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(_controller.showMoreDesc ?? ''),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return sliver;
      case Error(:var errMsg):
        return HttpError(
          errMsg: errMsg,
          onReload: _controller.onReload,
        );
    }
  }
}

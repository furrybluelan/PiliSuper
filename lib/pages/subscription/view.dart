import 'package:PiliPlus/common/skeleton/video_card_h.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/refresh_indicator.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/sub/sub/list.dart';
import 'package:PiliPlus/pages/subscription/controller.dart';
import 'package:PiliPlus/pages/subscription/widgets/item.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SubPage extends StatefulWidget {
  const SubPage({super.key});

  @override
  State<SubPage> createState() => _SubPageState();
}

class _SubPageState extends State<SubPage> {
  final SubController _subController = Get.put(SubController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的订阅')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: refreshIndicator(
          onRefresh: _subController.onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              Obx(() => _buildBody(_subController.loadingState.value)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 80,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(LoadingState<List<SubItemModel>?> loadingState) {
    return switch (loadingState) {
      Loading() => SliverGrid(
        gridDelegate: Grid.videoCardHDelegate(context),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const VideoCardHSkeleton(),
          childCount: 10,
        ),
      ),
      Success(:var response) =>
        response?.isNotEmpty == true
            ? SliverGrid(
                gridDelegate: Grid.videoCardHDelegate(context),
                delegate: SliverChildBuilderDelegate(
                  childCount: response!.length,
                  (BuildContext context, int index) {
                    if (index == response.length - 1) {
                      _subController.onLoadMore();
                    }
                    final item = response[index];
                    return SubItem(
                      item: item,
                      cancelSub: () => _subController.cancelSub(item),
                    );
                  },
                ),
              )
            : HttpError(
                onReload: _subController.onReload,
              ),
      Error(:var errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _subController.onReload,
      ),
    };
  }
}

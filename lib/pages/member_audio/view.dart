import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/loading_widget/loading_widget.dart';
import 'package:PiliPlus/common/widgets/refresh_indicator.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/space/space_audio/item.dart';
import 'package:PiliPlus/pages/member_audio/controller.dart';
import 'package:PiliPlus/pages/member_audio/widgets/item.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MemberAudio extends StatefulWidget {
  const MemberAudio({
    super.key,
    required this.heroTag,
    required this.mid,
  });

  final String? heroTag;
  final int mid;

  @override
  State<MemberAudio> createState() => _MemberAudioState();
}

class _MemberAudioState extends State<MemberAudio>
    with AutomaticKeepAliveClientMixin {
  late final _controller = Get.put(
    MemberAudioController(widget.mid),
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
              bottom: MediaQuery.paddingOf(context).bottom + 80,
            ),
            sliver: Obx(() => _buildBody(_controller.loadingState.value)),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildBody(LoadingState<List<SpaceAudioItem>?> loadingState) {
    return switch (loadingState) {
      Loading() => linearLoading,
      Success(:var response) =>
        response?.isNotEmpty == true
            ? SliverGrid(
                gridDelegate: SliverGridDelegateWithExtentAndRatio(
                  mainAxisSpacing: 2,
                  maxCrossAxisExtent: Grid.smallCardWidth * 2,
                  childAspectRatio: StyleString.aspectRatio * 2.6,
                  minHeight: MediaQuery.textScalerOf(context).scale(90),
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == response.length - 1) {
                      _controller.onLoadMore();
                    }
                    return MemberAudioItem(
                      item: response[index],
                    );
                  },
                  childCount: response!.length,
                ),
              )
            : HttpError(onReload: _controller.onReload),
      Error(:var errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _controller.onReload,
      ),
    };
  }
}

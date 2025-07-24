import 'dart:math';

import 'package:PiliPlus/common/widgets/custom_tooltip.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/loading_widget/loading_widget.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/models_new/live/live_emote/datum.dart';
import 'package:PiliPlus/models_new/live/live_emote/emoticon.dart';
import 'package:PiliPlus/pages/live_emote/controller.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LiveEmotePanel extends StatefulWidget {
  final int roomId;
  final Function(Emoticon emote, double? width, double? height) onChoose;
  final ValueChanged<Emoticon> onSendEmoticonUnique;
  const LiveEmotePanel({
    super.key,
    required this.roomId,
    required this.onChoose,
    required this.onSendEmoticonUnique,
  });

  @override
  State<LiveEmotePanel> createState() => _LiveEmotePanelState();
}

class _LiveEmotePanelState extends State<LiveEmotePanel>
    with AutomaticKeepAliveClientMixin {
  late final LiveEmotePanelController _emotePanelController = Get.put(
    LiveEmotePanelController(widget.roomId),
    tag: widget.roomId.toString(),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Obx(() => _buildBody(_emotePanelController.loadingState.value));
  }

  Widget _buildBody(LoadingState<List<LiveEmoteDatum>?> loadingState) {
    late final color = Theme.of(context).colorScheme.onInverseSurface;
    return switch (loadingState) {
      Loading() => loadingWidget,
      Success(:var response) =>
        response?.isNotEmpty == true
            ? Column(
                children: [
                  Expanded(
                    child: tabBarView(
                      controller: _emotePanelController.tabController,
                      children: response!.map(
                        (item) {
                          if (item.emoticons.isNullOrEmpty) {
                            return const SizedBox.shrink();
                          }
                          double widthFac = max(
                            1,
                            item.emoticons!.first.width! / 80,
                          );
                          double heightFac = max(
                            1,
                            item.emoticons!.first.height! / 80,
                          );
                          final width = widthFac * 38;
                          final height = heightFac * 38;
                          return GridView.builder(
                            padding: const EdgeInsets.only(
                              left: 12,
                              right: 12,
                              bottom: 12,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: widthFac * 40,
                                  mainAxisExtent: heightFac * 40,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: item.emoticons!.length,
                            itemBuilder: (context, index) {
                              final e = item.emoticons![index];
                              return Material(
                                type: MaterialType.transparency,
                                child: InkWell(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(6),
                                  ),
                                  onTap: () {
                                    if (item.pkgType == 3) {
                                      widget.onChoose(e, width, height);
                                    } else {
                                      widget.onSendEmoticonUnique(e);
                                    }
                                  },
                                  child: CustomTooltip(
                                    indicator: () => CustomPaint(
                                      size: const Size(14, 8),
                                      painter: TrianglePainter(color),
                                    ),
                                    overlayWidget: () => Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(8),
                                        ),
                                      ),
                                      child: Column(
                                        spacing: 4,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          NetworkImgLayer(
                                            src: e.url!,
                                            width: 65,
                                            height: 65,
                                            type: ImageType.emote,
                                            boxFit: BoxFit.contain,
                                          ),
                                          Text(
                                            e.emoji!.startsWith('[')
                                                ? e.emoji!.substring(
                                                    1,
                                                    e.emoji!.length - 1,
                                                  )
                                                : e.emoji!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: NetworkImgLayer(
                                        boxFit: BoxFit.contain,
                                        src: e.url!,
                                        width: width,
                                        height: height,
                                        type: ImageType.emote,
                                        quality: item.pkgType == 3 ? null : 80,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ).toList(),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.1),
                  ),
                  TabBar(
                    controller: _emotePanelController.tabController,
                    padding: const EdgeInsets.only(right: 60),
                    dividerColor: Colors.transparent,
                    dividerHeight: 0,
                    isScrollable: true,
                    tabs: response
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.all(8),
                            child: NetworkImgLayer(
                              width: 24,
                              height: 24,
                              type: ImageType.emote,
                              src: item.currentCover,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom),
                ],
              )
            : _errorWidget(),
      Error(:var errMsg) => _errorWidget(errMsg),
    };
  }

  Widget _errorWidget([String? errMsg]) => Center(
    child: TextButton.icon(
      onPressed: _emotePanelController.onReload,
      icon: const Icon(Icons.refresh),
      label: Text(errMsg ?? '没有数据'),
    ),
  );
}

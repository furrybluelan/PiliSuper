import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/custom_tooltip.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/loading_widget/loading_widget.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/models_new/emote/emote.dart';
import 'package:PiliPlus/models_new/emote/package.dart';
import 'package:PiliPlus/pages/emote/controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EmotePanel extends StatefulWidget {
  final Function(Emote emote, double? width, double? height) onChoose;

  const EmotePanel({super.key, required this.onChoose});

  @override
  State<EmotePanel> createState() => _EmotePanelState();
}

class _EmotePanelState extends State<EmotePanel>
    with AutomaticKeepAliveClientMixin {
  final EmotePanelController _emotePanelController = Get.put(
    EmotePanelController(),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ThemeData theme = Theme.of(context);
    return Obx(
      () => _buildBody(theme, _emotePanelController.loadingState.value),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    LoadingState<List<Package>?> loadingState,
  ) {
    late final color = Get.currentRoute.startsWith('/whisperDetail')
        ? theme.colorScheme.surface
        : theme.colorScheme.onInverseSurface;
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
                        (e) {
                          double size = e.emote!.first.meta!.size == 1
                              ? 40
                              : 60;
                          bool isTextEmote = e.type == 4;
                          return GridView.builder(
                            padding: const EdgeInsets.only(
                              left: 12,
                              right: 12,
                              bottom: 12,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: isTextEmote ? 100 : size,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  mainAxisExtent: size,
                                ),
                            itemCount: e.emote!.length,
                            itemBuilder: (context, index) {
                              final item = e.emote![index];
                              Widget child = Padding(
                                padding: const EdgeInsets.all(6),
                                child: isTextEmote
                                    ? Center(
                                        child: Text(
                                          item.text!,
                                          overflow: TextOverflow.clip,
                                          maxLines: 1,
                                        ),
                                      )
                                    : NetworkImgLayer(
                                        src: item.url!,
                                        width: size,
                                        height: size,
                                        type: ImageType.emote,
                                        boxFit: BoxFit.contain,
                                      ),
                              );
                              if (!isTextEmote) {
                                child = CustomTooltip(
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
                                          src: item.url!,
                                          width: 65,
                                          height: 65,
                                          type: ImageType.emote,
                                          boxFit: BoxFit.contain,
                                        ),
                                        Text(
                                          item.meta?.alias ??
                                              item.text!.substring(
                                                1,
                                                item.text!.length - 1,
                                              ),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  child: child,
                                );
                              }
                              return Material(
                                type: MaterialType.transparency,
                                child: InkWell(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(6),
                                  ),
                                  onTap: () => widget.onChoose(
                                    item,
                                    isTextEmote
                                        ? null
                                        : e.emote!.first.meta!.size == 1
                                        ? 24
                                        : 42,
                                    null,
                                  ),
                                  child: child,
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
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: iconButton(
                          iconSize: 20,
                          iconColor: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.8),
                          bgColor: Colors.transparent,
                          context: context,
                          onPressed: () => Get.toNamed(
                            '/webview',
                            parameters: {
                              'url':
                                  'https://www.bilibili.com/h5/mall/emoji-package/home?navhide=1&native.theme=1&night=${Get.isDarkMode ? 1 : 0}',
                            },
                          ),
                          icon: Icons.settings,
                        ),
                      ),
                      Expanded(
                        child: Material(
                          type: MaterialType.transparency,
                          child: TabBar(
                            controller: _emotePanelController.tabController,
                            padding: const EdgeInsets.only(right: 60),
                            dividerColor: Colors.transparent,
                            dividerHeight: 0,
                            isScrollable: true,
                            tabs: response
                                .map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: NetworkImgLayer(
                                      width: 24,
                                      height: 24,
                                      type: ImageType.emote,
                                      src: e.url,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ],
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

import 'dart:async';

import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/common/widgets/progress_bar/segment_progress_bar.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/view.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

class BottomControl extends StatelessWidget {
  final PlPlayerController controller;
  final Function buildBottomControl;
  const BottomControl({
    required this.controller,
    required this.buildBottomControl,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color colorTheme = theme.colorScheme.primary;
    //阅读器限制
    Timer? accessibilityDebounce;
    double lastAnnouncedValue = -1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(
            () {
              final int value = controller.sliderPositionSeconds.value;
              final int max = controller.durationSeconds.value.inSeconds;
              final int buffer = controller.bufferedSeconds.value;
              if (value > max || max <= 0) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 7),
                child: Semantics(
                  value: '${(value / max * 100).round()}%',
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      if (controller.dmTrend.isNotEmpty &&
                          controller.showDmTreandChart.value)
                        buildDmChart(theme, controller, 4.5),
                      if (controller.viewPointList.isNotEmpty &&
                          controller.showVP.value)
                        buildViewPointWidget(controller, 8.75),
                      ProgressBar(
                        progress: Duration(seconds: value),
                        buffered: Duration(seconds: buffer),
                        total: Duration(seconds: max),
                        progressBarColor: colorTheme,
                        baseBarColor: Colors.white.withValues(alpha: 0.2),
                        bufferedBarColor: colorTheme.withValues(alpha: 0.4),
                        timeLabelLocation: TimeLabelLocation.none,
                        thumbColor: colorTheme,
                        barHeight: 3.5,
                        thumbRadius: 7,
                        onDragStart: (duration) {
                          feedBack();
                          controller.onChangedSliderStart(duration.timeStamp);
                        },
                        onDragUpdate: (duration) {
                          double newProgress =
                              duration.timeStamp.inSeconds / max;
                          if (controller.showSeekPreview) {
                            if (!controller.showPreview.value) {
                              controller.showPreview.value = true;
                            }
                            controller.previewDx.value =
                                duration.localPosition.dx;
                          }
                          if ((newProgress - lastAnnouncedValue).abs() > 0.02) {
                            accessibilityDebounce?.cancel();
                            accessibilityDebounce = Timer(
                              const Duration(milliseconds: 200),
                              () {
                                SemanticsService.announce(
                                  "${(newProgress * 100).round()}%",
                                  TextDirection.ltr,
                                );
                                lastAnnouncedValue = newProgress;
                              },
                            );
                          }
                          controller.onUpdatedSliderProgress(
                            duration.timeStamp,
                          );
                        },
                        onSeek: (duration) {
                          if (controller.showSeekPreview) {
                            controller.showPreview.value = false;
                          }
                          controller
                            ..onChangedSliderEnd()
                            ..onChangedSlider(duration.inSeconds.toDouble())
                            ..seekTo(
                              Duration(seconds: duration.inSeconds),
                              isSeek: false,
                            );
                          SemanticsService.announce(
                            "${(duration.inSeconds / max * 100).round()}%",
                            TextDirection.ltr,
                          );
                        },
                      ),
                      if (controller.segmentList.isNotEmpty)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 5.25,
                          child: IgnorePointer(
                            child: CustomPaint(
                              size: const Size(double.infinity, 3.5),
                              painter: SegmentProgressBar(
                                segmentColors: controller.segmentList,
                              ),
                            ),
                          ),
                        ),
                      if (controller.viewPointList.isNotEmpty &&
                          controller.showVP.value)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 5.25,
                          child: IgnorePointer(
                            child: CustomPaint(
                              size: const Size(double.infinity, 3.5),
                              painter: SegmentProgressBar(
                                segmentColors: controller.viewPointList,
                              ),
                            ),
                          ),
                        ),
                      if (controller.showSeekPreview &&
                          controller.showControls.value)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 18,
                          child: buildSeekPreviewWidget(controller),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          buildBottomControl(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

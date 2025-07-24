import 'package:PiliPlus/common/skeleton/video_reply.dart';
import 'package:PiliPlus/common/widgets/custom_sliver_persistent_header_delegate.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/refresh_indicator.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/models_new/match/match_info/contest.dart';
import 'package:PiliPlus/models_new/match/match_info/team.dart';
import 'package:PiliPlus/pages/match_info/controller.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_item_grpc.dart';
import 'package:PiliPlus/pages/video/reply_reply/view.dart';
import 'package:PiliPlus/utils/date_util.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/num_util.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class MatchInfoPage extends StatefulWidget {
  const MatchInfoPage({super.key});

  @override
  State<MatchInfoPage> createState() => _MatchInfoPageState();
}

class _MatchInfoPageState extends State<MatchInfoPage> {
  final _controller = Get.put(
    MatchInfoController(),
    tag: Utils.generateRandomString(8),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('比赛详情')),
      body: SafeArea(
        bottom: false,
        child: refreshIndicator(
          onRefresh: _controller.onRefresh,
          child: CustomScrollView(
            controller: _controller.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              Obx(() => _buildInfo(theme, _controller.infoState.value)),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 80,
                ),
                sliver: Obx(
                  () => _buildReply(theme, _controller.loadingState.value),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () {
          feedBack();
          _controller.onReply(
            context,
            oid: _controller.cid,
            replyType: _controller.replyType,
          );
        },
        tooltip: '评论动态',
        child: const Icon(Icons.reply),
      ),
    );
  }

  Widget _buildInfo(ThemeData theme, LoadingState<MatchContest?> infoState) {
    if (infoState.isSuccess) {
      MatchContest? data = infoState.dataOrNull;
      if (data != null) {
        try {
          Widget teamInfo(MatchTeam team) {
            return Column(
              spacing: 5,
              mainAxisSize: MainAxisSize.min,
              children: [
                NetworkImgLayer(
                  width: 50,
                  height: 50,
                  src: 'https://i1.hdslb.com${team.logo}',
                  type: ImageType.emote,
                ),
                Text(team.title!),
              ],
            );
          }

          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                spacing: 12,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Text(
                      '${data.season?.title ?? ''}  ${data.gameStage ?? ''}',
                    ),
                  ),
                  Row(
                    spacing: 20,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data.homeId != 0)
                        Expanded(
                          child: Align(
                            alignment: const Alignment(0.8, 1),
                            child: teamInfo(data.homeTeam!),
                          ),
                        ),
                      Column(
                        spacing: 10,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (data.homeId != 0)
                            Text(
                              data.contestStatus == 1
                                  ? 'VS'
                                  : '${data.homeScore} : ${data.awayScore}',
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else if (data.season?.logo != null)
                            NetworkImgLayer(
                              width: 50,
                              height: 50,
                              src: 'https://i1.hdslb.com${data.season!.logo}',
                              type: ImageType.emote,
                            ),
                          if (data.contestStatus == 2)
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(6),
                                  ),
                                ),
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => Get.toNamed(
                                '/liveRoom?roomid=${data.liveRoom}',
                              ),
                              child: const Text('看直播'),
                            )
                          else if (data.contestStatus == 3)
                            Text(
                              '${DateUtil.dateFormat(data.stime)}${data.contestStatus == 3 ? ' 已结束' : ''}',
                              style: TextStyle(
                                color: theme.colorScheme.outline,
                              ),
                            )
                          else if (data.contestStatus == 1)
                            Text(
                              DateUtil.format(
                                data.stime,
                                format: DateFormat('yy-MM-dd HH:mm'),
                              ),
                              style: TextStyle(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                        ],
                      ),
                      if (data.awayId != 0)
                        Expanded(
                          child: Align(
                            alignment: const Alignment(-0.8, -1),
                            child: teamInfo(data.awayTeam!),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        } catch (_) {
          return const SliverToBoxAdapter();
        }
      }
    }
    return const SliverToBoxAdapter();
  }

  Widget _buildReply(
    ThemeData theme,
    LoadingState<List<ReplyInfo>?> loadingState,
  ) {
    return switch (loadingState) {
      Loading() => SliverList.builder(
        itemBuilder: (context, index) => const VideoReplySkeleton(),
        itemCount: 8,
      ),
      Success(:var response) =>
        response?.isNotEmpty == true
            ? SliverMainAxisGroup(
                slivers: [
                  _buildHeader(theme),
                  SliverList.builder(
                    itemCount: response!.length,
                    itemBuilder: (context, index) {
                      if (index == response.length - 1) {
                        _controller.onLoadMore();
                      }
                      return ReplyItemGrpc(
                        replyItem: response[index],
                        replyLevel: 1,
                        replyReply: (replyItem, id) =>
                            replyReply(context, replyItem, id),
                        onReply: (replyItem) => _controller.onReply(
                          context,
                          replyItem: replyItem,
                        ),
                        onDelete: (item, subIndex) =>
                            _controller.onRemove(index, item, subIndex),
                        upMid: _controller.upMid,
                        onCheckReply: (item) =>
                            _controller.onCheckReply(item, isManual: true),
                        onToggleTop: (item) => _controller.onToggleTop(
                          item,
                          index,
                          _controller.cid,
                          _controller.replyType,
                        ),
                      );
                    },
                  ),
                ],
              )
            : HttpError(onReload: _controller.onReload),
      Error(:var errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _controller.onReload,
      ),
    };
  }

  void replyReply(BuildContext context, ReplyInfo replyItem, int? id) {
    EasyThrottle.throttle('replyReply', const Duration(milliseconds: 500), () {
      int oid = replyItem.oid.toInt();
      int rpid = replyItem.id.toInt();
      Get.to(
        Scaffold(
          appBar: AppBar(title: const Text('评论详情')),
          body: SafeArea(
            top: false,
            bottom: false,
            child: VideoReplyReplyPanel(
              enableSlide: false,
              id: id,
              oid: oid,
              rpid: rpid,
              isVideoDetail: false,
              replyType: _controller.replyType,
              firstFloor: replyItem,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildHeader(ThemeData theme) {
    return SliverPersistentHeader(
      delegate: CustomSliverPersistentHeaderDelegate(
        bgColor: theme.colorScheme.surface,
        child: Container(
          height: 45,
          padding: const EdgeInsets.only(left: 12, right: 6),
          child: Row(
            children: [
              Obx(
                () {
                  final count = _controller.count.value;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                    child: Text(
                      '${count == -1 ? 0 : NumUtil.numFormat(count)}条回复',
                      key: ValueKey<int>(count),
                    ),
                  );
                },
              ),
              const Spacer(),
              SizedBox(
                height: 35,
                child: TextButton.icon(
                  onPressed: _controller.queryBySort,
                  icon: Icon(
                    Icons.sort,
                    size: 16,
                    color: theme.colorScheme.secondary,
                  ),
                  label: Obx(
                    () => Text(
                      _controller.sortType.value.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      pinned: true,
    );
  }
}

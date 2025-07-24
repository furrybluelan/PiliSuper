import 'dart:async';
import 'dart:math';

import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PagesPanel extends StatefulWidget {
  const PagesPanel({
    super.key,
    this.list,
    this.cover,
    required this.bvid,
    required this.heroTag,
    this.showEpisodes,
    required this.videoIntroController,
  });

  final List<Part>? list;
  final String? cover;

  final String bvid;
  final String heroTag;
  final Function? showEpisodes;
  final VideoIntroController videoIntroController;

  @override
  State<PagesPanel> createState() => _PagesPanelState();
}

class _PagesPanelState extends State<PagesPanel> {
  late int cid;
  int pageIndex = -1;
  late VideoDetailController _videoDetailController;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _listener;

  List<Part> get pages =>
      widget.list ?? widget.videoIntroController.videoDetail.value.pages!;

  @override
  void initState() {
    super.initState();
    _videoDetailController = Get.find<VideoDetailController>(
      tag: widget.heroTag,
    );
    if (widget.list == null) {
      cid = widget.videoIntroController.lastPlayCid.value;
      pageIndex = pages.indexWhere((Part e) => e.cid == cid);
      _listener = _videoDetailController.cid.listen((int cid) {
        this.cid = cid;
        pageIndex = max(0, pages.indexWhere((Part e) => e.cid == cid));
        if (!mounted) return;
        setState(() {});
        jumpToCurr();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        jumpToCurr();
      });
    }
  }

  void jumpToCurr() {
    if (!_scrollController.hasClients || pages.isEmpty) {
      return;
    }
    const double itemWidth = 150;
    final double targetOffset = (pageIndex * itemWidth - itemWidth / 2).clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _listener?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        if (widget.showEpisodes != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('视频选集 '),
                Expanded(
                  child: Text(
                    ' 正在播放：${pages[pageIndex].pagePart}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 34,
                  child: TextButton(
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(EdgeInsets.zero),
                    ),
                    onPressed: () => widget.showEpisodes!(
                      null,
                      null,
                      pages,
                      widget.bvid,
                      IdUtils.bv2av(widget.bvid),
                      cid,
                    ),
                    child: Text(
                      '共${pages.length}集',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 35,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: pages.length,
            itemExtent: 150,
            itemBuilder: (BuildContext context, int i) {
              bool isCurrentIndex = pageIndex == i;
              final item = pages[i];
              return Container(
                width: 150,
                margin: EdgeInsets.only(
                  right: i != pages.length - 1 ? 10 : 0,
                ),
                child: Material(
                  color: theme.colorScheme.onInverseSurface,
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                  child: InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                    onTap: () {
                      if (widget.showEpisodes == null) {
                        Get.back();
                      }
                      widget.videoIntroController.changeSeasonOrbangu(
                        null,
                        widget.bvid,
                        item.cid,
                        IdUtils.bv2av(widget.bvid),
                        widget.cover,
                      );
                      if (widget.list != null &&
                          widget
                                  .videoIntroController
                                  .videoDetail
                                  .value
                                  .ugcSeason !=
                              null) {
                        _videoDetailController.seasonCid = pages.first.cid;
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: <Widget>[
                          if (isCurrentIndex) ...<Widget>[
                            Image.asset(
                              'assets/images/live.png',
                              color: theme.colorScheme.primary,
                              height: 12,
                              semanticLabel: "正在播放：",
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              item.pagePart!,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 13,
                                color: isCurrentIndex
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/models_new/space/space_archive/item.dart';
import 'package:PiliPlus/pages/local_block/local_block_type.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
import 'package:PiliPlus/pages/video/ai_conclusion/view.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/ban_word_utils.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class _VideoCustomAction {
  final String title;
  final Widget icon;
  final VoidCallback onTap;
  const _VideoCustomAction(this.title, this.icon, this.onTap);
}

class VideoPopupMenu extends StatelessWidget {
  final double? iconSize;
  final double menuItemHeight;
  final BaseSimpleVideoItemModel videoItem;
  final VoidCallback? onRemove;

  const VideoPopupMenu({
    super.key,
    required this.iconSize,
    required this.videoItem,
    this.onRemove,
    this.menuItemHeight = 45,
  });

  Future<void> _addBlockedUser() async {
    final mid = videoItem.owner.mid;
    if (mid == null) {
      SmartDialog.showToast('无法获取用户ID');
      return;
    }
    final name = videoItem.owner.name ?? 'UID:$mid';
    final ok = await showConfirmDialog(
      context: Get.context!,
      title: const Text('确认本地屏蔽 UP'),
      content: Text('$name ($mid)'),
    );
    if (!ok) return;
    final blockedMids = Pref.recommendBlockedMids;
    blockedMids[mid] = name;
    Pref.recommendBlockedMids = blockedMids;
    GlobalData().recommendBlockedMids = blockedMids;
    RecommendFilter.recommendBlockedMids = blockedMids;
    SmartDialog.showToast('已本地屏蔽 $name($mid)');
    onRemove?.call();
  }

  Future<void> _appendKeyword({
    required LocalBlockType type,
    required String value,
    required String successMsg,
  }) async {
    final keyword = value.trim();
    if (keyword.isEmpty) {
      SmartDialog.showToast('内容为空');
      return;
    }
    final existing = type.loadRules();
    if (existing.contains(keyword)) {
      SmartDialog.showToast('已存在该屏蔽规则');
      onRemove?.call();
      return;
    }
    final ok = await showConfirmDialog(
      context: Get.context!,
      title: Text('确认加入${type.label}屏蔽'),
      content: Text(keyword),
    );
    if (!ok) return;
    type.appendRule(keyword);
    SmartDialog.showToast(successMsg);
    onRemove?.call();
  }

  String? _getZoneName() {
    // 分区 = tname（一级/二级分区名），不是 TAG/话题
    if (videoItem case HotVideoItemModel(:final tname)) {
      return tname;
    }
    if (videoItem case RcmdVideoItemAppModel(:final tname)) {
      return tname;
    }
    return null;
  }

  String? _getDesc() {
    if (videoItem case BaseVideoItemModel(:final desc)) {
      final d = desc?.trim();
      if (d != null && d.isNotEmpty) return d;
    }
    return null;
  }

  Future<void> _showCustomBlockDialog() async {
    LocalBlockType selected = LocalBlockType.title;
    final ctr = TextEditingController();
    final result = await showDialog<(LocalBlockType, String)>(
      context: Get.context!,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('自定义屏蔽'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<LocalBlockType>(
                    value: selected,
                    items: [
                      for (final t in LocalBlockType.values)
                        if (!t.isUp)
                          DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => selected = v);
                    },
                    decoration: const InputDecoration(labelText: '屏蔽类型'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctr,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: selected.addHint,
                      labelText: '规则（普通文字或 /正则/flags）',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: Get.back, child: const Text('取消')),
                TextButton(
                  onPressed: () =>
                      Get.back(result: (selected, ctr.text.trim())),
                  child: const Text('下一步'),
                ),
              ],
            );
          },
        );
      },
    );
    ctr.dispose();
    if (result == null) return;
    final (type, text) = result;
    if (text.isEmpty) {
      SmartDialog.showToast('内容为空');
      return;
    }
    await _appendKeyword(
      type: type,
      value: text,
      successMsg: '已加入${type.label}屏蔽',
    );
  }

  void _showLocalBlockDialog(BuildContext context) {
    final ownerName = videoItem.owner.name ?? '未知UP';
    final title = videoItem.title.trim();
    final zoneName = _getZoneName()?.trim();
    final desc = _getDesc();
    final colorScheme = Theme.of(context).colorScheme;

    Widget chip(String label, VoidCallback onTap) {
      return Material(
        color: colorScheme.onInverseSurface,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          onTap: onTap,
          onLongPress: () => Utils.copyText(label),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            child: Text(
              label,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('本地屏蔽'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '快捷选项（长按复制）',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    chip('UP主:$ownerName', () {
                      Get.back();
                      _addBlockedUser();
                    }),
                    if (title.isNotEmpty)
                      chip('标题:$title', () {
                        Get.back();
                        _appendKeyword(
                          type: LocalBlockType.title,
                          value: title,
                          successMsg: '已加入标题关键词屏蔽',
                        );
                      }),
                    chip(
                      zoneName?.isNotEmpty == true
                          ? '分区:$zoneName'
                          : '分区:无法获取',
                      () {
                        if (zoneName?.isNotEmpty != true) {
                          SmartDialog.showToast('当前视频无法获取分区信息');
                          return;
                        }
                        Get.back();
                        _appendKeyword(
                          type: LocalBlockType.zone,
                          value: zoneName!,
                          successMsg: '已加入分区关键词屏蔽',
                        );
                      },
                    ),
                    if (desc != null)
                      chip(
                        '简介:${desc.length > 40 ? '${desc.substring(0, 40)}…' : desc}',
                        () {
                          Get.back();
                          _appendKeyword(
                            type: LocalBlockType.desc,
                            value: desc,
                            successMsg: '已加入简介屏蔽',
                          );
                        },
                      ),
                    chip('自定义…', () {
                      Get.back();
                      _showCustomBlockDialog();
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '说明：分区为 tname；TAG/话题需在详情页或自定义中添加（卡片流通常无完整列表）',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
                Get.toNamed('/localBlock');
              },
              child: const Text('管理'),
            ),
            TextButton(onPressed: Get.back, child: const Text('取消')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_vert_outlined,
        color: Theme.of(context).colorScheme.outline,
        size: iconSize,
      ),
      position: PopupMenuPosition.under,
      itemBuilder: (context) =>
          [
                if (videoItem.bvid?.isNotEmpty == true) ...[
                  _VideoCustomAction(
                    videoItem.bvid!,
                    const Icon(CustomIcons.identifier_circle, size: 16),
                    () => Utils.copyText(videoItem.bvid!),
                  ),
                  _VideoCustomAction(
                    '稍后再看',
                    const Icon(MdiIcons.clockTimeEightOutline, size: 16),
                    () => UserHttp.toViewLater(bvid: videoItem.bvid),
                  ),
                  if (videoItem.cid != null && Pref.enableAi)
                    _VideoCustomAction(
                      'AI总结',
                      const Icon(CustomIcons.ai_circle, size: 16),
                      () async {
                        final res = await UgcIntroController.getAiConclusion(
                          videoItem.bvid!,
                          videoItem.cid!,
                          videoItem.owner.mid,
                        );
                        if (res != null && context.mounted) {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              child: Padding(
                                padding: const .symmetric(vertical: 14),
                                child: AiConclusionPanel.buildContent(
                                  context,
                                  Theme.of(context),
                                  res,
                                  tap: false,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                ],
                if (videoItem is! SpaceArchiveItem) ...[
                  _VideoCustomAction(
                    '访问：${videoItem.owner.name}',
                    const Icon(MdiIcons.accountCircleOutline, size: 16),
                    () => Get.toNamed('/member?mid=${videoItem.owner.mid}'),
                  ),
                  _VideoCustomAction(
                    '本地屏蔽',
                    const Icon(MdiIcons.accountOff, size: 16),
                    () => _showLocalBlockDialog(context),
                  ),
                  _VideoCustomAction(
                    '不感兴趣',
                    const Icon(MdiIcons.thumbDownOutline, size: 16),
                    () {
                      String? accessKey = Accounts.get(
                        AccountType.recommend,
                      ).accessKey;
                      if (accessKey == null || accessKey == "") {
                        SmartDialog.showToast("请退出账号后重新登录");
                        return;
                      }
                      if (videoItem case final RcmdVideoItemAppModel item) {
                        ThreePoint? tp = item.threePoint;
                        if (tp == null) {
                          SmartDialog.showToast("未能获取threePoint");
                          return;
                        }
                        if (tp.dislikeReasons == null && tp.feedbacks == null) {
                          SmartDialog.showToast(
                            "未能获取dislikeReasons或feedbacks",
                          );
                          return;
                        }
                        Widget actionButton(Reason? r, Reason? f) {
                          return SearchText(
                            text: r?.name ?? f?.name ?? '未知',
                            onTap: (_) async {
                              Get.back();
                              SmartDialog.showLoading(msg: '正在提交');
                              final res = await VideoHttp.feedDislike(
                                reasonId: r?.id,
                                feedbackId: f?.id,
                                id: item.param!,
                                goto: item.goto!,
                              );
                              SmartDialog.dismiss();
                              if (res.isSuccess) {
                                SmartDialog.showToast(
                                  r?.toast ?? f!.toast!,
                                );
                                onRemove?.call();
                              } else {
                                res.toast();
                              }
                            },
                          );
                        }

                        showDialog(
                          context: context,
                          builder: (context) {
                            return SimpleDialog(
                              contentPadding: const .fromLTRB(24, 16, 24, 24),
                              children: [
                                if (tp.dislikeReasons != null) ...[
                                  const Text('我不想看'),
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children: tp.dislikeReasons!
                                        .map((item) => actionButton(item, null))
                                        .toList(),
                                  ),
                                ],
                                if (tp.feedbacks != null) ...[
                                  const SizedBox(height: 5),
                                  const Text('反馈'),
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children: tp.feedbacks!
                                        .map((item) => actionButton(null, item))
                                        .toList(),
                                  ),
                                ],
                                const Divider(),
                                Center(
                                  child: FilledButton.tonal(
                                    onPressed: () async {
                                      SmartDialog.showLoading(
                                        msg: '正在提交',
                                      );
                                      final res =
                                          await VideoHttp.feedDislikeCancel(
                                            id: item.param!,
                                            goto: item.goto!,
                                          );
                                      SmartDialog.dismiss();
                                      SmartDialog.showToast(
                                        res.isSuccess ? "成功" : res.toString(),
                                      );
                                      Get.back();
                                    },
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text("撤销"),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      } else {
                        showDialog(
                          context: context,
                          builder: (context) => SimpleDialog(
                            contentPadding: const .all(24),
                            children: [
                              const Center(child: Text("web端暂不支持精细选择")),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 5.0,
                                runSpacing: 2.0,
                                alignment: .center,
                                children: [
                                  FilledButton.tonal(
                                    onPressed: () async {
                                      Get.back();
                                      SmartDialog.showLoading(msg: '正在提交');
                                      final res = await VideoHttp.dislikeVideo(
                                        bvid: videoItem.bvid!,
                                        type: true,
                                      );
                                      SmartDialog.dismiss();
                                      if (res.isSuccess) {
                                        SmartDialog.showToast('点踩成功');
                                        onRemove?.call();
                                      } else {
                                        res.toast();
                                      }
                                    },
                                    style: FilledButton.styleFrom(
                                      visualDensity: .compact,
                                    ),
                                    child: const Text("点踩"),
                                  ),
                                  FilledButton.tonal(
                                    onPressed: () async {
                                      Get.back();
                                      SmartDialog.showLoading(msg: '正在提交');
                                      final res = await VideoHttp.dislikeVideo(
                                        bvid: videoItem.bvid!,
                                        type: false,
                                      );
                                      SmartDialog.dismiss();
                                      SmartDialog.showToast(
                                        res.isSuccess ? '取消踩' : res.toString(),
                                      );
                                    },
                                    style: FilledButton.styleFrom(
                                      visualDensity: .compact,
                                    ),
                                    child: const Text("撤销"),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                  _VideoCustomAction(
                    '拉黑：${videoItem.owner.name}',
                    const Icon(MdiIcons.cancel, size: 16),
                    () => showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('提示'),
                          content: Text(
                            '确定拉黑:${videoItem.owner.name}(${videoItem.owner.mid})?'
                            '\n\n注：被拉黑的Up可以在隐私设置-黑名单管理中解除',
                          ),
                          actions: [
                            TextButton(
                              onPressed: Get.back,
                              child: Text(
                                '点错了',
                                style: TextStyle(
                                  color: ColorScheme.of(context).outline,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                Get.back();
                                final res = await VideoHttp.relationMod(
                                  mid: videoItem.owner.mid!,
                                  act: 5,
                                  reSrc: 11,
                                );
                                if (res.isSuccess) {
                                  onRemove?.call();
                                } else {
                                  res.toast();
                                }
                              },
                              child: const Text('确认'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                _VideoCustomAction(
                  "${MineController.anonymity.value ? '退出' : '进入'}无痕模式",
                  MineController.anonymity.value
                      ? const Icon(MdiIcons.incognitoOff, size: 16)
                      : const Icon(MdiIcons.incognito, size: 16),
                  MineController.onChangeAnonymity,
                ),
              ]
              .map(
                (e) => PopupMenuItem(
                  height: menuItemHeight,
                  onTap: e.onTap,
                  child: Row(
                    children: [
                      e.icon,
                      const SizedBox(width: 6),
                      Text(e.title, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }
}

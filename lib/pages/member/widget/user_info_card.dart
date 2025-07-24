import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/widgets/pendant_avatar.dart';
import 'package:PiliPlus/models/common/image_preview_type.dart';
import 'package:PiliPlus/models_new/space/space/card.dart';
import 'package:PiliPlus/models_new/space/space/images.dart';
import 'package:PiliPlus/models_new/space/space/live.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/image_util.dart';
import 'package:PiliPlus/utils/num_util.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UserInfoCard extends StatelessWidget {
  const UserInfoCard({
    super.key,
    required this.isV,
    required this.isOwner,
    required this.card,
    required this.images,
    required this.relation,
    required this.onFollow,
    this.live,
    this.silence,
  });

  final bool isV;
  final bool isOwner;
  final int relation;
  final SpaceCard card;
  final SpaceImages images;
  final VoidCallback onFollow;
  final Live? live;
  final int? silence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return isV ? _buildV(context, theme) : _buildH(context, theme);
  }

  Widget _countWidget({
    required ThemeData theme,
    required String title,
    required int? count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            NumUtil.numFormat(count),
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            title,
            style: TextStyle(
              height: 1.2,
              fontSize: 12,
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    bool darken = theme.brightness == Brightness.dark;
    String imgUrl =
        (darken
                ? images.nightImgurl?.isEmpty == true
                      ? images.imgUrl
                      : images.nightImgurl
                : images.imgUrl)
            .http2https;
    return Hero(
      tag: imgUrl,
      child: GestureDetector(
        onTap: () => context.imageView(
          imgList: [SourceModel(url: imgUrl)],
        ),
        child: CachedNetworkImage(
          imageUrl: ImageUtil.thumbnailUrl(imgUrl),
          width: double.infinity,
          height: 135,
          imageBuilder: (context, imageProvider) => DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  darken ? const Color(0x8D000000) : const Color(0x5DFFFFFF),
                  darken ? BlendMode.darken : BlendMode.lighten,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLeft(BuildContext context, ThemeData theme) => [
    Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 5),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Utils.copyText(card.name!),
            child: Text(
              card.name!,
              strutStyle: const StrutStyle(
                height: 1,
                leading: 0,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              style: TextStyle(
                height: 1,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: (card.vip?.status ?? -1) > 0 && card.vip?.type == 2
                    ? context.vipColor
                    : null,
              ),
            ),
          ),
          Image.asset(
            'assets/images/lv/lv${card.levelInfo?.identity == 2 ? '6_s' : card.levelInfo?.currentLevel}.png',
            height: 11,
            semanticLabel: '等级${card.levelInfo?.currentLevel}',
          ),
          if (card.vip?.status == 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: StyleString.mdRadius,
                color: context.vipColor,
              ),
              child: Text(
                card.vip?.label?.text ?? '大会员',
                strutStyle: const StrutStyle(
                  height: 1,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                style: const TextStyle(
                  height: 1,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
            ),
          if (card.nameplate?.imageSmall?.isNotEmpty == true)
            CachedNetworkImage(
              imageUrl: ImageUtil.thumbnailUrl(card.nameplate!.imageSmall!),
              height: 20,
              placeholder: (context, url) {
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
    ),
    if (card.officialVerify?.desc?.isNotEmpty == true)
      Container(
        margin: const EdgeInsets.only(left: 20, top: 8, right: 20),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          color: theme.colorScheme.onInverseSurface,
        ),
        child: Text.rich(
          TextSpan(
            children: [
              if (card.officialVerify?.icon?.isNotEmpty == true) ...[
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surface,
                    ),
                    child: Icon(
                      Icons.offline_bolt,
                      color: card.officialVerify?.type == 0
                          ? const Color(0xFFFFCC00)
                          : Colors.lightBlueAccent,
                      size: 18,
                    ),
                  ),
                ),
                const TextSpan(
                  text: ' ',
                ),
              ],
              TextSpan(
                text: card.officialVerify!.spliceTitle!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    if (card.sign?.isNotEmpty == true)
      Padding(
        padding: const EdgeInsets.only(left: 20, top: 6, right: 20),
        child: SelectableText(
          card.sign!.trim().replaceAll(RegExp(r'\n{2,}'), '\n'),
          style: const TextStyle(fontSize: 14),
        ),
      ),
    Padding(
      padding: const EdgeInsets.only(left: 20, top: 6, right: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          GestureDetector(
            onTap: () => Utils.copyText(card.mid.toString()),
            child: Text(
              'UID: ${card.mid}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          ...?card.spaceTag?.map(
            (item) => Text(
              item.title ?? '',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    ),
    if (silence == 1)
      Builder(
        builder: (context) {
          bool isLight = theme.brightness == Brightness.light;
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(6)),
              color: isLight
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.error,
            ),
            margin: const EdgeInsets.only(left: 20, top: 8, right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(
                      Icons.info,
                      size: 17,
                      color: isLight
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onError,
                    ),
                  ),
                  TextSpan(
                    text: ' 该账号封禁中',
                    style: TextStyle(
                      color: isLight
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onError,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
  ];

  Column _buildRight(BuildContext context, ThemeData theme) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: List.generate(
          5,
          (index) => index % 2 == 0
              ? _countWidget(
                  theme: theme,
                  title: ['粉丝', '关注', '获赞'][index ~/ 2],
                  count: index == 0
                      ? card.fans
                      : index == 2
                      ? card.attention
                      : card.likes?.likeNum,
                  onTap: () {
                    if (index == 0) {
                      Get.toNamed('/fan?mid=${card.mid}&name=${card.name}');
                    } else if (index == 2) {
                      Get.toNamed('/follow?mid=${card.mid}&name=${card.name}');
                    }
                  },
                )
              : const Expanded(
                  child: SizedBox(
                    height: 15,
                    width: 1,
                    child: VerticalDivider(),
                  ),
                ),
        ),
      ),
      const SizedBox(height: 5),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isOwner) ...[
            IconButton.outlined(
              onPressed: () {
                if (Accounts.main.isLogin) {
                  int mid = int.parse(card.mid!);
                  Get.toNamed(
                    '/whisperDetail',
                    arguments: {
                      'talkerId': mid,
                      'name': card.name,
                      'face': card.face,
                      'mid': mid,
                      'isLive': live?.liveStatus == 1,
                    },
                  );
                }
              },
              icon: const Icon(Icons.mail_outline, size: 21),
              style: IconButton.styleFrom(
                side: BorderSide(
                  width: 1.0,
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: FilledButton.tonal(
              onPressed: onFollow,
              style: FilledButton.styleFrom(
                backgroundColor: relation != 0
                    ? theme.colorScheme.onInverseSurface
                    : null,
                visualDensity: const VisualDensity(vertical: -1.8),
              ),
              child: Text.rich(
                style: TextStyle(
                  color: relation != 0 ? theme.colorScheme.outline : null,
                ),
                TextSpan(
                  children: [
                    if (relation != 0 && relation != 128) ...[
                      WidgetSpan(
                        alignment: PlaceholderAlignment.top,
                        child: Icon(
                          Icons.sort,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const TextSpan(text: ' '),
                    ],
                    TextSpan(
                      text: isOwner
                          ? '编辑资料'
                          : switch (relation) {
                              0 => '关注',
                              1 => '悄悄关注',
                              2 => '已关注',
                              // 3 => '回关',
                              4 || 6 => '已互关',
                              128 => '移除黑名单',
                              -10 => '特别关注', // 该状态码并不是官方状态码
                              _ => relation.toString(),
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Hero _buildAvatar(BuildContext context) => Hero(
    tag: card.face ?? '',
    child: PendantAvatar(
      avatar: card.face,
      size: 80,
      badgeSize: 22,
      officialType: card.officialVerify?.type,
      isVip: (card.vip?.status ?? -1) > 0,
      garbPendantImage: card.pendant!.image!,
      roomId: live?.liveStatus == 1 ? live!.roomid : null,
      onTap: () =>
          context.imageView(imgList: [SourceModel(url: card.face.http2https)]),
    ),
  );

  Column _buildV(BuildContext context, ThemeData theme) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, theme),
              SizedBox(
                width: double.infinity,
                height: MediaQuery.textScalerOf(context).scale(30) + 60,
              ),
            ],
          ),
          Positioned(
            top: 110,
            left: 20,
            child: _buildAvatar(context),
          ),
          Positioned(
            left: 160,
            top: 140,
            right: 15,
            bottom: 0,
            child: _buildRight(context, theme),
          ),
        ],
      ),
      ..._buildLeft(context, theme),
      if (card.prInfo?.content?.isNotEmpty == true) buildPrInfo(theme),
      const SizedBox(height: 5),
    ],
  );

  Widget buildPrInfo(ThemeData theme) => Builder(
    builder: (context) {
      final isDark = theme.brightness == Brightness.dark;
      final textColor = isDark
          ? Color(
              int.parse(
                'FF${card.prInfo?.textColorNight.substring(1)}',
                radix: 16,
              ),
            )
          : Color(
              int.parse('FF${card.prInfo?.textColor.substring(1)}', radix: 16),
            );
      return GestureDetector(
        onTap: () {
          if (card.prInfo?.url?.isNotEmpty == true) {
            PageUtils.handleWebview(card.prInfo!.url!);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isDark
              ? Color(
                  int.parse(
                    'FF${card.prInfo?.bgColorNight.substring(1)}',
                    radix: 16,
                  ),
                )
              : Color(
                  int.parse(
                    'FF${card.prInfo?.bgColor.substring(1)}',
                    radix: 16,
                  ),
                ),
          child: Row(
            children: [
              if (isDark && card.prInfo?.iconNight?.isNotEmpty == true) ...[
                CachedNetworkImage(
                  imageUrl: ImageUtil.thumbnailUrl(card.prInfo!.iconNight!),
                  height: 20,
                ),
                const SizedBox(width: 16),
              ] else if (card.prInfo?.icon?.isNotEmpty == true) ...[
                CachedNetworkImage(
                  imageUrl: ImageUtil.thumbnailUrl(card.prInfo!.icon!),
                  height: 20,
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Text(
                  card.prInfo!.content!,
                  style: TextStyle(fontSize: 13, color: textColor),
                ),
              ),
              if (card.prInfo?.url?.isNotEmpty == true) ...[
                const SizedBox(width: 10),
                Icon(
                  Icons.keyboard_arrow_right,
                  color: textColor,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  Column _buildH(BuildContext context, ThemeData theme) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // _buildHeader(context),
      SizedBox(
        height: Get.mediaQuery.padding.top + 56,
      ),
      SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            const SizedBox(width: 20),
            Padding(
              padding: EdgeInsets.only(
                top: 10,
                bottom: card.prInfo?.content?.isNotEmpty == true ? 0 : 10,
              ),
              child: _buildAvatar(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  ..._buildLeft(context, theme),
                  const SizedBox(height: 5),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: _buildRight(context, theme),
            ),
            const SizedBox(width: 20),
          ],
        ),
      ),
      if (card.prInfo?.content?.isNotEmpty == true) buildPrInfo(theme),
    ],
  );
}

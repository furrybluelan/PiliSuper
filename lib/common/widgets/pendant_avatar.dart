import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models/common/avatar_badge_type.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/image_util.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PendantAvatar extends StatelessWidget {
  final BadgeType _badgeType;
  final String? avatar;
  final double size;
  final double badgeSize;
  final String? garbPendantImage;
  final dynamic roomId;
  final VoidCallback? onTap;

  const PendantAvatar({
    super.key,
    required this.avatar,
    this.size = 80,
    double? badgeSize,
    bool? isVip,
    int? officialType,
    this.garbPendantImage,
    this.roomId,
    this.onTap,
  }) : _badgeType = officialType == null || officialType < 0
           ? isVip == true
                 ? BadgeType.vip
                 : BadgeType.none
           : officialType == 0
           ? BadgeType.person
           : officialType == 1
           ? BadgeType.institution
           : BadgeType.none,
       badgeSize = badgeSize ?? size / 3;

  static bool showDynDecorate = Pref.showDynDecorate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        onTap == null
            ? _buildAvatar(colorScheme)
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: _buildAvatar(colorScheme),
              ),
        if (showDynDecorate && !garbPendantImage.isNullOrEmpty)
          Positioned(
            top:
                -0.375 *
                (size == 80 ? size - 4 : size), // -(size * 1.75 - size) / 2
            child: IgnorePointer(
              child: CachedNetworkImage(
                width: size * 1.75,
                height: size * 1.75,
                imageUrl: ImageUtil.thumbnailUrl(garbPendantImage),
              ),
            ),
          ),
        if (roomId != null)
          Positioned(
            bottom: 0,
            child: InkWell(
              onTap: () => Get.toNamed('/liveRoom?roomid=$roomId'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(36)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.equalizer_rounded,
                      size: MediaQuery.textScalerOf(context).scale(16),
                      color: colorScheme.onSecondaryContainer,
                    ),
                    Text(
                      '直播中',
                      style: TextStyle(
                        height: 1,
                        fontSize: 13,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_badgeType != BadgeType.none)
          _buildBadge(colorScheme),
      ],
    );
  }

  Widget _buildAvatar(ColorScheme colorScheme) => size == 80
      ? DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              width: 2,
              color: colorScheme.surface,
            ),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: NetworkImgLayer(
              src: avatar,
              width: size,
              height: size,
              type: ImageType.avatar,
            ),
          ),
        )
      : NetworkImgLayer(
          src: avatar,
          width: size,
          height: size,
          type: ImageType.avatar,
        );

  Widget _buildBadge(ColorScheme colorScheme) {
    final child = switch (_badgeType) {
      BadgeType.vip => Image.asset(
        'assets/images/big-vip.png',
        height: badgeSize,
        semanticLabel: _badgeType.desc,
      ),
      _ => Icon(
        Icons.offline_bolt,
        color: _badgeType.color,
        size: badgeSize,
        semanticLabel: _badgeType.desc,
      ),
    };
    return Positioned(
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surface,
          ),
          child: child,
        ),
      ),
    );
  }
}

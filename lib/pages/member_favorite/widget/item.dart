import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models_new/space/space_fav/list.dart';
import 'package:PiliPlus/models_new/sub/sub/list.dart';
import 'package:PiliPlus/utils/fav_util.dart';
import 'package:PiliPlus/utils/num_util.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MemberFavItem extends StatelessWidget {
  const MemberFavItem({super.key, required this.item, this.callback});

  final SpaceFavItemModel item;
  final ValueChanged<bool?>? callback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () async {
          if (item.state == 1) {
            // invalid
            return;
          }

          if (item.type == 0 || item.type == 11) {
            var res = await Get.toNamed(
              '/favDetail',
              parameters: {
                'mediaId': item.id.toString(),
                'heroTag': Utils.makeHeroTag(item.id),
              },
            );
            callback?.call(res);
          } else {
            Get.toNamed(
              '/subDetail',
              arguments: SubItemModel(
                type: item.type,
                title: item.title,
                cover: item.cover,
                upper: item.upper,
                mediaCount: item.mediaCount,
                viewCount: item.viewCount,
              ),
              parameters: {
                'id': item.id.toString(),
                'heroTag': Utils.makeHeroTag(item.id),
              },
            );
          }
        },
        onLongPress: () => imageSaveDialog(
          title: item.title,
          cover: item.cover,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: StyleString.safeSpace,
            vertical: 5,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: StyleString.aspectRatio,
                child: LayoutBuilder(
                  builder: (context, boxConstraints) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        NetworkImgLayer(
                          src: item.cover,
                          width: boxConstraints.maxWidth,
                          height: boxConstraints.maxHeight,
                        ),
                        if (item.type == 21)
                          const PBadge(
                            right: 6,
                            top: 6,
                            text: '合集',
                          )
                        else if (item.type == 11)
                          const PBadge(
                            right: 6,
                            top: 6,
                            text: '收藏夹',
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      item.type == 0
                          ? '${item.mediaCount}个内容 · ${FavUtil.isPublicFavText(item.attr)}'
                          : item.type == 11
                          ? '${item.mediaCount}个内容 · ${item.upper?.name}'
                          : item.type == 21
                          ? '创建者: ${item.upper?.name}\n${item.mediaCount}个视频 · ${NumUtil.numFormat(item.viewCount)}播放'
                          : '${item.mediaCount}个内容',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

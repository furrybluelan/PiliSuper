import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/models_new/follow/list.dart';
import 'package:PiliPlus/pages/share/view.dart' show UserModel;
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/request_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FollowItem extends StatelessWidget {
  final FollowItemModel item;
  final bool? isOwner;
  final ValueChanged? callback;
  final ValueChanged<UserModel>? onSelect;

  const FollowItem({
    super.key,
    required this.item,
    this.callback,
    this.isOwner,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        onTap: () {
          if (onSelect != null) {
            onSelect!.call(
              UserModel(
                mid: item.mid!,
                name: item.uname!,
                avatar: item.face!,
              ),
            );
          } else {
            feedBack();
            Get.toNamed('/member?mid=${item.mid}');
          }
        },
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            NetworkImgLayer(
              width: 45,
              height: 45,
              type: ImageType.avatar,
              src: item.face,
            ),
            if (item.officialVerify?.type == 0 ||
                item.officialVerify?.type == 1)
              Positioned(
                bottom: 0,
                right: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surface,
                  ),
                  child: Icon(
                    Icons.offline_bolt,
                    color: item.officialVerify?.type == 0
                        ? const Color(0xFFFFCC00)
                        : Colors.lightBlueAccent,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          item.uname!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          item.sign!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        dense: true,
        trailing: isOwner == true
            ? SizedBox(
                height: 34,
                child: FilledButton.tonal(
                  onPressed: () => RequestUtils.actionRelationMod(
                    context: context,
                    mid: item.mid,
                    isFollow: item.attribute != -1,
                    callback: callback,
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                    foregroundColor: item.attribute == -1
                        ? null
                        : theme.colorScheme.outline,
                    backgroundColor: item.attribute == -1
                        ? null
                        : theme.colorScheme.onInverseSurface,
                  ),
                  child: Text(
                    '${item.attribute == -1 ? '' : '已'}关注',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

import 'dart:io';

import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:live_photo_maker/live_photo_maker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';

class ImageUtil {
  static String get time =>
      DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());

  // 图片分享
  static Future<void> onShareImg(String url) async {
    try {
      SmartDialog.showLoading();
      final temp = await getTemporaryDirectory();
      var path = '${temp.path}/${Utils.getFileName(url)}';
      var res = await Request().downloadFile(url.http2https, path);
      SmartDialog.dismiss();
      if (res.statusCode == 200) {
        SharePlus.instance.share(
          ShareParams(
            files: [XFile(path)],
            sharePositionOrigin: await Utils.isIpad()
                ? Rect.fromLTWH(0, 0, Get.width, Get.height / 2)
                : null,
          ),
        );
      }
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  // 获取存储权限
  static Future<bool> requestStoragePer(BuildContext context) async {
    await Permission.storage.request();
    PermissionStatus status = await Permission.storage.status;
    if (status == PermissionStatus.denied ||
        status == PermissionStatus.permanentlyDenied) {
      if (!context.mounted) return false;
      showDialog(
        context: context,
        builder: (context) {
          return const AlertDialog(
            title: Text('提示'),
            content: Text('存储权限未授权'),
            actions: [
              TextButton(
                onPressed: openAppSettings,
                child: Text('去授权'),
              ),
            ],
          );
        },
      );
      return false;
    } else {
      return true;
    }
  }

  // 获取相册权限
  static Future<bool> requestPhotoPer() async {
    await Permission.photos.request();
    PermissionStatus status = await Permission.photos.status;
    if (status == PermissionStatus.denied ||
        status == PermissionStatus.permanentlyDenied) {
      return false;
    } else {
      return true;
    }
  }

  static Future<bool> checkPermissionDependOnSdkInt(
    BuildContext context,
  ) async {
    if (Platform.isAndroid) {
      if (await Utils.sdkInt <= 32) {
        if (!context.mounted) return false;
        return requestStoragePer(context);
      } else {
        return requestPhotoPer();
      }
    }
    return requestStoragePer(context);
  }

  static Future<bool> downloadLivePhoto({
    required BuildContext context,
    required String url,
    required String liveUrl,
    required int width,
    required int height,
  }) async {
    try {
      if (!await checkPermissionDependOnSdkInt(context)) {
        return false;
      }
      SmartDialog.showLoading(msg: '正在下载');

      String tmpPath = (await getTemporaryDirectory()).path;
      late String imageName = "cover_${Utils.getFileName(url)}";
      late String imagePath = '$tmpPath/$imageName';
      String videoName = "video_${Utils.getFileName(liveUrl)}";
      String videoPath = '$tmpPath/$videoName';

      final res = await Request().downloadFile(liveUrl.http2https, videoPath);
      if (res.statusCode != 200) throw '${res.statusCode}';

      if (Platform.isIOS) {
        final res1 = await Request().downloadFile(url.http2https, imagePath);
        if (res1.statusCode != 200) throw '${res1.statusCode}';
        SmartDialog.showLoading(msg: '正在保存');
        bool success = await LivePhotoMaker.create(
          coverImage: imagePath,
          imagePath: null,
          voicePath: videoPath,
          width: width,
          height: height,
        );
        SmartDialog.dismiss();
        if (success) {
          SmartDialog.showToast(' Live Photo 已保存 ');
        } else {
          SmartDialog.showToast('保存失败');
        }
      } else {
        SmartDialog.showLoading(msg: '正在保存');
        final SaveResult result = await SaverGallery.saveFile(
          filePath: videoPath,
          fileName: videoName,
          androidRelativePath: "Pictures/PiliPlus",
          skipIfExists: false,
        );
        SmartDialog.dismiss();
        if (result.isSuccess) {
          SmartDialog.showToast(' 已保存 ');
        } else {
          SmartDialog.showToast('保存失败，${result.errorMessage}');
        }
      }

      return true;
    } catch (err) {
      SmartDialog.dismiss();
      SmartDialog.showToast(err.toString());
      return false;
    }
  }

  static Future<bool> downloadImg(
    BuildContext context,
    List<String> imgList,
  ) async {
    if (!await checkPermissionDependOnSdkInt(context)) return false;
    final cancelToken = CancelToken();
    SmartDialog.showLoading(
      msg: '正在下载原图',
      clickMaskDismiss: true,
      onDismiss: cancelToken.cancel,
    );
    try {
      final isAndroid = Platform.isAndroid;
      final tempPath = (await getTemporaryDirectory()).path;
      final futures = imgList.map((url) async {
        var name = Utils.getFileName(url);
        var filePath = '$tempPath/$name';

        var response = await Request().downloadFile(
          url.http2https,
          filePath,
          cancelToken: cancelToken,
        );

        if (isAndroid) {
          if (response.statusCode == 200) {
            await SaverGallery.saveFile(
              filePath: filePath,
              fileName: name,
              androidRelativePath: "Pictures/PiliPlus",
              skipIfExists: false,
            );
          }
        }
        return {
          'filePath': filePath,
          'name': name,
          'statusCode': response.statusCode,
        };
      });
      final result = await Future.wait(futures, eagerError: true);
      if (!isAndroid) {
        for (Map res in result) {
          if (res['statusCode'] == 200) {
            await SaverGallery.saveFile(
              filePath: res['filePath'],
              fileName: res['name'],
              androidRelativePath: "Pictures/PiliPlus",
              skipIfExists: false,
            );
          }
        }
      }
      if (cancelToken.isCancelled) {
        SmartDialog.showToast('已取消下载');
        return false;
      } else {
        SmartDialog.showToast('图片已保存');
      }
      return true;
    } catch (e) {
      if (cancelToken.isCancelled) {
        SmartDialog.showToast('已取消下载');
      } else {
        SmartDialog.showToast(e.toString());
      }
      return false;
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  static final _thumbRegex = RegExp(
    r'(@(\d+[a-z]_?)*)(\..*)?$',
    caseSensitive: false,
  );
  static String thumbnailUrl(String? src, [int? quality]) {
    if (src != null && quality != 100) {
      bool hasMatch = false;
      src = src.splitMapJoin(
        _thumbRegex,
        onMatch: (Match match) {
          hasMatch = true;
          String suffix = match.group(3) ?? '.webp';
          return '${match.group(1)}_${quality ?? GlobalData().imgQuality}q$suffix';
        },
        onNonMatch: (String str) {
          return str;
        },
      );
      if (!hasMatch) {
        src += '@${quality ?? GlobalData().imgQuality}q.webp';
      }
    }
    return src.http2https;
  }
}

import 'dart:convert';

import 'package:PiliPlus/common/widgets/pair.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

class WebDav {
  late String _webdavDirectory;
  String? _fileName;

  webdav.Client? _client;

  WebDav._internal();
  static final WebDav _instance = WebDav._internal();
  factory WebDav() => _instance;

  Future<Pair<bool, String?>> init() async {
    final webDavUri = Pref.webdavUri;
    final webDavUsername = Pref.webdavUsername;
    final webDavPassword = Pref.webdavPassword;
    _webdavDirectory = Pref.webdavDirectory;
    if (!_webdavDirectory.endsWith('/')) {
      _webdavDirectory += '/';
    }
    _webdavDirectory += 'PiliPlus';

    try {
      _client = null;
      final client =
          webdav.newClient(
              webDavUri,
              user: webDavUsername,
              password: webDavPassword,
            )
            ..setHeaders({'accept-charset': 'utf-8'})
            ..setConnectTimeout(4000)
            ..setReceiveTimeout(4000)
            ..setSendTimeout(4000);

      await client.mkdirAll(_webdavDirectory);

      _client = client;
      return Pair(first: true, second: null);
    } catch (e) {
      return Pair(first: false, second: e.toString());
    }
  }

  String _getFileName() {
    return Get.context!.isTablet
        ? 'piliplus_settings_pad.json'
        : 'piliplus_settings_phone.json';
  }

  Future<void> backup() async {
    if (_client == null) {
      final res = await init();
      if (res.first == false) {
        SmartDialog.showToast('备份失败，请检查配置: ${res.second}');
        return;
      }
    }
    try {
      String data = GStorage.exportAllSettings();
      _fileName ??= _getFileName();
      final path = '$_webdavDirectory/$_fileName';
      try {
        await _client!.remove(path);
      } catch (_) {}
      await _client!.write(path, utf8.encode(data));
      SmartDialog.showToast('备份成功');
    } catch (e) {
      SmartDialog.showToast('备份失败: $e');
    }
  }

  Future<void> restore() async {
    if (_client == null) {
      final res = await init();
      if (res.first == false) {
        SmartDialog.showToast('恢复失败，请检查配置: ${res.second}');
        return;
      }
    }
    try {
      _fileName ??= _getFileName();
      final path = '$_webdavDirectory/$_fileName';
      final data = await _client!.read(path);
      await GStorage.importAllSettings(utf8.decode(data));
      SmartDialog.showToast('恢复成功');
    } catch (e) {
      SmartDialog.showToast('恢复失败: $e');
    }
  }
}

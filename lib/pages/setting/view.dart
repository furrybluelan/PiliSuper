import 'package:PiliPlus/http/login.dart';
import 'package:PiliPlus/pages/about/view.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/pages/setting/extra_setting.dart';
import 'package:PiliPlus/pages/setting/play_setting.dart';
import 'package:PiliPlus/pages/setting/privacy_setting.dart';
import 'package:PiliPlus/pages/setting/recommend_setting.dart';
import 'package:PiliPlus/pages/setting/style_setting.dart';
import 'package:PiliPlus/pages/setting/video_setting.dart';
import 'package:PiliPlus/pages/setting/widgets/multi_select_dialog.dart';
import 'package:PiliPlus/pages/webdav/view.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class _SettingsModel {
  final String name;
  final String title;
  final String? subtitle;
  final IconData icon;

  const _SettingsModel({
    required this.name,
    required this.title,
    this.subtitle,
    required this.icon,
  });
}

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  late String _type = 'privacySetting';
  final RxBool _noAccount = Accounts.accountMode.isEmpty.obs;
  bool get _isPortrait => context.orientation == Orientation.portrait;

  final List<_SettingsModel> _items = [
    const _SettingsModel(
      name: 'privacySetting',
      title: '隐私设置',
      subtitle: '黑名单、无痕模式',
      icon: Icons.privacy_tip_outlined,
    ),
    const _SettingsModel(
      name: 'recommendSetting',
      title: '推荐流设置',
      subtitle: '推荐来源（web/app）、刷新保留内容、过滤器',
      icon: Icons.explore_outlined,
    ),
    const _SettingsModel(
      name: 'videoSetting',
      title: '音视频设置',
      subtitle: '画质、音质、解码、缓冲、音频输出等',
      icon: Icons.video_settings_outlined,
    ),
    const _SettingsModel(
      name: 'playSetting',
      title: '播放器设置',
      subtitle: '双击/长按、全屏、后台播放、弹幕、字幕、底部进度条等',
      icon: Icons.touch_app_outlined,
    ),
    const _SettingsModel(
      name: 'styleSetting',
      title: '外观设置',
      subtitle: '横屏适配（平板）、侧栏、列宽、首页、动态红点、主题、字号、图片、帧率等',
      icon: Icons.style_outlined,
    ),
    const _SettingsModel(
      name: 'extraSetting',
      title: '其它设置',
      subtitle: '震动、搜索、收藏、ai、评论、动态、代理、更新检查等',
      icon: Icons.extension_outlined,
    ),
    const _SettingsModel(
      name: 'webdavSetting',
      title: 'WebDAV 设置',
      icon: MdiIcons.databaseCogOutline,
    ),
    const _SettingsModel(
      name: 'about',
      title: '关于',
      icon: Icons.info_outline,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: _isPortrait
            ? const Text('设置')
            : Text(switch (_type) {
                'privacySetting' => '隐私设置',
                'recommendSetting' => '推荐流设置',
                'videoSetting' => '音视频设置',
                'playSetting' => '播放器设置',
                'styleSetting' => '外观设置',
                'extraSetting' => '其它设置',
                'webdavSetting' => 'WebDAV 设置',
                'about' => '关于',
                _ => '设置',
              }),
      ),
      body: _isPortrait
          ? _buildList(theme)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: MediaQuery.removePadding(
                    context: context,
                    removeRight: true,
                    removeTop: true,
                    child: _buildList(theme),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                ),
                Expanded(
                  flex: 6,
                  child: MediaQuery.removePadding(
                    context: context,
                    removeLeft: true,
                    removeTop: true,
                    child: switch (_type) {
                      'privacySetting' => const PrivacySetting(
                        showAppBar: false,
                      ),
                      'recommendSetting' => const RecommendSetting(
                        showAppBar: false,
                      ),
                      'videoSetting' => const VideoSetting(showAppBar: false),
                      'playSetting' => const PlaySetting(showAppBar: false),
                      'styleSetting' => const StyleSetting(showAppBar: false),
                      'extraSetting' => const ExtraSetting(showAppBar: false),
                      'webdavSetting' => const WebDavSettingPage(
                        showAppBar: false,
                      ),
                      'about' => const AboutPage(showAppBar: false),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _toPage(String name) {
    if (_isPortrait) {
      Get.toNamed('/$name');
    } else {
      _type = name;
      setState(() {});
    }
  }

  Color? _getTileColor(ThemeData theme, String name) {
    if (_isPortrait) {
      return null;
    } else {
      return name == _type ? theme.colorScheme.onInverseSurface : null;
    }
  }

  Widget _buildList(ThemeData theme) {
    TextStyle titleStyle = theme.textTheme.titleMedium!;
    TextStyle subTitleStyle = theme.textTheme.labelMedium!.copyWith(
      color: theme.colorScheme.outline,
    );
    return ListView(
      children: [
        _buildSearchItem(theme),
        ..._items
            .sublist(0, _items.length - 1)
            .map(
              (item) => ListTile(
                tileColor: _getTileColor(theme, item.name),
                onTap: () => _toPage(item.name),
                leading: Icon(item.icon),
                title: Text(item.title, style: titleStyle),
                subtitle: item.subtitle == null
                    ? null
                    : Text(item.subtitle!, style: subTitleStyle),
              ),
            ),
        ListTile(
          onTap: () => LoginPageController.switchAccountDialog(context),
          leading: const Icon(Icons.switch_account_outlined),
          title: const Text('设置账号模式'),
        ),
        Obx(
          () => _noAccount.value
              ? const SizedBox.shrink()
              : ListTile(
                  leading: const Icon(Icons.logout_outlined),
                  onTap: () => _logoutDialog(context),
                  title: Text('退出登录', style: titleStyle),
                ),
        ),
        ListTile(
          tileColor: _getTileColor(theme, _items.last.name),
          onTap: () => _toPage(_items.last.name),
          leading: Icon(_items.last.icon),
          title: Text(_items.last.title, style: titleStyle),
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 80),
      ],
    );
  }

  Future<void> _logoutDialog(BuildContext context) async {
    final result = await showDialog<Set<LoginAccount>>(
      context: context,
      builder: (context) {
        return MultiSelectDialog<LoginAccount>(
          title: '选择要登出的账号uid',
          initValues: const Iterable.empty(),
          values: {for (var i in Accounts.account.values) i: i.mid.toString()},
        );
      },
    );
    if (!context.mounted || result.isNullOrEmpty) return;
    Future<void> logout() {
      _noAccount.value = result!.length == Accounts.account.length;
      return Accounts.deleteAll(result);
    }

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('提示'),
          content: Text(
            "确认要退出以下账号登录吗\n\n${result!.map((i) => i.mid.toString()).join('\n')}",
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text(
                '点错了',
                style: TextStyle(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                logout();
              },
              child: Text(
                '仅登出',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: () async {
                SmartDialog.showLoading();
                final res = await LoginHttp.logout(Accounts.main);
                if (res['status']) {
                  SmartDialog.dismiss();
                  logout();
                  Get.back();
                } else {
                  SmartDialog.dismiss();
                  SmartDialog.showToast(res['msg'].toString());
                }
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchItem(ThemeData theme) => Padding(
    padding: EdgeInsets.only(
      left: 16 + MediaQuery.paddingOf(context).left,
      right: 16,
      bottom: 8,
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => Get.toNamed('/settingsSearch'),
        borderRadius: const BorderRadius.all(Radius.circular(50)),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(50)),
            color: theme.colorScheme.onInverseSurface,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  size: MediaQuery.textScalerOf(context).scale(18),
                  Icons.search,
                ),
                const Text(' 搜索'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

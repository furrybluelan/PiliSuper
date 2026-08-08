import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:hive_ce/hive.dart';

class SetDisplayMode extends StatefulWidget {
  const SetDisplayMode({super.key});

  @override
  State<SetDisplayMode> createState() => _SetDisplayModeState();
}

class _SetDisplayModeState extends State<SetDisplayMode> {
  List<DisplayMode> modes = <DisplayMode>[];
  DisplayMode? active;
  DisplayMode? preferred;

  Box setting = GStorage.setting;

  @override
  void initState() {
    super.initState();
    init();
  }

  // 获取所有的mode
  Future<void> fetchAll() async {
    preferred = await FlutterDisplayMode.preferred;
    active = await FlutterDisplayMode.active;
    setting.put(SettingBoxKey.displayMode, preferred.toString());
    if (mounted) {
      setState(() {});
    }
  }

  void _applyMode(DisplayMode mode) {
    FlutterDisplayMode.setPreferredMode(mode).whenComplete(
      () => Future.delayed(const Duration(milliseconds: 100), fetchAll),
    );
  }

  // 初始化mode/手动设置
  Future<void> init() async {
    try {
      modes = await FlutterDisplayMode.supported;
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint(e.toString());
    }

    final value = setting.get(SettingBoxKey.displayMode);
    if (value != null) {
      preferred = modes.firstWhereOrNull((e) => e.toString() == value);
    }

    preferred ??= DisplayMode.auto;

    FlutterDisplayMode.setPreferredMode(preferred!).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 100), fetchAll);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(title: const Text('屏幕帧率设置')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                MediaQuery.viewPaddingOf(context).copyWith(top: 0, bottom: 0) +
                const EdgeInsets.only(left: 25, top: 10, bottom: 5),
            child: Text(
              '没有生效？重启app试试',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(
            // TV 上不能用 RadioGroup：它的 W3C radio group 语义会在方向键移动
            // 焦点时就改变选中值，遥控器只有方向键，等于「路过即切换帧率」。
            // 改用 ListTile + 单选图标，仅确定键触发的 onTap 才真正应用。
            child: DeviceUtils.isTV
                ? ListView.builder(
                    itemCount: modes.length,
                    itemBuilder: (context, index) {
                      final DisplayMode mode = modes[index];
                      final selected = mode == preferred;
                      return ListTile(
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                        title: mode == DisplayMode.auto
                            ? const Text('自动')
                            : Text('$mode${mode == active ? '  [系统]' : ''}'),
                        onTap: () => _applyMode(mode),
                      );
                    },
                  )
                : RadioGroup(
                    onChanged: (DisplayMode? newMode) => _applyMode(newMode!),
                    groupValue: preferred,
                    child: ListView.builder(
                      itemCount: modes.length,
                      itemBuilder: (context, index) {
                        final DisplayMode mode = modes[index];
                        return RadioListTile<DisplayMode>(
                          value: mode,
                          title: mode == DisplayMode.auto
                              ? const Text('自动')
                              : Text('$mode${mode == active ? '  [系统]' : ''}'),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

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

  // 初始化mode/手动设置
  Future<void> init() async {
    try {
      modes = await FlutterDisplayMode.supported;
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint(e.toString());
    }

    var value = setting.get(SettingBoxKey.displayMode);
    if (value != null) {
      preferred = modes.firstWhereOrNull((e) => e.toString() == value);
    }

    preferred ??= DisplayMode.auto;

    FlutterDisplayMode.setPreferredMode(preferred!).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 100)).whenComplete(fetchAll);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('屏幕帧率设置')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 25, top: 10, bottom: 5),
              child: Text(
                '没有生效？重启app试试',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: modes.length,
                itemBuilder: (context, index) {
                  final DisplayMode mode = modes[index];
                  return RadioListTile<DisplayMode>(
                    value: mode,
                    title: mode == DisplayMode.auto
                        ? const Text('自动')
                        : Text('$mode${mode == active ? '  [系统]' : ''}'),
                    groupValue: preferred,
                    onChanged: (DisplayMode? newMode) {
                      FlutterDisplayMode.setPreferredMode(
                        newMode!,
                      ).whenComplete(
                        () => Future.delayed(
                          const Duration(milliseconds: 100),
                        ).whenComplete(fetchAll),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:PiliPlus/models/common/video/cdn_type.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/utils/cdn_speed_service.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

class SelectDialog<T> extends StatefulWidget {
  final T? value;
  final String title;
  final List<(T, String)> values;
  final Widget Function(BuildContext, int)? subtitleBuilder;
  final bool toggleable;

  const SelectDialog({
    super.key,
    this.value,
    required this.values,
    required this.title,
    this.subtitleBuilder,
    this.toggleable = false,
  });

  @override
  State<SelectDialog<T>> createState() => _SelectDialogState<T>();
}

class _SelectDialogState<T> extends State<SelectDialog<T>> {
  // TV 上用两步流程：方向键只移动焦点（更新 _pendingValue），确定键才提交。
  // 非 TV 保持原来的「焦点即选中立刻 pop」行为。
  late T? _pendingValue;

  @override
  void initState() {
    super.initState();
    _pendingValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final titleMedium = TextTheme.of(context).titleMedium!;
    final isTV = DeviceUtils.isTV;
    return AlertDialog(
      clipBehavior: Clip.hardEdge,
      title: Text(widget.title),
      constraints: widget.subtitleBuilder != null
          ? const BoxConstraints.tightFor(width: 320)
          : null,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: Material(
        type: .transparency,
        child: SingleChildScrollView(
          // TV 上不能用 RadioGroup：它实现 W3C radio group 语义，方向键移动焦点
          // 的同时就会改变选中值，而遥控器只有方向键，导致「焦点到哪就选到哪」。
          // 改用 ListTile + 单选图标，仅 onTap（确定键的 ActivateAction）才预选。
          child: isTV
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    widget.values.length,
                    (index) {
                      final item = widget.values[index];
                      final selected = _pendingValue == item.$1;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                        ),
                        title: Text(item.$2, style: titleMedium),
                        subtitle: widget.subtitleBuilder?.call(context, index),
                        onTap: () => setState(() {
                          _pendingValue = widget.toggleable && selected
                              ? null
                              : item.$1;
                        }),
                      );
                    },
                  ),
                )
              : RadioGroup<T>(
                  onChanged: (v) =>
                      Navigator.of(context).pop(v ?? widget.value),
                  groupValue: _pendingValue,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      widget.values.length,
                      (index) {
                        final item = widget.values[index];
                        return RadioListTile<T>(
                          toggleable: widget.toggleable,
                          dense: true,
                          value: item.$1,
                          title: Text(
                            item.$2,
                            style: titleMedium,
                          ),
                          subtitle: widget.subtitleBuilder?.call(context, index),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ),
      // TV 模式下显示「取消/确定」按钮，非 TV 无按钮（点击即关闭）。
      actions: isTV
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  '取消',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              TextButton(
                // toggleable 取消选择时 _pendingValue 为 null，调用方将其视为
                // 「不做改动」，与取消一致，故直接提交而不回退为原值。
                onPressed: () => Navigator.of(context).pop(_pendingValue),
                child: const Text('确定'),
              ),
            ]
          : null,
    );
  }
}

class CdnSelectDialog extends StatefulWidget {
  final BaseItem? sample;

  const CdnSelectDialog({
    super.key,
    this.sample,
  });

  @override
  State<CdnSelectDialog> createState() => _CdnSelectDialogState();
}

class _CdnSelectDialogState extends State<CdnSelectDialog> {
  late final List<ValueNotifier<String?>> _cdnResList;
  late final bool _cdnSpeedTest;
  CancelToken? _cancelToken;

  @override
  void initState() {
    _cdnSpeedTest = Pref.cdnSpeedTest;
    if (_cdnSpeedTest) {
      final length = CDNService.values.length;
      _cdnResList = List.generate(
        length,
        (_) => ValueNotifier<String?>(null),
      );
      _cancelToken = CancelToken();
      _startSpeedTest();
    }
    super.initState();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    if (_cdnSpeedTest) {
      for (final notifier in _cdnResList) {
        notifier.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _startSpeedTest() async {
    final token = _cancelToken;
    if (token == null) return;
    try {
      final videoItem = widget.sample ?? await CdnSpeedService.getSampleUrl();
      if (token.isCancelled || !mounted) return;
      await CdnSpeedService.testAll(
        videoItem,
        cancelToken: token,
        onProgress: (service, result) {
          if (token.isCancelled || !mounted) return;
          _cdnResList[service.index].value = result;
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('CDN speed test failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SelectDialog<CDNService>(
      title: 'CDN 设置',
      values: CDNService.values.map((i) => (i, i.desc)).toList(),
      value: VideoUtils.cdnService,
      subtitleBuilder: _cdnSpeedTest
          ? (context, index) {
              final item = _cdnResList[index];
              return ValueListenableBuilder(
                valueListenable: item,
                builder: (context, value, _) {
                  return Text(
                    value ?? '---',
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              );
            }
          : null,
    );
  }
}

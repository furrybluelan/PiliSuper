import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, KeyDownEvent;

class DualSliderDialog extends StatefulWidget {
  final double value1;
  final double value2;
  final Widget title;
  final Widget description1;
  final Widget description2;
  final double min;
  final double max;
  final int? divisions;
  final String suffix;
  final int precise;

  const DualSliderDialog({
    super.key,
    required this.value1,
    required this.value2,
    required this.description1,
    required this.description2,
    required this.title,
    required this.min,
    required this.max,
    this.divisions,
    this.suffix = '',
    this.precise = 1,
  });

  @override
  State<DualSliderDialog> createState() => _DualSliderDialogState();
}

class _DualSliderDialogState extends State<DualSliderDialog> {
  late double _tempValue1;
  late double _tempValue2;
  final _slider2Focus = FocusNode();
  final _cancelFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tempValue1 = widget.value1;
    _tempValue2 = widget.value2;
  }

  @override
  void dispose() {
    _slider2Focus.dispose();
    _cancelFocus.dispose();
    super.dispose();
  }

  Widget _wrapSlider(Widget slider, {FocusNode? nextFocus}) {
    if (!DeviceUtils.isTV || nextFocus == null) return slider;
    // TV 上 Slider 左右调值，上下键不能移出焦点。捕获上下键跳到下一个节点。
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowDown ||
              key == LogicalKeyboardKey.arrowUp) {
            nextFocus.requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: slider,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.title,
      contentPadding: const EdgeInsets.only(
        top: 20,
        left: 8,
        right: 8,
        bottom: 8,
      ),
      content: Column(
        mainAxisSize: .min,
        children: [
          widget.description1,
          _wrapSlider(
            Builder(
              builder: (context) {
                return Slider(
                  value: _tempValue1,
                  min: widget.min,
                  max: widget.max,
                  divisions: widget.divisions,
                  label:
                      '${_tempValue1.toStringAsFixed(widget.precise)}${widget.suffix}',
                  onChanged: (double value) {
                    _tempValue1 = value.toPrecision(widget.precise);
                    (context as Element).markNeedsBuild();
                  },
                );
              },
            ),
            nextFocus: _slider2Focus,
          ),
          widget.description2,
          _wrapSlider(
            Builder(
              builder: (context) {
                return Slider(
                  focusNode: _slider2Focus,
                  value: _tempValue2,
                  min: widget.min,
                  max: widget.max,
                  divisions: widget.divisions,
                  label:
                      '${_tempValue2.toStringAsFixed(widget.precise)}${widget.suffix}',
                  onChanged: (double value) {
                    _tempValue2 = value.toPrecision(widget.precise);
                    (context as Element).markNeedsBuild();
                  },
                );
              },
            ),
            nextFocus: _cancelFocus,
          ),
        ],
      ),
      actions: [
        TextButton(
          focusNode: _cancelFocus,
          onPressed: Navigator.of(context).pop,
          child: Text(
            '取消',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, (_tempValue1, _tempValue2)),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

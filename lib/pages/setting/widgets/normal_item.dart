import 'package:flutter/material.dart';

class NormalItem extends StatefulWidget {
  final String? title;
  final Function? getTitle;
  final String? subtitle;
  final Function? getSubtitle;
  final String? setKey;
  final bool? defaultVal;
  final ValueChanged<bool>? onChanged;
  final bool? needReboot;
  final Widget? leading;
  final Function? getTrailing;
  final Function? onTap;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? titleStyle;

  const NormalItem({
    this.title,
    this.getTitle,
    this.subtitle,
    this.getSubtitle,
    this.setKey,
    this.defaultVal,
    this.onChanged,
    this.needReboot,
    this.leading,
    this.getTrailing,
    this.onTap,
    this.contentPadding,
    this.titleStyle,
    super.key,
  });

  @override
  State<NormalItem> createState() => _NormalItemState();
}

class _NormalItemState extends State<NormalItem> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: widget.contentPadding,
      onTap: () => widget.onTap?.call(() {
        setState(() {});
      }),
      title: Text(
        widget.title ?? widget.getTitle?.call(),
        style: widget.titleStyle ?? Theme.of(context).textTheme.titleMedium!,
      ),
      subtitle: widget.subtitle != null || widget.getSubtitle != null
          ? Text(
              widget.subtitle ?? widget.getSubtitle?.call(),
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            )
          : null,
      leading: widget.leading,
      trailing: widget.getTrailing?.call(),
    );
  }
}

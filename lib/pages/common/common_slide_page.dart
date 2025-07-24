import 'dart:math';

import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

abstract class CommonSlidePage extends StatefulWidget {
  const CommonSlidePage({super.key, this.enableSlide});

  final bool? enableSlide;
}

abstract class CommonSlidePageState<T extends CommonSlidePage> extends State<T>
    with TickerProviderStateMixin {
  Offset? downPos;
  bool? isSliding;

  late final bool enableSlide;
  AnimationController? _animController;
  Animation<Offset>? _anim;

  static bool slideDismissReplyPage = Pref.slideDismissReplyPage;

  @override
  void initState() {
    super.initState();
    enableSlide = widget.enableSlide != false && slideDismissReplyPage;
    if (enableSlide) {
      _animController = AnimationController(
        vsync: this,
        reverseDuration: const Duration(milliseconds: 500),
      );
      _anim = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(0, 1),
      ).animate(_animController!);
    }
  }

  @override
  void dispose() {
    _animController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return enableSlide
        ? SlideTransition(
            position: _anim!,
            child: buildPage(theme),
          )
        : buildPage(theme);
  }

  Widget buildPage(ThemeData theme);

  Widget buildList(ThemeData theme) => throw UnimplementedError();

  Widget slideList(ThemeData theme) => LayoutBuilder(
    builder: (_, constrains) {
      final maxWidth = constrains.maxWidth;

      void onDismiss() {
        if (isSliding == true) {
          if (_animController!.value * maxWidth + downPos!.dx >= 100) {
            Get.back();
          } else {
            _animController!.reverse();
          }
        }
        downPos = null;
        isSliding = null;
      }

      void onPan(Offset localPosition) {
        if (isSliding == false) {
          return;
        } else if (isSliding == null) {
          if (downPos != null) {
            Offset cumulativeDelta = localPosition - downPos!;
            if (cumulativeDelta.dx.abs() >= cumulativeDelta.dy.abs()) {
              downPos = localPosition;
              isSliding = true;
            } else {
              isSliding = false;
            }
          }
        } else if (isSliding == true) {
          if (localPosition.dx < 0) {
            return;
          }
          _animController!.value =
              max(0, (localPosition.dx - downPos!.dx)) / maxWidth;
        }
      }

      return GestureDetector(
        onPanDown: (details) {
          if (details.localPosition.dx > 30) {
            isSliding = false;
          } else {
            downPos = details.localPosition;
          }
        },
        onPanStart: (details) {
          onPan(details.localPosition);
        },
        onPanUpdate: (details) {
          onPan(details.localPosition);
        },
        onPanCancel: onDismiss,
        onPanEnd: (_) {
          onDismiss();
        },
        child: buildList(theme),
      );
    },
  );
}

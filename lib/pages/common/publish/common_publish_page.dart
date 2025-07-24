import 'dart:async';
import 'dart:io';
import 'dart:math' show max;

import 'package:PiliPlus/http/msg.dart';
import 'package:PiliPlus/models/common/publish_panel_type.dart';
import 'package:PiliPlus/models_new/upload_bfs/data.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:chat_bottom_container/chat_bottom_container.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

abstract class CommonPublishPage<T> extends StatefulWidget {
  const CommonPublishPage({
    super.key,
    this.initialValue,
    this.imageLengthLimit,
    this.onSave,
    this.autofocus = true,
  });

  final String? initialValue;
  final int? imageLengthLimit;
  final ValueChanged<T>? onSave;
  final bool autofocus;
}

abstract class CommonPublishPageState<T extends CommonPublishPage>
    extends State<T>
    with WidgetsBindingObserver {
  late final focusNode = FocusNode();
  late final controller = ChatBottomPanelContainerController<PanelType>();
  TextEditingController get editController;

  Rx<PanelType> panelType = PanelType.none.obs;
  late final RxBool readOnly = false.obs;
  late final RxBool enablePublish = false.obs;

  late final imagePicker = ImagePicker();
  late final RxList<String> pathList = <String>[].obs;
  int get limit => widget.imageLengthLimit ?? 9;

  bool? hasPub;
  void initPubState();

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
    }

    initPubState();

    if (widget.autofocus) {
      Future.delayed(const Duration(milliseconds: 300)).whenComplete(() {
        if (mounted) {
          focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    if (hasPub != true) {
      onSave();
    }
    focusNode.dispose();
    editController.dispose();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  Future<void> _requestFocus() async {
    await Future.delayed(const Duration(microseconds: 200));
    focusNode.requestFocus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted &&
          widget.autofocus &&
          panelType.value == PanelType.keyboard) {
        controller.restoreChatPanel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (focusNode.hasFocus) {
            focusNode.unfocus();
            _requestFocus();
          } else {
            _requestFocus();
          }
        });
      }
    } else if (state == AppLifecycleState.paused) {
      controller.keepChatPanel();
      if (focusNode.hasFocus) {
        focusNode.unfocus();
      }
    }
  }

  void updatePanelType(PanelType type) {
    final isSwitchToKeyboard = PanelType.keyboard == type;
    final isSwitchToEmojiPanel =
        PanelType.emoji == type || PanelType.more == type;
    bool isUpdated = false;
    switch (type) {
      case PanelType.keyboard:
        updateInputView(isReadOnly: false);
        break;
      case PanelType.emoji || PanelType.more:
        isUpdated = updateInputView(isReadOnly: true);
        break;
      default:
        break;
    }

    void updatePanelTypeFunc() {
      controller.updatePanelType(
        isSwitchToKeyboard
            ? ChatBottomPanelType.keyboard
            : ChatBottomPanelType.other,
        data: type,
        forceHandleFocus: isSwitchToEmojiPanel
            ? ChatBottomHandleFocus.requestFocus
            : ChatBottomHandleFocus.none,
      );
    }

    if (isUpdated) {
      // Waiting for the input view to update.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        updatePanelTypeFunc();
      });
    } else {
      updatePanelTypeFunc();
    }
  }

  Future<void> hidePanel() async {
    if (focusNode.hasFocus) {
      await Future.delayed(const Duration(milliseconds: 100));
      focusNode.unfocus();
    }
    updateInputView(isReadOnly: false);
    if (ChatBottomPanelType.none == controller.currentPanelType) return;
    controller.updatePanelType(ChatBottomPanelType.none);
  }

  bool updateInputView({
    required bool isReadOnly,
  }) {
    if (readOnly.value != isReadOnly) {
      readOnly.value = isReadOnly;
      return true;
    }
    return false;
  }

  Widget buildEmojiPickerPanel() {
    double height = context.isTablet ? 300 : 170;
    final keyboardHeight = controller.keyboardHeight;
    if (keyboardHeight != 0) {
      height = max(height, keyboardHeight);
    }
    return SizedBox(
      height: height,
      child: customPanel,
    );
  }

  Widget buildMorePanel(ThemeData theme) => throw UnimplementedError();

  Widget buildPanelContainer(ThemeData theme, [Color? panelBgColor]) {
    return ChatBottomPanelContainer<PanelType>(
      controller: controller,
      inputFocusNode: focusNode,
      otherPanelWidget: (type) {
        if (type == null) return const SizedBox.shrink();
        switch (type) {
          case PanelType.emoji:
            return buildEmojiPickerPanel();
          case PanelType.more:
            return buildMorePanel(theme);
          default:
            return const SizedBox.shrink();
        }
      },
      onPanelTypeChange: (panelType, data) {
        switch (panelType) {
          case ChatBottomPanelType.none:
            this.panelType.value = PanelType.none;
            break;
          case ChatBottomPanelType.keyboard:
            this.panelType.value = PanelType.keyboard;
            break;
          case ChatBottomPanelType.other:
            if (data == null) return;
            this.panelType.value = data;
            break;
        }
      },
      panelBgColor: panelBgColor ?? Theme.of(context).colorScheme.surface,
    );
  }

  Future<void> onPublish() async {
    feedBack();
    List<Map<String, dynamic>>? pictures;
    if (pathList.isNotEmpty) {
      SmartDialog.showLoading(msg: '正在上传图片...');
      final cancelToken = CancelToken();
      try {
        pictures = await Future.wait<Map<String, dynamic>>(
          pathList.map((path) async {
            Map result = await MsgHttp.uploadBfs(
              path: path,
              category: 'daily',
              biz: 'new_dyn',
              cancelToken: cancelToken,
            );
            if (!result['status']) throw HttpException(result['msg']);
            UploadBfsResData data = result['data'];
            return {
              'img_width': data.imageWidth,
              'img_height': data.imageHeight,
              'img_size': data.imgSize,
              'img_src': data.imageUrl,
            };
          }).toList(),
          eagerError: true,
        );
        SmartDialog.dismiss();
      } on HttpException catch (e) {
        cancelToken.cancel();
        SmartDialog.dismiss();
        SmartDialog.showToast(e.message);
        return;
      }
    }
    onCustomPublish(pictures: pictures);
  }

  Future<void> onCustomPublish({List? pictures});

  Widget? get customPanel => null;

  void onChanged(String value) {
    enablePublish.value = value.trim().isNotEmpty;
  }

  void onSave() {}
}

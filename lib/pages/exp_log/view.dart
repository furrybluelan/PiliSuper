import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/loading_widget/loading_widget.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/coin_log/list.dart';
import 'package:PiliPlus/pages/exp_log/controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ExpLogPage extends StatefulWidget {
  const ExpLogPage({super.key});

  @override
  State<ExpLogPage> createState() => _ExpLogPageState();
}

class _ExpLogPageState extends State<ExpLogPage> {
  late final _controller = Get.put(ExpLogController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('经验记录')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: 10,
                    right: 10,
                    bottom: MediaQuery.paddingOf(context).bottom + 80,
                  ),
                  sliver: Obx(() => _buildBody(_controller.loadingState.value)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(LoadingState<List<CoinLogItem>?> loadingState) {
    return switch (loadingState) {
      Loading() => linearLoading,
      Success(:var response) =>
        response?.isNotEmpty == true
            ? Builder(
                builder: (context) {
                  final them = Theme.of(context);
                  final outline = them.colorScheme.outline.withValues(
                    alpha: 0.1,
                  );
                  final divider = Divider(
                    height: 1,
                    color: outline,
                  );
                  final sliverDivider = SliverToBoxAdapter(
                    child: divider,
                  );
                  final dividerV = VerticalDivider(
                    width: 1,
                    color: outline,
                  );
                  return SliverMainAxisGroup(
                    slivers: [
                      sliverDivider,
                      SliverToBoxAdapter(
                        child: ColoredBox(
                          color: them.colorScheme.onInverseSurface,
                          child: _item(
                            const CoinLogItem(
                              time: '时间',
                              delta: '变化',
                              reason: '原因',
                            ),
                            dividerV,
                            isHeader: true,
                          ),
                        ),
                      ),
                      sliverDivider,
                      SliverList.separated(
                        itemCount: response!.length,
                        itemBuilder: (context, index) {
                          return _item(response[index], dividerV);
                        },
                        separatorBuilder: (context, index) => divider,
                      ),
                      sliverDivider,
                    ],
                  );
                },
              )
            : HttpError(onReload: _controller.onReload),
      Error(:var errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _controller.onReload,
      ),
    };
  }

  Widget _item(CoinLogItem item, Widget divider, {bool isHeader = false}) {
    Widget text(int flex, String text) => Expanded(
      flex: flex,
      child: Padding(
        padding: isHeader
            ? const EdgeInsets.symmetric(vertical: 6)
            : const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: isHeader
                ? const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)
                : const TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
    Widget content = Row(
      children: [
        divider,
        text(2, item.time),
        divider,
        text(1, item.delta),
        divider,
        text(2, item.reason),
        divider,
      ],
    );
    return IntrinsicHeight(
      child: isHeader ? content : SelectionArea(child: content),
    );
  }
}

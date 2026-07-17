import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/pages/local_block/local_block_type.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

/// 融合本地屏蔽管理：UP / 标题 / 分区 / TAG / 话题 / 简介
class LocalBlockPage extends StatefulWidget {
  const LocalBlockPage({super.key});

  @override
  State<LocalBlockPage> createState() => _LocalBlockPageState();
}

class _LocalBlockPageState extends State<LocalBlockPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtr;
  final _searchCtr = TextEditingController();
  final _addCtr = TextEditingController();
  final _addFocus = FocusNode();

  LocalBlockType get _type => LocalBlockType.values[_tabCtr.index];

  List<String> _items = [];
  String _query = '';
  bool _batchMode = false;
  final Set<int> _selected = {};

  /// (rawIndex, display) — 搜索时仍保留在完整列表中的下标，避免 indexOf 撞重
  List<(int, String)> get _filteredEntries {
    if (_query.isEmpty) {
      return [
        for (var i = 0; i < _items.length; i++) (i, _items[i]),
      ];
    }
    final q = _query.toLowerCase();
    return [
      for (var i = 0; i < _items.length; i++)
        if (_items[i].toLowerCase().contains(q)) (i, _items[i]),
    ];
  }

  @override
  void initState() {
    super.initState();
    _tabCtr = TabController(length: LocalBlockType.values.length, vsync: this)
      ..addListener(_onTabChanged);
    _reload();
  }

  void _onTabChanged() {
    if (_tabCtr.indexIsChanging) return;
    setState(() {
      _batchMode = false;
      _selected.clear();
      _searchCtr.clear();
      _query = '';
      _addCtr.clear();
      _reload();
    });
  }

  void _reload() {
    _items = _type.loadRules();
  }

  @override
  void dispose() {
    _tabCtr
      ..removeListener(_onTabChanged)
      ..dispose();
    _searchCtr.dispose();
    _addCtr.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _persist(List<String> next) async {
    _type.saveRules(next);
    setState(() {
      _items = next;
      _batchMode = false;
      _selected.clear();
    });
  }

  Future<void> _confirmAdd() async {
    final text = _addCtr.text.trim();
    if (text.isEmpty) {
      SmartDialog.showToast('请输入内容');
      return;
    }
    if (_type.isUp) {
      final uid = int.tryParse(text);
      if (uid == null || uid <= 0) {
        SmartDialog.showToast('UID 无效');
        return;
      }
      // 与 loadRules 展示格式一致：「名称 (mid)」
      final display = 'UID:$uid ($uid)';
      final exists = Pref.recommendBlockedMids.containsKey(uid) ||
          _items.any((e) => RegExp(r'\(' + '$uid' + r'\)$').hasMatch(e));
      if (exists) {
        SmartDialog.showToast('该 UP 已在列表中');
        return;
      }
      final ok = await showConfirmDialog(
        context: context,
        title: const Text('确认添加'),
        content: Text('将本地屏蔽 UP：$uid'),
      );
      if (!ok || !mounted) return;
      await _persist([..._items, display]);
      _addCtr.clear();
      SmartDialog.showToast('已添加');
      return;
    }
    if (_items.contains(text)) {
      SmartDialog.showToast('该规则已存在');
      return;
    }
    final ok = await showConfirmDialog(
      context: context,
      title: const Text('确认添加'),
      content: Text(text),
    );
    if (!ok || !mounted) return;
    await _persist([..._items, text]);
    _addCtr.clear();
    SmartDialog.showToast('已添加');
  }

  Future<void> _confirmEdit(int rawIndex, String oldValue) async {
    final ctr = TextEditingController(text: oldValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改规则'),
        content: TextField(
          controller: ctr,
          autofocus: true,
          decoration: InputDecoration(hintText: _type.addHint),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('取消')),
          TextButton(
            onPressed: () => Get.back(result: ctr.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    ctr.dispose();
    if (result == null || !mounted) return;
    if (result.isEmpty) {
      SmartDialog.showToast('内容不能为空');
      return;
    }
    if (result == oldValue) return;
    if (_items.contains(result) && result != oldValue) {
      SmartDialog.showToast('该规则已存在');
      return;
    }
    final ok = await showConfirmDialog(
      context: context,
      title: const Text('确认修改'),
      content: Text('$oldValue\n→\n$result'),
    );
    if (!ok || !mounted) return;
    final next = List<String>.from(_items)..[rawIndex] = result;
    await _persist(next);
    SmartDialog.showToast('已修改');
  }

  Future<void> _confirmDeleteOne(int rawIndex, String value) async {
    final ok = await showConfirmDialog(
      context: context,
      title: const Text('确认删除'),
      content: Text(value),
    );
    if (!ok || !mounted) return;
    final next = List<String>.from(_items)..removeAt(rawIndex);
    await _persist(next);
    SmartDialog.showToast('已删除');
  }

  Future<void> _confirmBatchDelete() async {
    if (_selected.isEmpty) {
      SmartDialog.showToast('请先选择要删除的项');
      return;
    }
    // 只保留仍有效的下标，从大到小删，避免错位
    final toDelete = _selected.where((i) => i >= 0 && i < _items.length).toList()
      ..sort((a, b) => b.compareTo(a));
    if (toDelete.isEmpty) {
      SmartDialog.showToast('所选项目已失效，请重试');
      setState(_selected.clear);
      return;
    }
    final preview = toDelete.map((i) => _items[i]).take(5).join('\n');
    final ok = await showConfirmDialog(
      context: context,
      title: Text('确认删除 ${toDelete.length} 项'),
      content: Text(
        preview + (toDelete.length > 5 ? '\n…' : ''),
      ),
    );
    if (!ok || !mounted) return;
    final next = List<String>.from(_items);
    for (final i in toDelete) {
      next.removeAt(i);
    }
    await _persist(next);
    SmartDialog.showToast('已删除');
  }

  void _toggleBatchMode() {
    setState(() {
      _batchMode = !_batchMode;
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredEntries;
    final isBatch = _batchMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('本地屏蔽'),
        bottom: TabBar(
          controller: _tabCtr,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final t in LocalBlockType.values) Tab(text: t.label),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtr,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '搜索屏蔽词',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: isBatch ? '取消批量' : '批量删除',
                  onPressed: _toggleBatchMode,
                  style: IconButton.styleFrom(
                    backgroundColor: isBatch
                        ? theme.colorScheme.errorContainer
                        : null,
                    foregroundColor: isBatch
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  // 垃圾桶中带 X：批量删除
                  icon: Icon(
                    isBatch ? Icons.close : Icons.auto_delete_outlined,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _items.isEmpty ? '暂无规则' : '无匹配结果',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final (rawIndex, value) = filtered[index];
                      final selected = _selected.contains(rawIndex);
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: ListTile(
                          dense: true,
                          leading: isBatch
                              ? Checkbox(
                                  value: selected,
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selected.add(rawIndex);
                                      } else {
                                        _selected.remove(rawIndex);
                                      }
                                    });
                                  },
                                )
                              : null,
                          title: Text(value, maxLines: 3),
                          onTap: () {
                            if (isBatch) {
                              setState(() {
                                if (selected) {
                                  _selected.remove(rawIndex);
                                } else {
                                  _selected.add(rawIndex);
                                }
                              });
                              return;
                            }
                            if (_type.isUp) {
                              SmartDialog.showToast('UP 项不支持直接改名，可删除后重新添加');
                              return;
                            }
                            _confirmEdit(rawIndex, value);
                          },
                          onLongPress: () {
                            Utils.copyText(value);
                          },
                          trailing: isBatch
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: '复制',
                                      icon: const Icon(Icons.copy, size: 20),
                                      onPressed: () => Utils.copyText(value),
                                    ),
                                    IconButton(
                                      tooltip: '删除',
                                      icon: const Icon(
                                        Icons.close,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _confirmDeleteOne(rawIndex, value),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: isBatch
                  ? SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                        onPressed: _confirmBatchDelete,
                        child: Text('删除所选 (${_selected.length})'),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _addCtr,
                            focusNode: _addFocus,
                            keyboardType: _type.isUp
                                ? TextInputType.number
                                : TextInputType.text,
                            inputFormatters: _type.isUp
                                ? [FilteringTextInputFormatter.digitsOnly]
                                : null,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: _type.addHint,
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _confirmAdd(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _confirmAdd,
                          child: const Text('添加'),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

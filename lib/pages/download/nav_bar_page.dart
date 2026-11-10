import 'package:PiliPlus/pages/download/download/view.dart';
import 'package:material_ui/material_ui.dart';

/// Reuse the seasonal download page, including its multiselect and update actions.
class DownloadNavBarPage extends StatelessWidget {
  const DownloadNavBarPage({super.key});

  @override
  Widget build(BuildContext context) => MediaQuery.removePadding(
    context: context,
    removeTop: true,
    child: const DownloadPage(embedded: true),
  );
}

import 'package:flutter/material.dart';

import '../services/module_service.dart';
import 'module_read_only_state_screen.dart';

class QuranModuleScreen extends StatelessWidget {
  const QuranModuleScreen({
    super.key,
    required this.moduleService,
    required this.title,
  });

  final ModuleService moduleService;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ModuleReadOnlyStateScreen<QuranOverviewDto>(
      title: title,
      load: moduleService.quran,
    );
  }
}

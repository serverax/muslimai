import 'package:flutter/material.dart';

import '../services/module_service.dart';
import 'module_read_only_state_screen.dart';

class KnowledgeModuleScreen extends StatelessWidget {
  const KnowledgeModuleScreen({
    super.key,
    required this.moduleService,
    required this.title,
  });

  final ModuleService moduleService;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ModuleReadOnlyStateScreen<KnowledgeOverviewDto>(
      title: title,
      load: moduleService.knowledge,
    );
  }
}

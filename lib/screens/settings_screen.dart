// settings_screen.dart — app preferences (gear icon target)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<AppSettings>(
        builder: (context, settings, _) => ListView(
          children: [
            SwitchListTile(
              title: const Text('Manual game generation'),
              subtitle: const Text(
                  'Show the type/difficulty dialog instead of dequeuing from pre-generated games'),
              value: settings.manualGeneration,
              onChanged: settings.setManualGeneration,
            ),
          ],
        ),
      ),
    );
  }
}

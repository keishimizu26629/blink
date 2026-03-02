import 'package:flutter/material.dart';

import '../../view_models/project_view_model.dart';

class AppearanceSettings extends StatelessWidget {
  final double windowOpacity;
  final bool isBringToFrontHotkeyEnabled;
  final BringToFrontShortcut bringToFrontShortcut;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<bool> onHotkeyEnabledChanged;
  final ValueChanged<BringToFrontShortcut> onShortcutChanged;

  const AppearanceSettings({
    super.key,
    required this.windowOpacity,
    required this.isBringToFrontHotkeyEnabled,
    required this.bringToFrontShortcut,
    required this.onOpacityChanged,
    required this.onHotkeyEnabledChanged,
    required this.onShortcutChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('表示設定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('最前面ショートカット有効', style: TextStyle(fontSize: 14)),
            value: isBringToFrontHotkeyEnabled,
            onChanged: onHotkeyEnabledChanged,
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'ショートカット',
                style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<BringToFrontShortcut>(
                  value: bringToFrontShortcut,
                  isExpanded: true,
                  underline: const SizedBox(),
                  onChanged: isBringToFrontHotkeyEnabled
                      ? (value) { if (value != null) onShortcutChanged(value); }
                      : null,
                  items: BringToFrontShortcut.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName, style: const TextStyle(fontSize: 12))))
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Opacity', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: windowOpacity,
                  min: 0.6,
                  max: 1.0,
                  onChanged: onOpacityChanged,
                ),
              ),
              SizedBox(
                width: 46,
                child: Text(
                  '${(windowOpacity * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

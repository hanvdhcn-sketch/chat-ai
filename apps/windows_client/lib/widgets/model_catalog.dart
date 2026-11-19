import 'package:flutter/material.dart';

/// UI-facing model labels. Runtime still routes to Grok/Gemini via API.
class UiModel {
  const UiModel({
    required this.id,
    required this.label,
    required this.runtimeHint,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  /// Hint only — never call Anthropic; API picks Grok/Gemini.
  final String runtimeHint;
  final IconData icon;
  final Color color;
}

const kUiModels = <UiModel>[
  UiModel(
    id: 'gpt-6',
    label: 'GPT-6',
    runtimeHint: 'grok',
    icon: Icons.auto_awesome,
    color: Color(0xFF10A37F),
  ),
  UiModel(
    id: 'claude-4',
    label: 'Claude 4',
    runtimeHint: 'gemini',
    icon: Icons.psychology_alt_outlined,
    color: Color(0xFFD97706),
  ),
  UiModel(
    id: 'gemini-2.5',
    label: 'Gemini 2.5',
    runtimeHint: 'gemini',
    icon: Icons.diamond_outlined,
    color: Color(0xFF4285F4),
  ),
  UiModel(
    id: 'copilot',
    label: 'Copilot',
    runtimeHint: 'grok',
    icon: Icons.flight_outlined,
    color: Color(0xFF0078D4),
  ),
];

UiModel uiModelById(String id) =>
    kUiModels.firstWhere((m) => m.id == id, orElse: () => kUiModels.first);

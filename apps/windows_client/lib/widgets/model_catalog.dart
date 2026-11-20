import 'package:flutter/material.dart';

/// Single runtime model surface — xAI Grok only.
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
  /// Always grok / grok-fast — API ignores other vendors.
  final String runtimeHint;
  final IconData icon;
  final Color color;
}

const kGrokModel = UiModel(
  id: 'grok',
  label: 'Grok',
  runtimeHint: 'grok',
  icon: Icons.auto_awesome,
  color: Color(0xFF1D9BF0),
);

/// Kept as a one-item list for call sites that still iterate models.
const kUiModels = <UiModel>[kGrokModel];

UiModel uiModelById(String id) =>
    kUiModels.firstWhere((m) => m.id == id, orElse: () => kGrokModel);

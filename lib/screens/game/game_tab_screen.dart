import 'package:flutter/material.dart';

import 'freeflow/free_flow_screen.dart';

/// GAME tab — opens straight into Free Flow.
///
/// Bro v2: "what should happen is the paywall shows when they press the
/// SPEAK icon in roleplay." The tab-entry gate that used to live here
/// is gone — every gate now sits inside [FreeFlowScreen._goLive], which
/// is the single chokepoint every speak action (auto-fire on tab open,
/// CHANGE CHARACTER, manual chip tap, retry from error) flows through.
/// So a free user lands inside the live experience; their FIRST speak
/// uses the free pass; every subsequent speak hits the paywall.
class GameTabScreen extends StatelessWidget {
  const GameTabScreen({super.key});

  @override
  Widget build(BuildContext context) => const FreeFlowScreen(tabMode: true);
}

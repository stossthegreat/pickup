import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/auralay_app_colors.dart';

/// Robust pop for the full-screen sessions and result cards.
///
/// Every session / scene / result screen is pushed on the ROOT
/// navigator (via `Navigator.of(context, rootNavigator: true).push`),
/// but the old close paths called a bare `Navigator.of(context).pop()`
/// behind a `canPop` guard — which silently no-ops when the context
/// resolves to a nested (go_router shell) navigator that has nothing
/// to pop. That is why the X / DONE / GO BACK buttons looked dead.
///
/// This tries the local navigator first (correct route ownership),
/// then falls back to the root navigator. One of them owns the route,
/// so the screen always closes.
void safePop(BuildContext context) {
  final local = Navigator.of(context);
  if (local.canPop()) {
    local.pop();
    return;
  }
  Navigator.of(context, rootNavigator: true).maybePop();
}

/// SafeCloseButton — the one X used by every full-screen session.
///
/// Two guarantees the home-grown X buttons kept failing on:
///   1. **44×44 pt tap target** (Apple HIG floor). Smaller targets get
///      eaten by adjacent widgets on iOS hit-testing.
///   2. **Pops immediately.** [onTearDown] (if supplied) runs as a
///      background future via [unawaited] — it never blocks the pop.
///      If [onTearDown] hangs (a stuck WebSocket close, etc.), the user
///      is still off the screen.
///
/// Drop in any AppBar / Positioned / Stack chrome:
///   SafeCloseButton(onTearDown: _stopSession)
class SafeCloseButton extends StatelessWidget {
  final Future<void> Function()? onTearDown;
  final Color color;
  final double size;

  const SafeCloseButton({
    super.key,
    this.onTearDown,
    this.color = AppColors.textPrimary,
    this.size = 24,
  });

  void _close(BuildContext context) {
    HapticFeedback.lightImpact();
    if (onTearDown != null) {
      // Fire-and-forget. If the teardown hangs, we still pop.
      // ignore: discarded_futures
      onTearDown!();
    }
    safePop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Close',
      button: true,
      child: GestureDetector(
        onTap: () => _close(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(Icons.close_rounded, color: color, size: size),
        ),
      ),
    );
  }
}

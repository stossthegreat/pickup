import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend/auth_service.dart';
import '../../services/backend/tiers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/academy/game_button.dart';

/// PICK YOUR NAME — its own screen, one job.
///
/// This used to be a cramped text field bolted to the top of the account
/// screen, above two sign-in buttons and a wall of copy, so nobody knew
/// what it was for or that it mattered. It matters a lot: it's the name
/// on every leaderboard row and every squad roster, it's globally
/// unique, and without one you show up as ANON to everybody.
///
/// So it gets a page. It says what the name is FOR, it checks
/// availability while you type (the DB has `handle text unique`, so a
/// clash would otherwise only surface as a failed save), and it's
/// skippable — plenty of people only ever want the solo app.
class HandleScreen extends StatefulWidget {
  /// True during onboarding: no back arrow, and continuing goes home.
  final bool onboarding;
  const HandleScreen({super.key, this.onboarding = false});

  @override
  State<HandleScreen> createState() => _HandleScreenState();
}

enum _Check { idle, checking, free, taken, invalid, offline }

class _HandleScreenState extends State<HandleScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  _Check _state = _Check.idle;
  bool _saving = false;

  /// Letters, numbers, underscore. 3–14. Keeps rosters readable and
  /// stops lookalike/whitespace games.
  static final _valid = RegExp(r'^[A-Za-z0-9_]{3,14}$');

  @override
  void initState() {
    super.initState();
    _prefill();
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    final existing = await AuthService.getHandle();
    if (!mounted || existing == null || existing.isEmpty) return;
    _ctrl.text = existing;
    setState(() => _state = _Check.free);
  }

  void _onChanged() {
    _debounce?.cancel();
    final v = _ctrl.text.trim();
    if (v.isEmpty) {
      setState(() => _state = _Check.idle);
      return;
    }
    if (!_valid.hasMatch(v)) {
      setState(() => _state = _Check.invalid);
      return;
    }
    setState(() => _state = _Check.checking);
    // Debounced so a fast typist doesn't fire a query per keystroke.
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final free = await AuthService.isHandleFree(v);
      if (!mounted || _ctrl.text.trim() != v) return;
      setState(() => _state = free == null
          ? _Check.offline
          : free
              ? _Check.free
              : _Check.taken);
    });
  }

  Future<void> _save() async {
    if (_state != _Check.free || _saving) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final ok = await AuthService.setHandle(_ctrl.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      // Say WHY. 'Taken' is only one of the reasons a save can fail, and
      // showing it for all of them sent people hunting for a new name
      // when the real problem was their profile row.
      final why = AuthService.lastError ?? '';
      if (why.contains('taken')) {
        setState(() => _state = _Check.taken);
      } else {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface1,
            title: Text('Couldn\'t save that name',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w900)),
            content: SelectableText(why.isEmpty ? 'Unknown error.' : why,
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('OK',
                    style: GoogleFonts.inter(
                        color: AppColors.red, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
      }
      return;
    }
    _done();
  }

  void _done() {
    if (widget.onboarding) {
      // The last screen of onboarding. He has paid, been tested, seen his
      // score and claimed an account — home is the right place to land
      // and there is nothing left to sell him.
      context.go('/home');
    } else {
      context.pop();
    }
  }

  (Color, IconData?, String) get _status => switch (_state) {
        _Check.idle => (AppColors.textMuted, null,
            '3–14 characters · letters, numbers, underscore'),
        _Check.checking => (AppColors.textTertiary, null, 'Checking…'),
        _Check.free => (kNeon, Icons.check_circle_rounded, 'Available'),
        _Check.taken => (AppColors.red, Icons.cancel_rounded,
            'Taken — someone got there first'),
        _Check.invalid => (AppColors.signalAmber, Icons.error_rounded,
            '3–14 characters · letters, numbers, underscore only'),
        _Check.offline => (AppColors.textTertiary, Icons.cloud_off_rounded,
            'Can\'t check right now — try again'),
      };

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon, statusText) = _status;

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.onboarding)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
              const SizedBox(height: 18),

              Text('PICK YOUR NAME',
                      style: GoogleFonts.inter(
                        color: AppColors.red,
                        fontSize: 11,
                        letterSpacing: 3.4,
                        fontWeight: FontWeight.w900,
                      ))
                  .animate()
                  .fadeIn(duration: 300.ms),
              const SizedBox(height: 10),
              Text('This is the name\neveryone else sees.',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.12,
                        letterSpacing: -1,
                        fontWeight: FontWeight.w900,
                      ))
                  .animate()
                  .fadeIn(delay: 60.ms, duration: 320.ms),
              const SizedBox(height: 20),

              // WHAT IT'S FOR — the part that was missing entirely.
              _Use(
                  icon: Icons.emoji_events_rounded,
                  text: 'Your row on the voice rizz leaderboard'),
              _Use(
                  icon: Icons.shield_rounded,
                  text: 'Your name on your squad\'s board'),
              _Use(
                  icon: Icons.sports_mma_rounded,
                  text: 'What rivals see when you battle them'),

              const SizedBox(height: 22),

              // ── The field ────────────────────────────────────────
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                maxLength: 14,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 22,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w900,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'MARCUS',
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                  filled: true,
                  fillColor: AppColors.surface1,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: statusColor, width: 1.6),
                  ),
                  suffixIcon: _state == _Check.checking
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.textTertiary),
                          ),
                        )
                      : statusIcon == null
                          ? null
                          : Icon(statusIcon, color: statusColor),
                ),
              ),
              const SizedBox(height: 9),
              Row(children: [
                Expanded(
                  child: Text(statusText,
                      style: GoogleFonts.inter(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ]),

              const Spacer(),

              GameButton(
                label: _saving ? 'SAVING…' : 'CLAIM IT',
                pulse: _state == _Check.free && !_saving,
                onTap: _state == _Check.free && !_saving ? _save : null,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _done();
                },
                child: Text(
                    widget.onboarding
                        ? 'SKIP — I\'M HERE TO TRAIN ALONE'
                        : 'CANCEL',
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 11.5,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w800,
                    )),
              ),
              if (widget.onboarding)
                Text('You show up as ANON until you pick one.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _Use extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Use({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: [
        Icon(icon, size: 15, color: AppColors.textTertiary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
        ),
      ]),
    );
  }
}

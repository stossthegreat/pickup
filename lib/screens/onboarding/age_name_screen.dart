import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/local_store_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/imhim_wordmark.dart';

/// Onboarding — name + age band. Both feed the AI: characters use his
/// name in first-date / texting scenes, and pitch their register to his
/// age band. Sits between the manifesto and the AI-consent gate.
///
/// When [fromSettings] is true it's opened for editing and pops on save
/// instead of routing forward.
class AgeNameScreen extends StatefulWidget {
  final bool fromSettings;
  const AgeNameScreen({super.key, this.fromSettings = false});

  @override
  State<AgeNameScreen> createState() => _AgeNameScreenState();
}

class _AgeNameScreenState extends State<AgeNameScreen> {
  final _nameCtrl = TextEditingController();
  String? _ageGroup;

  static const _bands = <String>['18-25', '26-35', '36-45', '46+'];

  @override
  void initState() {
    super.initState();
    // Pre-fill when editing from Settings.
    // ignore: discarded_futures
    _prefill();
  }

  Future<void> _prefill() async {
    final name = await LocalStoreService.userName();
    final age = await LocalStoreService.userAgeGroup();
    if (!mounted) return;
    setState(() {
      if (name != null) _nameCtrl.text = name;
      _ageGroup = age;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canContinue => _ageGroup != null;

  Future<void> _continue() async {
    if (!_canContinue) return;
    HapticFeedback.mediumImpact();
    await LocalStoreService.setUserName(_nameCtrl.text);
    await LocalStoreService.setUserAgeGroup(_ageGroup);
    if (widget.fromSettings) {
      if (!mounted) return;
      context.pop();
      return;
    }
    // Stamp onboarding complete here (the gender picker is bypassed in
    // the new funnel — this is a men's app, so pin male coding). Doing it
    // now means a mid-flow bail still re-shows onboarding, but finishing
    // this step routes returning users straight to /home.
    await LocalStoreService.setUserGender('m');
    await LocalStoreService.setOnboarded(true);
    if (!mounted) return;
    // AI-data consent gate next, then the paywall.
    context.go('/onboarding/consent');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Subtle red wash from the top.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -1.1),
                    radius: 1.2,
                    colors: [
                      AppColors.red.withValues(alpha: 0.16),
                      Colors.black,
                    ],
                    stops: const [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 12, 26, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.fromSettings)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: AppColors.textSecondary),
                      ),
                    )
                  else
                    const SizedBox(height: 8),
                  // Scrollable so the keyboard can never overflow the form.
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 14),
                          const Center(
                            child: ImHimWordmark(fontSize: 40, letterSpacing: -1.2),
                          ),
                  const SizedBox(height: 30),

                  Text('Before we start.',
                      style: GoogleFonts.playfairDisplay(
                        color: AppColors.textPrimary,
                        fontSize: 34,
                        height: 1.05,
                        letterSpacing: -0.6,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w800,
                      )).animate().fadeIn(duration: 420.ms),
                  const SizedBox(height: 8),
                  Text('So the girls talk to you like a real person — not a '
                      'stranger.',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 14.5,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      )).animate().fadeIn(delay: 120.ms, duration: 420.ms),

                  const SizedBox(height: 32),

                  // ── Name ──────────────────────────────────────────────
                  Text('WHAT SHOULD SHE CALL YOU?',
                      style: GoogleFonts.inter(
                        color: AppColors.red,
                        fontSize: 11,
                        letterSpacing: 2.6,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.surface3, width: 0.8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      cursorColor: AppColors.red,
                      maxLength: 24,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Your first name',
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.textTertiary,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // ── Age band ──────────────────────────────────────────
                  Text('YOUR AGE',
                      style: GoogleFonts.inter(
                        color: AppColors.red,
                        fontSize: 11,
                        letterSpacing: 2.6,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 4),
                  Text('Shapes how she reads you.',
                      style: GoogleFonts.inter(
                        color: AppColors.textTertiary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final b in _bands) _ageChip(b),
                    ],
                  ),

                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Continue ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: _canContinue
                          ? AppColors.red
                          : AppColors.red.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _canContinue ? _continue : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 19),
                          alignment: Alignment.center,
                          child: Text('CONTINUE',
                              style: GoogleFonts.inter(
                                color: _canContinue
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.5),
                                fontSize: 14.5,
                                letterSpacing: 3.2,
                                fontWeight: FontWeight.w900,
                              )),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ageChip(String band) {
    final selected = _ageGroup == band;
    return Material(
      color: selected ? AppColors.red : AppColors.surface1,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _ageGroup = band);
        },
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? AppColors.red
                  : AppColors.red.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Text(band,
              style: GoogleFonts.inter(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              )),
        ),
      ),
    );
  }
}

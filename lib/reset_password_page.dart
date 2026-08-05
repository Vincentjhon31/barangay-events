import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'auth_service.dart';
import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';

/// Shown instead of the normal signed-in app shell the moment a "Forgot
/// password?" reset link's AuthChangeEvent.passwordRecovery fires (see
/// AppAuthService.passwordRecoveryEvents in main.dart's
/// _BarangayCalendarAppState) — the recovery flow already grants a real,
/// if narrowly-scoped, active session, which [AppAuthService.updatePassword]
/// works against exactly the same way a normal signed-in password change
/// does. No "current password" field, unlike the Security page's own
/// change-password form — this whole screen only exists because the user
/// couldn't produce the current one.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.authService, required this.onDone});

  final AppAuthService authService;

  /// Called once the new password is saved — the caller falls back to its
  /// normal signed-in/out routing from here.
  final VoidCallback onDone;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authEmailPasswordRequired)),
      );
      return;
    }
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authPasswordTooShort)),
      );
      return;
    }
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.resetPasswordMismatch)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.authService.updatePassword(newPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.resetPasswordSuccess)),
      );
      widget.onDone();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authFailedGeneric)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const Positioned.fill(child: LiquidGlassBackdrop()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: GlassPanel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.resetPasswordTitle,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.resetPasswordSubtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          key: const Key('reset-password-new-field'),
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: l10n.resetPasswordNewLabel,
                            prefixIcon: glassFieldIcon(FontAwesomeIcons.lock, size: 14),
                            prefixIconConstraints: glassFieldIconConstraints,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          key: const Key('reset-password-confirm-field'),
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: l10n.resetPasswordConfirmLabel,
                            prefixIcon: glassFieldIcon(FontAwesomeIcons.lock, size: 14),
                            prefixIconConstraints: glassFieldIconConstraints,
                          ),
                        ),
                        const SizedBox(height: 22),
                        FilledButton(
                          key: const Key('reset-password-save-button'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          onPressed: _saving ? null : () => _save(),
                          child: Text(
                            _saving ? l10n.pleaseWait : l10n.resetPasswordSaveButton,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

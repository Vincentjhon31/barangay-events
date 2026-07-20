import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'auth_service.dart';
import 'l10n/app_localizations.dart';
import 'liquid_glass_components.dart';

/// Change sign-in email / password — reached from Profile's "Security" tile.
class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key, required this.authService});

  final AppAuthService authService;

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  late final TextEditingController _newEmailController;
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _savingEmail = false;
  bool _savingPassword = false;

  @override
  void initState() {
    super.initState();
    _newEmailController =
        TextEditingController(text: widget.authService.currentUser?.email ?? '');
  }

  @override
  void dispose() {
    _newEmailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateEmail() async {
    final l10n = AppLocalizations.of(context)!;
    final currentEmail = widget.authService.currentUser?.email ?? '';
    final newEmail = _newEmailController.text.trim();

    if (newEmail.isEmpty || !newEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidEmailError)),
      );
      return;
    }
    if (newEmail == currentEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sameEmailError)),
      );
      return;
    }

    setState(() => _savingEmail = true);
    try {
      await widget.authService.updateEmail(newEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.emailUpdateSuccess),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.updateEmailError(error.toString()))),
      );
    } finally {
      if (mounted) setState(() => _savingEmail = false);
    }
  }

  Future<void> _updatePassword() async {
    final l10n = AppLocalizations.of(context)!;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordTooShortError)),
      );
      return;
    }
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordMismatchError)),
      );
      return;
    }

    setState(() => _savingPassword = true);
    try {
      await widget.authService.updatePassword(newPassword);
      if (!mounted) return;
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordUpdateSuccess)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.updatePasswordError(error.toString()))),
      );
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currentEmail = widget.authService.currentUser?.email ?? '';

    return GlassSubPage(
      title: l10n.securityTitle,
      subtitle: l10n.securitySubtitle,
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.securityEmailSectionTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.securityCurrentEmail(currentEmail),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('security-new-email-field'),
                controller: _newEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.newEmailLabel,
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.envelope),
                  prefixIconConstraints: glassFieldIconConstraints,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                key: const Key('security-update-email-button'),
                onPressed: _savingEmail ? null : () => unawaited(_updateEmail()),
                icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 14),
                label: Text(_savingEmail ? l10n.updatingButton : l10n.updateEmailButton),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.securityPasswordSectionTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('security-new-password-field'),
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  labelText: l10n.newPasswordLabel,
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.lock),
                  prefixIconConstraints: glassFieldIconConstraints,
                  suffixIcon: IconButton(
                    key: const Key('security-toggle-new-password-visibility'),
                    tooltip: _obscureNewPassword ? l10n.showPasswordTooltip : l10n.hidePasswordTooltip,
                    icon: FaIcon(
                      _obscureNewPassword ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash,
                      size: 16,
                    ),
                    onPressed: () =>
                        setState(() => _obscureNewPassword = !_obscureNewPassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('security-confirm-password-field'),
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: l10n.confirmNewPasswordLabel,
                  prefixIcon: glassFieldIcon(FontAwesomeIcons.lock),
                  prefixIconConstraints: glassFieldIconConstraints,
                  suffixIcon: IconButton(
                    key: const Key('security-toggle-confirm-password-visibility'),
                    tooltip:
                        _obscureConfirmPassword ? l10n.showPasswordTooltip : l10n.hidePasswordTooltip,
                    icon: FaIcon(
                      _obscureConfirmPassword ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash,
                      size: 16,
                    ),
                    onPressed: () => setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('security-update-password-button'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _savingPassword ? null : () => unawaited(_updatePassword()),
                icon: const FaIcon(FontAwesomeIcons.key, size: 14),
                label: Text(_savingPassword ? l10n.updatingButton : l10n.updatePasswordButton),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

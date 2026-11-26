import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

enum _Mode { password, signUp, code }

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  _Mode _mode = _Mode.password;
  bool _codeSent = false;
  String? _notice;
  String? _failure;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  void _setMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _codeSent = false;
      _notice = null;
      _failure = null;
    });
  }

  Future<void> _submit(AuthService auth, AppLocalizations loc) async {
    if (auth.busy) return;
    final email = _email.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _notice = null;
      _failure = null;
    });

    AuthOutcome outcome;
    switch (_mode) {
      case _Mode.password:
        if (_password.text.isEmpty) return;
        outcome = await auth.signInWithPassword(email, _password.text);
      case _Mode.signUp:
        if (_password.text.isEmpty) return;
        outcome = await auth.signUpWithPassword(email, _password.text);
      case _Mode.code:
        if (_codeSent) {
          if (_code.text.trim().isEmpty) return;
          outcome = await auth.verifyEmailCode(email, _code.text);
        } else {
          outcome = await auth.sendEmailCode(email);
        }
    }
    if (!mounted) return;
    setState(() {
      switch (outcome) {
        case AuthOutcome.signedIn:
          break;
        case AuthOutcome.confirmEmail:
          _notice = loc.authConfirmEmail;
          _mode = _Mode.password;
        case AuthOutcome.codeSent:
          _codeSent = true;
          _notice = loc.authCodeSent;
        case AuthOutcome.failed:
          _failure = auth.error == 'auth_not_configured'
              ? loc.authNotConfigured
              : loc.authFailed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final auth = context.watch<AuthService>();
    final isCode = _mode == _Mode.code;
    final needsPassword = !isCode;

    final String primaryLabel;
    if (isCode) {
      primaryLabel = _codeSent ? loc.authVerifyCode : loc.authSendCode;
    } else if (_mode == _Mode.signUp) {
      primaryLabel = loc.authCreateAccount;
    } else {
      primaryLabel = loc.authSignIn;
    }

    return Scaffold(
      backgroundColor: AppTheme.mist,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.border),
              ),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppTheme.brandName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loc.authSignInTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _email,
                      enabled: !auth.busy && !_codeSent,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: loc.authEmail),
                    ),
                    if (needsPassword) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        enabled: !auth.busy,
                        obscureText: true,
                        autofillHints: [
                          _mode == _Mode.signUp
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onSubmitted: (_) => _submit(auth, loc),
                        decoration:
                            InputDecoration(labelText: loc.authPassword),
                      ),
                    ],
                    if (isCode && _codeSent) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _code,
                        enabled: !auth.busy,
                        keyboardType: TextInputType.number,
                        onSubmitted: (_) => _submit(auth, loc),
                        decoration: InputDecoration(labelText: loc.authCodeLabel),
                      ),
                    ],
                    if (_notice != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _notice!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                    if (_failure != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _failure!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: auth.busy ? null : () => _submit(auth, loc),
                      child: auth.busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(primaryLabel),
                    ),
                    const SizedBox(height: 8),
                    if (!isCode)
                      TextButton(
                        onPressed: auth.busy
                            ? null
                            : () => _setMode(
                                  _mode == _Mode.signUp
                                      ? _Mode.password
                                      : _Mode.signUp,
                                ),
                        child: Text(
                          _mode == _Mode.signUp
                              ? loc.authSwitchToSignIn
                              : loc.authSwitchToSignUp,
                        ),
                      ),
                    TextButton(
                      onPressed: auth.busy
                          ? null
                          : () => _setMode(isCode ? _Mode.password : _Mode.code),
                      child: Text(
                        isCode ? loc.authUsePassword : loc.authUseEmailCode,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

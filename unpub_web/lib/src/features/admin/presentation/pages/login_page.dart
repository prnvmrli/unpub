import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:unpub_web/l10n/app_localizations.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../l10n/app_localizations_ext.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../bloc/login_cubit.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({required this.authSession, required this.from, super.key});

  final AuthSession authSession;
  final String? from;

  void _search(BuildContext context, String value) {
    final query = value.trim();
    if (query.isEmpty) {
      context.go('/packages');
      return;
    }
    context.go('/packages?q=${Uri.encodeQueryComponent(query)}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocProvider(
      create: (_) => LoginCubit(authSession),
      child: BlocListener<LoginCubit, LoginState>(
        listenWhen: (previous, current) => previous.success != current.success,
        listener: (context, state) {
          if (state.success) {
            context.go(from ?? '/dashboard');
          }
        },
        child: AppScaffold(
          authSession: authSession,
          searchQuery: null,
          onSearch: (value) => _search(context, value),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: FadeSlideIn(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: BlocBuilder<LoginCubit, LoginState>(
                      builder: (context, state) {
                        final cubit = context.read<LoginCubit>();
                        final errorText = _errorText(l10n, state.errorType);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.login,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              onChanged: cubit.onEmailChanged,
                              onSubmitted: (_) => cubit.login(),
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              obscureText: true,
                              onChanged: cubit.onPasswordChanged,
                              onSubmitted: (_) => cubit.login(),
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            if (errorText != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                errorText,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: state.loading ? null : cubit.login,
                                child: Text(
                                  state.loading ? l10n.validating : l10n.login,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _errorText(AppLocalizations l10n, LoginErrorType? errorType) {
    switch (errorType) {
      case LoginErrorType.emptyCredentials:
        return 'Enter email and password';
      case LoginErrorType.invalidCredentials:
        return l10n.invalidTokenUnauthorized;
      case null:
        return null;
    }
  }
}

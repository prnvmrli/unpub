import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../core/theme/theme_cubit.dart';
import '../../l10n/app_localizations_ext.dart';

class TopHeader extends StatefulWidget {
  const TopHeader({
    required this.authSession,
    required this.searchQuery,
    required this.onSearch,
    super.key,
  });

  final AuthSession authSession;
  final String? searchQuery;
  final ValueChanged<String> onSearch;

  @override
  State<TopHeader> createState() => _TopHeaderState();
}

class _TopHeaderState extends State<TopHeader> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery ?? '');
  }

  @override
  void didUpdateWidget(covariant TopHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.searchQuery ?? '';
    if (_controller.text != value) {
      _controller.text = value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 920;
    final currentPath = GoRouterState.of(context).uri.path;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF0E2B4D), Color(0xFF13406F), Color(0xFF1A568C)]
              : const [Color(0xFF024D96), Color(0xFF0A73C8), Color(0xFF1495DA)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _Brand(onTap: () => context.go('/')),
                            const Spacer(),
                            const _ThemeToggleButton(),
                            const SizedBox(width: 8),
                            _AdminNav(
                              authSession: widget.authSession,
                              currentPath: currentPath,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.search,
                          onSubmitted: widget.onSearch,
                          decoration: _searchDecoration(context),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        _Brand(onTap: () => context.go('/')),
                        const SizedBox(width: 24),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            textInputAction: TextInputAction.search,
                            onSubmitted: widget.onSearch,
                            decoration: _searchDecoration(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const _ThemeToggleButton(),
                        const SizedBox(width: 8),
                        _AdminNav(
                          authSession: widget.authSession,
                          currentPath: currentPath,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _searchDecoration(BuildContext context) => InputDecoration(
    hintText: context.l10n.searchPackages,
    prefixIcon: const Icon(Icons.search, size: 20),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    fillColor: Colors.white,
    filled: true,
  );
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return IconButton.filledTonal(
          onPressed: () => context.read<ThemeCubit>().toggle(),
          tooltip: isDark ? l10n.switchToLight : l10n.switchToDark,
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            foregroundColor: Colors.white,
          ),
        );
      },
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bubble_chart_rounded, color: Colors.white, size: 22),
          SizedBox(width: 8),
          Text(
            'pub.dev',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNav extends StatelessWidget {
  const _AdminNav({required this.authSession, required this.currentPath});

  final AuthSession authSession;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: authSession,
      builder: (context, _) {
        final target = authSession.isLoggedIn ? '/dashboard' : '/login';
        final selected =
            currentPath.startsWith('/dashboard') ||
            currentPath.startsWith('/admin') ||
            currentPath == '/login';
        return TextButton(
          onPressed: () => context.go(target),
          style: TextButton.styleFrom(
            backgroundColor: selected
                ? Colors.white.withValues(alpha: 0.16)
                : null,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            authSession.isLoggedIn ? l10n.admin : l10n.login,
            style: TextStyle(color: selected ? Colors.white : Colors.white70),
          ),
        );
      },
    );
  }
}

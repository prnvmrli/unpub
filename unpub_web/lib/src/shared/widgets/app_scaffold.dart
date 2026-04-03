import 'package:flutter/material.dart';

import '../../core/auth/auth_session.dart';
import 'top_header.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.authSession,
    required this.searchQuery,
    required this.onSearch,
    required this.body,
    super.key,
  });

  final AuthSession authSession;
  final String? searchQuery;
  final ValueChanged<String> onSearch;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF0C1118), Color(0xFF101825), Color(0xFF131E2D)]
                      : const [Color(0xFFF2F7FD), Color(0xFFEEF4FA), Color(0xFFF8FAFD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Column(
            children: [
              TopHeader(
                authSession: authSession,
                searchQuery: searchQuery,
                onSearch: onSearch,
              ),
              Expanded(child: body),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:unpub_web/src/core/auth/auth_session.dart';
import 'package:unpub_web/src/core/network/api_client.dart';
import 'package:unpub_web/src/features/admin/presentation/bloc/login_cubit.dart';

void main() {
  test('LoginCubit emits emptyToken error when token is missing', () async {
    final authSession = _FakeAuthSession(nextLoginResult: true);
    final cubit = LoginCubit(authSession);
    addTearDown(cubit.close);

    await cubit.login();

    expect(cubit.state.errorType, LoginErrorType.emptyToken);
    expect(cubit.state.success, false);
  });

  test('LoginCubit emits invalidToken when auth rejects token', () async {
    final authSession = _FakeAuthSession(nextLoginResult: false);
    final cubit = LoginCubit(authSession);
    addTearDown(cubit.close);

    cubit.onTokenChanged('bad-token');
    await cubit.login();

    expect(authSession.lastToken, 'bad-token');
    expect(cubit.state.loading, false);
    expect(cubit.state.errorType, LoginErrorType.invalidToken);
    expect(cubit.state.success, false);
  });

  test('LoginCubit emits success when auth accepts token', () async {
    final authSession = _FakeAuthSession(nextLoginResult: true);
    final cubit = LoginCubit(authSession);
    addTearDown(cubit.close);

    cubit.onTokenChanged('good-token');
    await cubit.login();

    expect(authSession.lastToken, 'good-token');
    expect(cubit.state.loading, false);
    expect(cubit.state.errorType, isNull);
    expect(cubit.state.success, true);
  });
}

class _FakeAuthSession extends AuthSession {
  _FakeAuthSession({required this.nextLoginResult}) : super(const ApiClient());

  final bool nextLoginResult;
  String? lastToken;

  @override
  Future<bool> login(String token) async {
    lastToken = token;
    return nextLoginResult;
  }
}


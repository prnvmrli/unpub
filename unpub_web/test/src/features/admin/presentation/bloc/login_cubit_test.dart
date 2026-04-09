import 'package:flutter_test/flutter_test.dart';
import 'package:unpub_web/src/core/auth/auth_session.dart';
import 'package:unpub_web/src/core/network/api_client.dart';
import 'package:unpub_web/src/features/admin/presentation/bloc/login_cubit.dart';

void main() {
  test(
    'LoginCubit emits emptyCredentials in email/password mode when missing',
    () async {
      final authSession = _FakeAuthSession(nextLoginResult: true);
      final cubit = LoginCubit(authSession);
      addTearDown(cubit.close);

      await cubit.login();

      expect(cubit.state.errorType, LoginErrorType.emptyCredentials);
      expect(cubit.state.success, false);
    },
  );

  test(
    'LoginCubit emits emptyToken error in token mode when token is missing',
    () async {
      final authSession = _FakeAuthSession(nextLoginResult: true);
      final cubit = LoginCubit(authSession);
      addTearDown(cubit.close);

      cubit.setUsePasswordLogin(false);
      await cubit.login();

      expect(cubit.state.errorType, LoginErrorType.emptyToken);
      expect(cubit.state.success, false);
    },
  );

  test('LoginCubit emits invalidToken when auth rejects token login', () async {
    final authSession = _FakeAuthSession(nextLoginResult: false);
    final cubit = LoginCubit(authSession);
    addTearDown(cubit.close);

    cubit.setUsePasswordLogin(false);
    cubit.onTokenChanged('bad-token');
    await cubit.login();

    expect(authSession.lastToken, 'bad-token');
    expect(cubit.state.loading, false);
    expect(cubit.state.errorType, LoginErrorType.invalidToken);
    expect(cubit.state.success, false);
  });

  test('LoginCubit emits success when auth accepts token login', () async {
    final authSession = _FakeAuthSession(nextLoginResult: true);
    final cubit = LoginCubit(authSession);
    addTearDown(cubit.close);

    cubit.setUsePasswordLogin(false);
    cubit.onTokenChanged('good-token');
    await cubit.login();

    expect(authSession.lastToken, 'good-token');
    expect(cubit.state.loading, false);
    expect(cubit.state.errorType, isNull);
    expect(cubit.state.success, true);
  });

  test('LoginCubit emits success when auth accepts password login', () async {
    final authSession = _FakeAuthSession(nextPasswordLoginResult: true);
    final cubit = LoginCubit(authSession);
    addTearDown(cubit.close);

    cubit.onEmailChanged('dev@example.com');
    cubit.onPasswordChanged('secret');
    await cubit.login();

    expect(authSession.lastEmail, 'dev@example.com');
    expect(authSession.lastPassword, 'secret');
    expect(cubit.state.loading, false);
    expect(cubit.state.errorType, isNull);
    expect(cubit.state.success, true);
  });
}

class _FakeAuthSession extends AuthSession {
  _FakeAuthSession({
    this.nextLoginResult = true,
    this.nextPasswordLoginResult = true,
  }) : super(ApiClient());

  final bool nextLoginResult;
  final bool nextPasswordLoginResult;
  String? lastToken;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<bool> login(String token) async {
    lastToken = token;
    return nextLoginResult;
  }

  @override
  Future<bool> loginWithToken(String token) async {
    lastToken = token;
    return nextLoginResult;
  }

  @override
  Future<bool> loginWithPassword({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;
    return nextPasswordLoginResult;
  }
}

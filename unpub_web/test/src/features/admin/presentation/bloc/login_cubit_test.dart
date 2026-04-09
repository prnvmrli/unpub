import 'package:flutter_test/flutter_test.dart';
import 'package:unpub_web/src/core/auth/auth_session.dart';
import 'package:unpub_web/src/core/network/api_client.dart';
import 'package:unpub_web/src/features/admin/presentation/bloc/login_cubit.dart';

void main() {
  test(
    'LoginCubit emits emptyCredentials when email/password are missing',
    () async {
      final authSession = _FakeAuthSession(nextPasswordLoginResult: true);
      final cubit = LoginCubit(authSession);
      addTearDown(cubit.close);

      await cubit.login();

      expect(cubit.state.errorType, LoginErrorType.emptyCredentials);
      expect(cubit.state.success, false);
    },
  );

  test(
    'LoginCubit emits invalidCredentials when auth rejects password login',
    () async {
      final authSession = _FakeAuthSession(nextPasswordLoginResult: false);
      final cubit = LoginCubit(authSession);
      addTearDown(cubit.close);

      cubit.onEmailChanged('dev@example.com');
      cubit.onPasswordChanged('bad-password');
      await cubit.login();

      expect(authSession.lastEmail, 'dev@example.com');
      expect(authSession.lastPassword, 'bad-password');
      expect(cubit.state.loading, false);
      expect(cubit.state.errorType, LoginErrorType.invalidCredentials);
      expect(cubit.state.success, false);
    },
  );

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
  _FakeAuthSession({this.nextPasswordLoginResult = true}) : super(ApiClient());

  final bool nextPasswordLoginResult;
  String? lastEmail;
  String? lastPassword;

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

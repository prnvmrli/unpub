import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';

class LoginState {
  const LoginState({
    this.email = '',
    this.password = '',
    this.loading = false,
    this.errorType,
    this.success = false,
  });

  final String email;
  final String password;
  final bool loading;
  final LoginErrorType? errorType;
  final bool success;

  LoginState copyWith({
    String? email,
    String? password,
    bool? loading,
    LoginErrorType? errorType,
    bool clearErrorType = false,
    bool? success,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      loading: loading ?? this.loading,
      errorType: clearErrorType ? null : (errorType ?? this.errorType),
      success: success ?? this.success,
    );
  }
}

enum LoginErrorType { emptyCredentials, invalidCredentials }

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._authSession) : super(const LoginState());

  final AuthSession _authSession;

  void onEmailChanged(String value) {
    emit(state.copyWith(email: value, clearErrorType: true, success: false));
  }

  void onPasswordChanged(String value) {
    emit(state.copyWith(password: value, clearErrorType: true, success: false));
  }

  Future<void> login() async {
    final email = state.email.trim();
    final password = state.password;
    if (email.isEmpty || password.isEmpty) {
      emit(
        state.copyWith(errorType: LoginErrorType.emptyCredentials, success: false),
      );
      return;
    }

    emit(state.copyWith(loading: true, clearErrorType: true, success: false));
    final isValid = await _authSession.loginWithPassword(
      email: email,
      password: password,
    );
    if (!isValid) {
      emit(
        state.copyWith(
          loading: false,
          errorType: LoginErrorType.invalidCredentials,
          success: false,
        ),
      );
      return;
    }
    emit(state.copyWith(loading: false, success: true));
  }
}

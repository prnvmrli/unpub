import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';

class LoginState {
  const LoginState({
    this.usePasswordLogin = true,
    this.email = '',
    this.password = '',
    this.token = '',
    this.loading = false,
    this.errorType,
    this.success = false,
  });

  final bool usePasswordLogin;
  final String email;
  final String password;
  final String token;
  final bool loading;
  final LoginErrorType? errorType;
  final bool success;

  LoginState copyWith({
    bool? usePasswordLogin,
    String? email,
    String? password,
    String? token,
    bool? loading,
    LoginErrorType? errorType,
    bool clearErrorType = false,
    bool? success,
  }) {
    return LoginState(
      usePasswordLogin: usePasswordLogin ?? this.usePasswordLogin,
      email: email ?? this.email,
      password: password ?? this.password,
      token: token ?? this.token,
      loading: loading ?? this.loading,
      errorType: clearErrorType ? null : (errorType ?? this.errorType),
      success: success ?? this.success,
    );
  }
}

enum LoginErrorType { emptyCredentials, emptyToken, invalidToken }

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._authSession) : super(const LoginState());

  final AuthSession _authSession;

  void setUsePasswordLogin(bool value) {
    emit(
      state.copyWith(
        usePasswordLogin: value,
        clearErrorType: true,
        success: false,
      ),
    );
  }

  void onEmailChanged(String value) {
    emit(state.copyWith(email: value, clearErrorType: true, success: false));
  }

  void onPasswordChanged(String value) {
    emit(state.copyWith(password: value, clearErrorType: true, success: false));
  }

  void onTokenChanged(String value) {
    emit(state.copyWith(token: value, clearErrorType: true, success: false));
  }

  Future<void> login() async {
    if (state.usePasswordLogin) {
      final email = state.email.trim();
      final password = state.password;
      if (email.isEmpty || password.isEmpty) {
        emit(
          state.copyWith(
            errorType: LoginErrorType.emptyCredentials,
            success: false,
          ),
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
            errorType: LoginErrorType.invalidToken,
            success: false,
          ),
        );
        return;
      }
      emit(state.copyWith(loading: false, success: true));
      return;
    }

    final token = state.token.trim();
    if (token.isEmpty) {
      emit(
        state.copyWith(errorType: LoginErrorType.emptyToken, success: false),
      );
      return;
    }

    emit(state.copyWith(loading: true, clearErrorType: true, success: false));
    final isValid = await _authSession.loginWithToken(token);
    if (!isValid) {
      emit(
        state.copyWith(
          loading: false,
          errorType: LoginErrorType.invalidToken,
          success: false,
        ),
      );
      return;
    }
    emit(state.copyWith(loading: false, success: true));
  }
}

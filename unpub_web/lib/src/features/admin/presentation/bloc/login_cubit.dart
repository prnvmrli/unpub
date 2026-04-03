import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';

class LoginState {
  const LoginState({
    this.token = '',
    this.loading = false,
    this.errorType,
    this.success = false,
  });

  final String token;
  final bool loading;
  final LoginErrorType? errorType;
  final bool success;

  LoginState copyWith({
    String? token,
    bool? loading,
    LoginErrorType? errorType,
    bool clearErrorType = false,
    bool? success,
  }) {
    return LoginState(
      token: token ?? this.token,
      loading: loading ?? this.loading,
      errorType: clearErrorType ? null : (errorType ?? this.errorType),
      success: success ?? this.success,
    );
  }
}

enum LoginErrorType {
  emptyToken,
  invalidToken,
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._authSession) : super(const LoginState());

  final AuthSession _authSession;

  void onTokenChanged(String value) {
    emit(state.copyWith(token: value, clearErrorType: true, success: false));
  }

  Future<void> login() async {
    final token = state.token.trim();
    if (token.isEmpty) {
      emit(state.copyWith(errorType: LoginErrorType.emptyToken, success: false));
      return;
    }

    emit(state.copyWith(loading: true, clearErrorType: true, success: false));
    final isValid = await _authSession.login(token);
    if (!isValid) {
      emit(state.copyWith(
        loading: false,
        errorType: LoginErrorType.invalidToken,
        success: false,
      ));
      return;
    }
    emit(state.copyWith(loading: false, success: true));
  }
}

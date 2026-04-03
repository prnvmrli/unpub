import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/admin_models.dart';
import '../../data/admin_repository.dart';

class AdminTokensState {
  const AdminTokensState({
    this.loading = false,
    this.includeAll = false,
    this.errorMessage,
    this.notice,
    this.ownerName = '',
    this.expiresAt = '',
    this.revokeTokenId = '',
    this.tokens = const [],
    this.downloads = const [],
  });

  final bool loading;
  final bool includeAll;
  final String? errorMessage;
  final AdminNotice? notice;
  final String ownerName;
  final String expiresAt;
  final String revokeTokenId;
  final List<AdminToken> tokens;
  final List<DownloadLog> downloads;

  AdminTokensState copyWith({
    bool? loading,
    bool? includeAll,
    String? errorMessage,
    AdminNotice? notice,
    bool clearFeedback = false,
    String? ownerName,
    String? expiresAt,
    String? revokeTokenId,
    List<AdminToken>? tokens,
    List<DownloadLog>? downloads,
  }) {
    return AdminTokensState(
      loading: loading ?? this.loading,
      includeAll: includeAll ?? this.includeAll,
      errorMessage: clearFeedback ? null : (errorMessage ?? this.errorMessage),
      notice: clearFeedback ? null : (notice ?? this.notice),
      ownerName: ownerName ?? this.ownerName,
      expiresAt: expiresAt ?? this.expiresAt,
      revokeTokenId: revokeTokenId ?? this.revokeTokenId,
      tokens: tokens ?? this.tokens,
      downloads: downloads ?? this.downloads,
    );
  }
}

class AdminTokensCubit extends Cubit<AdminTokensState> {
  AdminTokensCubit({
    required AdminRepository adminRepository,
  }) : _adminRepository = adminRepository,
       super(const AdminTokensState());

  final AdminRepository _adminRepository;

  void setIncludeAll(bool value) {
    emit(state.copyWith(includeAll: value));
  }

  void setOwnerName(String value) {
    emit(state.copyWith(ownerName: value, clearFeedback: true));
  }

  void setExpiresAt(String value) {
    emit(state.copyWith(expiresAt: value, clearFeedback: true));
  }

  void setRevokeTokenId(String value) {
    emit(state.copyWith(revokeTokenId: value, clearFeedback: true));
  }

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearFeedback: true));
    try {
      final tokens = await _adminRepository.listTokens(
        includeAll: state.includeAll,
      );
      final downloads = await _adminRepository.listDownloads(
        includeAll: state.includeAll,
      );
      emit(state.copyWith(
        loading: false,
        tokens: tokens,
        downloads: downloads,
      ));
    } catch (error) {
      emit(state.copyWith(loading: false, errorMessage: error.toString()));
    }
  }

  Future<void> createToken() async {
    emit(state.copyWith(loading: true, clearFeedback: true));
    try {
      final token = await _adminRepository.createToken(
        ownerName: state.ownerName,
        expiresAt: state.expiresAt,
      );
      emit(state.copyWith(
        loading: false,
        notice: AdminNotice.tokenCreated(token),
        ownerName: '',
        expiresAt: '',
      ));
      await load();
    } catch (error) {
      emit(state.copyWith(loading: false, errorMessage: error.toString()));
    }
  }

  Future<void> revokeToken() async {
    final tokenId = state.revokeTokenId.trim();
    if (tokenId.isEmpty) {
      emit(state.copyWith(notice: const AdminNotice.missingTokenId()));
      return;
    }

    emit(state.copyWith(loading: true, clearFeedback: true));
    try {
      await _adminRepository.revokeToken(
        tokenId: tokenId,
      );
      emit(state.copyWith(
        loading: false,
        notice: AdminNotice.tokenRevoked(tokenId),
        revokeTokenId: '',
      ));
      await load();
    } catch (error) {
      emit(state.copyWith(loading: false, errorMessage: error.toString()));
    }
  }
}

enum AdminNoticeType {
  tokenCreated,
  tokenRevoked,
  missingTokenId,
}

class AdminNotice {
  const AdminNotice(this.type, this.value);

  const AdminNotice.tokenCreated(String value)
      : type = AdminNoticeType.tokenCreated,
        value = value;

  const AdminNotice.tokenRevoked(String value)
      : type = AdminNoticeType.tokenRevoked,
        value = value;

  const AdminNotice.missingTokenId()
      : type = AdminNoticeType.missingTokenId,
        value = null;

  final AdminNoticeType type;
  final String? value;
}

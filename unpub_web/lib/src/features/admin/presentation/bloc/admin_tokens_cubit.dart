import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/admin_models.dart';
import '../../data/admin_repository.dart';

class AdminTokensState {
  const AdminTokensState({
    this.loading = false,
    this.includeAll = false,
    this.errorMessage,
    this.notice,
    this.tokenName = '',
    this.expiryDays = '',
    this.canDownload = true,
    this.canPublish = false,
    this.createdToken,
    this.revokeTokenId = '',
    this.tokens = const [],
    this.users = const [],
    this.downloads = const [],
  });

  final bool loading;
  final bool includeAll;
  final String? errorMessage;
  final AdminNotice? notice;
  final String tokenName;
  final String expiryDays;
  final bool canDownload;
  final bool canPublish;
  final String? createdToken;
  final String revokeTokenId;
  final List<AdminToken> tokens;
  final List<AdminUser> users;
  final List<DownloadLog> downloads;

  AdminTokensState copyWith({
    bool? loading,
    bool? includeAll,
    String? errorMessage,
    AdminNotice? notice,
    bool clearFeedback = false,
    String? tokenName,
    String? expiryDays,
    bool? canDownload,
    bool? canPublish,
    String? createdToken,
    bool clearCreatedToken = false,
    String? revokeTokenId,
    List<AdminToken>? tokens,
    List<AdminUser>? users,
    List<DownloadLog>? downloads,
  }) {
    return AdminTokensState(
      loading: loading ?? this.loading,
      includeAll: includeAll ?? this.includeAll,
      errorMessage: clearFeedback ? null : (errorMessage ?? this.errorMessage),
      notice: clearFeedback ? null : (notice ?? this.notice),
      tokenName: tokenName ?? this.tokenName,
      expiryDays: expiryDays ?? this.expiryDays,
      canDownload: canDownload ?? this.canDownload,
      canPublish: canPublish ?? this.canPublish,
      createdToken: clearCreatedToken
          ? null
          : (createdToken ?? this.createdToken),
      revokeTokenId: revokeTokenId ?? this.revokeTokenId,
      tokens: tokens ?? this.tokens,
      users: users ?? this.users,
      downloads: downloads ?? this.downloads,
    );
  }
}

class AdminTokensCubit extends Cubit<AdminTokensState> {
  AdminTokensCubit({required AdminRepository adminRepository})
    : _adminRepository = adminRepository,
      super(const AdminTokensState());

  final AdminRepository _adminRepository;

  void setIncludeAll(bool value) {
    emit(state.copyWith(includeAll: value));
  }

  void setTokenName(String value) {
    emit(state.copyWith(tokenName: value, clearFeedback: true));
  }

  void setExpiryDays(String value) {
    emit(state.copyWith(expiryDays: value, clearFeedback: true));
  }

  void setCanDownload(bool value) {
    emit(state.copyWith(canDownload: value, clearFeedback: true));
  }

  void setCanPublish(bool value) {
    emit(state.copyWith(canPublish: value, clearFeedback: true));
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
      final users = await _adminRepository.listUsers();
      final downloads = await _adminRepository.listDownloads(
        includeAll: state.includeAll,
      );
      emit(
        state.copyWith(
          loading: false,
          tokens: tokens,
          users: users,
          downloads: downloads,
        ),
      );
    } catch (error) {
      emit(state.copyWith(loading: false, errorMessage: error.toString()));
    }
  }

  Future<void> createToken() async {
    final name = state.tokenName.trim();
    if (name.isEmpty) {
      emit(state.copyWith(errorMessage: 'Token name is required'));
      return;
    }
    if (!state.canDownload && !state.canPublish) {
      emit(state.copyWith(errorMessage: 'Select at least one permission'));
      return;
    }

    final daysRaw = state.expiryDays.trim();
    int? expiryDays;
    if (daysRaw.isNotEmpty) {
      expiryDays = int.tryParse(daysRaw);
      if (expiryDays == null || expiryDays < 1 || expiryDays > 3650) {
        emit(state.copyWith(errorMessage: 'Expiry days must be 1-3650'));
        return;
      }
    }

    emit(state.copyWith(loading: true, clearFeedback: true));
    try {
      final token = await _adminRepository.createToken(
        name: name,
        expiryDays: expiryDays,
        canDownload: state.canDownload,
        canPublish: state.canPublish,
      );
      emit(
        state.copyWith(
          loading: false,
          notice: const AdminNotice.tokenCreated(),
          tokenName: '',
          expiryDays: '',
          canDownload: true,
          canPublish: false,
          createdToken: token,
        ),
      );
      await load();
    } catch (error) {
      emit(state.copyWith(loading: false, errorMessage: error.toString()));
    }
  }

  void clearCreatedToken() {
    emit(state.copyWith(clearCreatedToken: true));
  }

  Future<void> revokeToken() async {
    final tokenId = state.revokeTokenId.trim();
    if (tokenId.isEmpty) {
      emit(state.copyWith(notice: const AdminNotice.missingTokenId()));
      return;
    }

    emit(state.copyWith(loading: true, clearFeedback: true));
    try {
      await _adminRepository.revokeToken(tokenId: tokenId);
      emit(
        state.copyWith(
          loading: false,
          notice: AdminNotice.tokenRevoked(tokenId),
          revokeTokenId: '',
        ),
      );
      await load();
    } catch (error) {
      emit(state.copyWith(loading: false, errorMessage: error.toString()));
    }
  }

  Future<void> revokeTokenById(int tokenId) async {
    emit(state.copyWith(loading: true, clearFeedback: true));
    try {
      await _adminRepository.revokeToken(tokenId: '$tokenId');
      emit(
        state.copyWith(
          loading: false,
          notice: AdminNotice.tokenRevoked('$tokenId'),
          revokeTokenId: '',
        ),
      );
      await load();
    } catch (error) {
      emit(state.copyWith(loading: false, errorMessage: error.toString()));
    }
  }

  Future<void> disableUserById(int userId) async {
    emit(state.copyWith(loading: true, clearFeedback: true));
    try {
      await _adminRepository.disableUser(userId: '$userId');
      emit(
        state.copyWith(
          loading: false,
          notice: AdminNotice.userDisabled('$userId'),
        ),
      );
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
  userDisabled,
}

class AdminNotice {
  const AdminNotice(this.type, this.value);

  const AdminNotice.tokenCreated()
    : type = AdminNoticeType.tokenCreated,
      value = null;

  const AdminNotice.tokenRevoked(String value)
    : type = AdminNoticeType.tokenRevoked,
      value = value;

  const AdminNotice.missingTokenId()
    : type = AdminNoticeType.missingTokenId,
      value = null;

  const AdminNotice.userDisabled(String value)
    : type = AdminNoticeType.userDisabled,
      value = value;

  final AdminNoticeType type;
  final String? value;
}

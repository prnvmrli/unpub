import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:unpub_api/models.dart';

import '../../data/packages_repository.dart';

sealed class PackageListState {
  const PackageListState();
}

class PackageListLoading extends PackageListState {
  const PackageListLoading();
}

class PackageListLoaded extends PackageListState {
  const PackageListLoaded(this.data);

  final ListApi data;
}

class PackageListError extends PackageListState {
  const PackageListError(this.message);

  final String message;
}

class PackageListCubit extends Cubit<PackageListState> {
  PackageListCubit(this._packagesRepository) : super(const PackageListLoading());

  final PackagesRepository _packagesRepository;

  Future<void> load({
    required int size,
    required int page,
    String? searchQuery,
  }) async {
    emit(const PackageListLoading());
    try {
      final result = await _packagesRepository.fetchPackages(
        size: size,
        page: page,
        query: searchQuery,
      );
      emit(PackageListLoaded(result));
    } catch (error) {
      emit(PackageListError(error.toString()));
    }
  }
}

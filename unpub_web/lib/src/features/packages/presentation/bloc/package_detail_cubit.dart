import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:unpub_api/models.dart';

import '../../data/packages_repository.dart';

sealed class PackageDetailState {
  const PackageDetailState();
}

class PackageDetailLoading extends PackageDetailState {
  const PackageDetailLoading();
}

class PackageDetailLoaded extends PackageDetailState {
  const PackageDetailLoaded(this.data);

  final WebapiDetailView data;
}

class PackageDetailError extends PackageDetailState {
  const PackageDetailError(this.message);

  final String message;
}

class PackageDetailCubit extends Cubit<PackageDetailState> {
  PackageDetailCubit(this._packagesRepository) : super(const PackageDetailLoading());

  final PackagesRepository _packagesRepository;

  Future<void> load({
    required String name,
    required String version,
  }) async {
    emit(const PackageDetailLoading());
    try {
      final result = await _packagesRepository.fetchPackage(name, version);
      emit(PackageDetailLoaded(result));
    } catch (error) {
      emit(PackageDetailError(error.toString()));
    }
  }
}

dev-web:
	cd unpub_web &&\
	flutter pub get &&\
	flutter run -d chrome

dev-api:
	cd unpub &&	dart run build_runner watch

build:
	cd unpub_web &&\
	flutter pub get &&\
	flutter build web
	dart format **/*.dart

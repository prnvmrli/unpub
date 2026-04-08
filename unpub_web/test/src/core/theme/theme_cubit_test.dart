import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unpub_web/src/core/theme/theme_cubit.dart';

void main() {
  test('ThemeCubit defaults to light and toggles light<->dark', () {
    final cubit = ThemeCubit();
    addTearDown(cubit.close);

    expect(cubit.state, ThemeMode.light);

    cubit.toggle();
    expect(cubit.state, ThemeMode.dark);

    cubit.toggle();
    expect(cubit.state, ThemeMode.light);
  });
}


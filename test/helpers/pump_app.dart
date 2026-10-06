import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfound/app/theme/app_theme.dart';
import 'package:wayfound/app/theme/theme_provider.dart';
import 'package:wayfound/features/auth/data/auth_provider.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';

extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    AuthRepository? authRepository,
    SharedPreferences? sharedPreferences,
    AsyncValue<User?>? authUserValue,
    ThemeMode themeMode = ThemeMode.system,
  }) async {
    if (sharedPreferences == null) {
      SharedPreferences.setMockInitialValues({});
    }
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();

    return pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (authRepository != null)
            authRepositoryProvider.overrideWithValue(authRepository),
          if (authUserValue != null)
            authUserProvider.overrideWithValue(authUserValue),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: widget,
        ),
      ),
    );
  }
}

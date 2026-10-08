import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfound/app/theme/app_theme.dart';
import 'package:wayfound/app/theme/theme_provider.dart';
import 'package:wayfound/features/auth/data/auth_provider.dart';
import 'package:wayfound/features/auth/data/auth_repository.dart';
import 'package:wayfound/features/auth/domain/app_user.dart';
import 'package:wayfound/features/trips/data/trips_providers.dart';

extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    AuthRepository? authRepository,
    SharedPreferences? sharedPreferences,
    AsyncValue<User?>? authUserValue,
    AsyncValue<AppUser?>? appUserValue,
    ThemeMode themeMode = ThemeMode.system,
  }) async {
    if (sharedPreferences == null) {
      SharedPreferences.setMockInitialValues({});
    }
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();

    final AsyncValue<AppUser?>? effectiveAppUser;
    if (appUserValue != null) {
      effectiveAppUser = appUserValue;
    } else if (authUserValue != null) {
      effectiveAppUser = authUserValue.when(
        data: (user) => AsyncData(
          user == null
              ? null
              : AppUser(
                  uid: user.uid,
                  email: user.email ?? '',
                  displayName:
                      user.displayName ?? user.email?.split('@').first ?? '',
                  photoUrl: user.photoURL,
                ),
        ),
        loading: () => const AsyncLoading(),
        error: (e, st) => AsyncError(e, st),
      );
    } else {
      effectiveAppUser = null;
    }

    return pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          myTripsProvider.overrideWithValue(const AsyncData([])),
          if (authRepository != null)
            authRepositoryProvider.overrideWithValue(authRepository),
          if (authUserValue != null)
            authUserProvider.overrideWithValue(authUserValue),
          if (effectiveAppUser != null)
            appUserProvider.overrideWithValue(effectiveAppUser),
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

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Configuración del proyecto de Firebase (booking-artist-1b85f).
///
/// Cada plataforma (web, iPhone, Android) se registra aparte en la Consola de
/// Firebase → Configuración del proyecto → Tus apps. Mientras una plataforma
/// no tenga su App ID, la app corre ahí en modo demo: los datos viven en
/// memoria y se borran al cerrarla.
const _apiKey = 'AIzaSyDtKR2JetnbgUv2xzfHN940Wv6S9_DaICQ';
const _projectId = 'booking-artist-1b85f';
const _senderId = '963662530921';
const _bucket = 'booking-artist-1b85f.firebasestorage.app';

/// Identificador de la app en Apple y Google Play. No se puede cambiar
/// después de subir la primera versión.
const appBundleId = 'com.tarimapr.app';

/// App de iPhone: Consola de Firebase → Agregar app → iOS, con el bundle ID
/// de arriba. Copia aquí el GOOGLE_APP_ID del GoogleService-Info.plist
/// (empieza con 1:963662530921:ios:). También se puede pasar al compilar con
/// --dart-define=FIREBASE_IOS_APP_ID=...
const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');

/// App de Android: igual, con "Agregar app → Android" y el mismo ID.
const _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');

FirebaseOptions? get cloudOptions {
  if (kIsWeb) {
    return const FirebaseOptions(
      apiKey: _apiKey,
      authDomain: 'booking-artist-1b85f.firebaseapp.com',
      projectId: _projectId,
      storageBucket: _bucket,
      messagingSenderId: _senderId,
      appId: '1:963662530921:web:cea8717ca9e3a9d95b95f8',
      measurementId: 'G-JY2W6K33SE',
    );
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS when _iosAppId.isNotEmpty:
      return const FirebaseOptions(
        apiKey: _apiKey,
        appId: _iosAppId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        storageBucket: _bucket,
        iosBundleId: appBundleId,
      );
    case TargetPlatform.android when _androidAppId.isNotEmpty:
      return const FirebaseOptions(
        apiKey: _apiKey,
        appId: _androidAppId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        storageBucket: _bucket,
      );
    default:
      return null;
  }
}

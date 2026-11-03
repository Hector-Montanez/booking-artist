import 'package:firebase_core/firebase_core.dart';

/// Configuración del proyecto de Firebase (Consola de Firebase → Configuración
/// del proyecto → Tus apps → app web → firebaseConfig).
///
/// Si se pone en null la app funciona en modo demo: los datos viven en memoria
/// y se borran al recargar.
// ignore: unnecessary_nullable_for_final_variable_declarations
const FirebaseOptions? cloudOptions = FirebaseOptions(
  apiKey: 'AIzaSyDtKR2JetnbgUv2xzfHN940Wv6S9_DaICQ',
  authDomain: 'booking-artist-1b85f.firebaseapp.com',
  projectId: 'booking-artist-1b85f',
  storageBucket: 'booking-artist-1b85f.firebasestorage.app',
  messagingSenderId: '963662530921',
  appId: '1:963662530921:web:cea8717ca9e3a9d95b95f8',
  measurementId: 'G-JY2W6K33SE',
);

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyCd2oortGut_-oaipa',
      appId: '1:248380732121:web:ed4486',
      messagingSenderId: '248380732121',
      projectId: 'agri-dahshory',
      storageBucket: 'agri-dahshory.firebasestorage.app',
    );
  }
}

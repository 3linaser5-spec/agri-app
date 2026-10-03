import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyCd2oortGut_-oaipa', // لو مفتاحك الأصلي مختلف، غيره من إعدادات Firebase
      appId: '1:248380732121:android:a2438adbcdde00461b744c8', // الرقم الجديد اللي جبناه
      messagingSenderId: '248380732121',
      projectId: 'agri-dahshory',
      storageBucket: 'agri-dahshory.firebasestorage.app',
    );
  }
}

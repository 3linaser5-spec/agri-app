import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/subscriber_model.dart';

class SubscriberService {
  SubscriberService._();
  static final _firestore = FirebaseFirestore.instance;

  static Stream<List<ActiveSubscriber>> watchActiveSubscribers() {
    return _firestore
        .collectionGroup('services')
        .where('service', isEqualTo: 'satellite_monitoring')
        .snapshots()
        .asyncMap((snapshot) async {
      final result = <ActiveSubscriber>[];
      for (final entitlement in snapshot.docs) {
        final data = entitlement.data();
        if (data['status']?.toString() != 'active') continue;
        final uid = data['uid']?.toString() ??
            entitlement.reference.parent.parent?.id ??
            entitlement.id;
        final profile = await _firestore.collection('users').doc(uid).get();
        final merged = <String, dynamic>{
          ...?profile.data(),
          ...data,
        };
        result.add(ActiveSubscriber.fromData(uid, merged));
      }
      result.sort((a, b) => a.name.compareTo(b.name));
      return result;
    });
  }

  static Future<void> setAreaLimit({
    required String uid,
    required double maxAreaFeddan,
  }) async {
    if (!maxAreaFeddan.isFinite || maxAreaFeddan <= 0) {
      throw ArgumentError('حد المساحة يجب أن يكون أكبر من صفر.');
    }
    await FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('setSatelliteSubscriberQuota')
        .call({'uid': uid, 'maxAreaFeddan': maxAreaFeddan});
  }
}

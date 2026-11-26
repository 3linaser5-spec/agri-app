import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/farm_workspace_models.dart';
import 'offline_farm_store.dart';
import 'offline_outbox.dart';

/// سجل المحاصيل: مواسم الزراعة، الإنتاج المتوقع والفعلي، التكاليف والإيراد.
///
/// التخزين في `cropSeasons`، وكل موسم يخص صاحبه عبر `owner_id`. يعمل بدون
/// إنترنت بنفس آلية [OfflineFarmStore].
class CropLogService {
  CropLogService._();

  static const String collectionName = 'cropSeasons';

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static String _cacheKey(String uid) => 'crop_seasons_$uid';

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection(collectionName);

  /// تحميل المواسم، مع مزامنة العمليات المؤجلة أولًا.
  static Future<List<CropSeason>> loadSeasons() async {
    final uid = _uid;
    if (uid == null) return const [];
    await OfflineFarmStore.flush();
    final seasons = await OfflineFarmStore.cachedList<CropSeason>(
      key: _cacheKey(uid),
      fetch: () async {
        final snapshot =
            await _collection.where('owner_id', isEqualTo: uid).get();
        final items = snapshot.docs
            .map((doc) => CropSeason.fromMap(doc.id, doc.data()))
            .toList(growable: false);
        items.sort((a, b) => b.plantingDate.compareTo(a.plantingDate));
        return items;
      },
      toJson: (season) => {'id': season.id, ...season.toMap()},
      fromJson: (json) =>
          CropSeason.fromMap(json['id']?.toString() ?? '', json),
    );
    return seasons;
  }

  static Future<CropSeason?> addSeason(CropSeason season) async {
    final uid = _uid;
    if (uid == null) return null;
    final reference = _collection.doc();
    final stored = CropSeason(
      id: reference.id,
      ownerId: uid,
      plotId: season.plotId,
      crop: season.crop,
      variety: season.variety,
      areaFeddan: season.areaFeddan,
      plantingDate: season.plantingDate,
      harvestDate: season.harvestDate,
      expectedYieldKg: season.expectedYieldKg,
      actualYieldKg: season.actualYieldKg,
      pricePerKg: season.pricePerKg,
      expenses: season.expenses,
      notes: season.notes,
    );
    await OfflineFarmStore.write(
      collection: collectionName,
      docId: stored.id,
      type: OfflineOperationType.set,
      data: {
        ...stored.toMap(),
        'created_at': DateTime.now().toIso8601String(),
      },
    );
    return stored;
  }

  static Future<void> updateSeason(CropSeason season) async {
    await OfflineFarmStore.write(
      collection: collectionName,
      docId: season.id,
      type: OfflineOperationType.set,
      data: season.toMap(),
    );
  }

  static Future<void> deleteSeason(CropSeason season) async {
    await OfflineFarmStore.write(
      collection: collectionName,
      docId: season.id,
      type: OfflineOperationType.delete,
    );
  }

  /// مواسم قطعة معيّنة (أو الكل لو لم تُحدد).
  static List<CropSeason> filterByPlot(
    List<CropSeason> seasons,
    String? plotId,
  ) {
    if (plotId == null) return seasons;
    return seasons
        .where((season) => season.plotId == plotId)
        .toList(growable: false);
  }

  /// ملخص الأرباح لكل موسم (للعرض في لوحة الأرباح).
  static Map<String, CropProfitSummary> summaryByCrop(
    Iterable<CropSeason> seasons,
  ) {
    final groups = <String, List<CropSeason>>{};
    for (final season in seasons) {
      groups.putIfAbsent(season.crop, () => []).add(season);
    }
    return {
      for (final entry in groups.entries)
        entry.key: CropProfitSummary.fromSeasons(entry.value),
    };
  }

  /// أفضل موسم ربحًا (بالجنيه)، أو `null` لو لا توجد بيانات.
  static CropSeason? bestSeason(Iterable<CropSeason> seasons) {
    CropSeason? best;
    for (final season in seasons) {
      if (best == null || season.netProfit > best.netProfit) best = season;
    }
    return best;
  }

  static Future<void> logFailure(Object error) async {
    debugPrint('تعذر تنفيذ عملية سجل المحاصيل: $error');
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/farm_workspace_models.dart';
import 'offline_farm_store.dart';
import 'offline_outbox.dart';

/// إدارة أكثر من مزرعة/قطعة، مع حفظ «القطعة النشطة» على الجهاز حتى تفتح
/// الشاشات على نفس القطعة بدون إعادة اختيار.
class FarmSiteService {
  FarmSiteService._();

  static const String sitesCollection = 'farmSites';
  static const String plotsCollection = 'farmPlots';
  static const String _activePlotKey = 'active_plot_id';

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _collection(String name) =>
      FirebaseFirestore.instance.collection(name);

  static String _sitesCacheKey(String uid) => 'sites_$uid';
  static String _plotsCacheKey(String uid) => 'plots_$uid';

  static Future<List<FarmSite>> loadSites() async {
    final uid = _uid;
    if (uid == null) return const [];
    await OfflineFarmStore.flush();
    return OfflineFarmStore.cachedList<FarmSite>(
      key: _sitesCacheKey(uid),
      fetch: () async {
        final snapshot = await _collection(sitesCollection)
            .where('owner_id', isEqualTo: uid)
            .get();
        final sites = snapshot.docs
            .map((doc) => FarmSite.fromMap(doc.id, doc.data()))
            .toList(growable: false);
        sites.sort((a, b) => a.name.compareTo(b.name));
        return sites;
      },
      toJson: (site) => {'id': site.id, ...site.toMap()},
      fromJson: (json) =>
          FarmSite.fromMap(json['id']?.toString() ?? '', json),
    );
  }

  static Future<List<FarmPlot>> loadPlots() async {
    final uid = _uid;
    if (uid == null) return const [];
    await OfflineFarmStore.flush();
    return OfflineFarmStore.cachedList<FarmPlot>(
      key: _plotsCacheKey(uid),
      fetch: () async {
        final snapshot = await _collection(plotsCollection)
            .where('owner_id', isEqualTo: uid)
            .get();
        final plots = snapshot.docs
            .map((doc) => FarmPlot.fromMap(doc.id, doc.data()))
            .toList(growable: false);
        plots.sort((a, b) {
          final bySite = a.siteId.compareTo(b.siteId);
          return bySite != 0 ? bySite : a.name.compareTo(b.name);
        });
        return plots;
      },
      toJson: (plot) => {'id': plot.id, ...plot.toMap()},
      fromJson: (json) =>
          FarmPlot.fromMap(json['id']?.toString() ?? '', json),
    );
  }

  static Future<FarmSite?> addSite({
    required String name,
    String governorate = '',
    String notes = '',
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    final reference = _collection(sitesCollection).doc();
    final site = FarmSite(
      id: reference.id,
      ownerId: uid,
      name: name.trim(),
      governorate: governorate.trim(),
      notes: notes.trim(),
      createdAt: DateTime.now(),
    );
    await OfflineFarmStore.write(
      collection: sitesCollection,
      docId: site.id,
      type: OfflineOperationType.set,
      data: site.toMap(),
    );
    return site;
  }

  static Future<FarmPlot?> addPlot({
    required String siteId,
    required String name,
    String crop = '',
    double areaFeddan = 0,
    String irrigationMethod = '',
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    final reference = _collection(plotsCollection).doc();
    final plot = FarmPlot(
      id: reference.id,
      ownerId: uid,
      siteId: siteId,
      name: name.trim(),
      crop: crop.trim(),
      areaFeddan: areaFeddan,
      irrigationMethod: irrigationMethod,
      createdAt: DateTime.now(),
    );
    await OfflineFarmStore.write(
      collection: plotsCollection,
      docId: plot.id,
      type: OfflineOperationType.set,
      data: plot.toMap(),
    );
    return plot;
  }

  static Future<void> deletePlot(FarmPlot plot) async {
    await OfflineFarmStore.write(
      collection: plotsCollection,
      docId: plot.id,
      type: OfflineOperationType.delete,
    );
    if (await activePlotId() == plot.id) await setActivePlotId(null);
  }

  /// القطعة النشطة المحفوظة على الجهاز، أو `null` لو لم تُختر بعد.
  static Future<String?> activePlotId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activePlotKey);
  }

  static Future<void> setActivePlotId(String? plotId) async {
    final prefs = await SharedPreferences.getInstance();
    if (plotId == null) {
      await prefs.remove(_activePlotKey);
    } else {
      await prefs.setString(_activePlotKey, plotId);
    }
  }

  /// اختيار قطعة نشطة افتراضية: المحفوظة إن وُجدت، وإلا أول قطعة.
  static Future<FarmPlot?> resolveActivePlot(List<FarmPlot> plots) async {
    if (plots.isEmpty) return null;
    final saved = await activePlotId();
    if (saved != null) {
      for (final plot in plots) {
        if (plot.id == saved) return plot;
      }
    }
    final first = plots.first;
    await setActivePlotId(first.id);
    return first;
  }

  /// بحث سريع بالاسم لإيجاد قطعة (للبحث في القوائم الطويلة).
  static List<FarmPlot> search(List<FarmPlot> plots, String query) {
    final text = query.trim();
    if (text.isEmpty) return plots;
    return plots
        .where((plot) =>
            plot.name.contains(text) ||
            plot.crop.contains(text) ||
            plot.irrigationMethod.contains(text))
        .toList(growable: false);
  }

  static Future<void> logFailure(Object error) async {
    debugPrint('تعذر تنفيذ عملية مزرعة: $error');
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/irrigation_catalog_models.dart';

class IrrigationCatalogService {
  final FirebaseFirestore firestore;
  IrrigationCatalogService({FirebaseFirestore? firestore}) : firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<IrrigationCatalogItem>> watchItems({String? kind}) => firestore.collection('irrigationCatalog').where('active', isEqualTo: true).snapshots().map((s) {
    final items = s.docs.map((d) => IrrigationCatalogItem.fromJson(d.data())).where((x) => kind == null || x.kind == kind).toList(growable: false);
    return items;
  });

  Future<void> saveItem(IrrigationCatalogItem item, String adminUid) => firestore.collection('irrigationCatalog').doc(item.id).set({...item.toJson(), 'updated_by': adminUid, 'updated_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  Future<void> archiveItem(String id, String adminUid) => firestore.collection('irrigationCatalog').doc(id).set({'active': false, 'updated_by': adminUid, 'updated_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  Future<void> saveSatelliteLink(IrrigationSatelliteLink link, String ownerUid) => firestore.collection('irrigationDesignProjects').doc(link.projectId).collection('satelliteLinks').doc(link.zoneId).set({...link.toJson(), 'owner_id': ownerUid, 'updated_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  Stream<List<IrrigationSatelliteLink>> watchSatelliteLinks(String projectId) => firestore.collection('irrigationDesignProjects').doc(projectId).collection('satelliteLinks').snapshots().map((s) => s.docs.map((d) => IrrigationSatelliteLink.fromJson(d.data())).toList(growable: false));
}

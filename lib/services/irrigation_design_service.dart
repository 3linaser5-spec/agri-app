import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/irrigation_design_models.dart';

class IrrigationDesignService {
  final FirebaseFirestore firestore;
  IrrigationDesignService({FirebaseFirestore? firestore}) : firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> saveProject({required String ownerId, required IrrigationDesignProject project}) async {
    if (ownerId.trim().isEmpty) throw ArgumentError.value(ownerId, 'ownerId', 'required');
    final ref = firestore.collection('irrigationDesignProjects').doc(project.id);
    await ref.set({...project.toJson(), 'owner_id': ownerId, 'updated_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await ref.collection('versions').doc(project.version.toString()).set({'owner_id': ownerId, 'version': project.version.toJson(), 'project': project.toJson(), 'created_at': FieldValue.serverTimestamp()});
  }

  Future<IrrigationDesignProject?> getProject(String id) async {
    final snapshot = await firestore.collection('irrigationDesignProjects').doc(id).get();
    final data = snapshot.data();
    return data == null ? null : IrrigationDesignProject.fromJson(data);
  }

  Stream<List<IrrigationDesignProject>> watchProjects(String ownerId) => firestore.collection('irrigationDesignProjects').where('owner_id', isEqualTo: ownerId).snapshots().map((s) => s.docs.map((d) => IrrigationDesignProject.fromJson(d.data())).toList(growable: false));
}

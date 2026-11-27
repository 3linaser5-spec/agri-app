import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/farm_team_models.dart';
import 'farm_task_service.dart';
import 'offline_farm_store.dart';
import 'offline_outbox.dart';

/// أسباب فشل الانضمام بكود دعوة.
enum FarmJoinFailure { invalidCode, expired, offline, alreadyMember, notSignedIn, unknown }

/// نتيجة محاولة الانضمام لفريق مزرعة.
class FarmJoinResult {
  final FarmMember? member;
  final FarmJoinFailure? failure;

  const FarmJoinResult.success(this.member) : failure = null;
  const FarmJoinResult.failure(this.failure) : member = null;

  bool get success => member != null;

  String get message => switch (failure) {
        FarmJoinFailure.invalidCode =>
          'الكود غير صحيح. راجع الكود مع المهندس أو مالك المزرعة.',
        FarmJoinFailure.expired => 'انتهت صلاحية الكود. اطلب كودًا جديدًا.',
        FarmJoinFailure.offline =>
          'تحتاج اتصالًا بالإنترنت للانضمام أول مرة، وبعدها يعمل التطبيق بدون إنترنت.',
        FarmJoinFailure.alreadyMember => 'أنت عضو في هذه المزرعة بالفعل.',
        FarmJoinFailure.notSignedIn => 'سجّل الدخول أولًا للانضمام للفريق.',
        FarmJoinFailure.unknown => 'تعذر الانضمام الآن. حاول مرة أخرى.',
        null => 'تم الانضمام لفريق المزرعة.',
      };
}

/// إدارة فريق المزرعة الهرمي: دعوة الأعضاء بأدوارهم، إسناد المهام نزولًا،
/// ومشاركة البرنامج السمادي مع المشرفين والعمال.
class FarmTeamService {
  FarmTeamService._();

  static const String membersCollection = 'farmMembers';
  static const String invitesCollection = 'farmInvites';
  static const String programSharesCollection = 'farmProgramShares';

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static String get currentUserName {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final email = user?.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    final phone = user?.phoneNumber ?? '';
    return phone.isEmpty ? 'مستخدم نباتي' : phone;
  }

  static CollectionReference<Map<String, dynamic>> _collection(String name) =>
      FirebaseFirestore.instance.collection(name);

  static String _membersCacheKey(String uid) => 'team_members_$uid';
  static String _sharesCacheKey(String uid) => 'team_programs_$uid';

  /// كل الأعضاء الذين يخصّون المستخدم: الأعضاء في مزارعه + عضوياته في مزارع
  /// غيره (لو انضم لفريق مهندس آخر).
  static Future<List<FarmMember>> loadMembers() async {
    final uid = _uid;
    if (uid == null) return const [];
    await OfflineFarmStore.flush();
    return OfflineFarmStore.cachedList<FarmMember>(
      key: _membersCacheKey(uid),
      fetch: () async {
        final owned = await _collection(membersCollection)
            .where('owner_id', isEqualTo: uid)
            .get();
        final memberships = await _collection(membersCollection)
            .where('member_uid', isEqualTo: uid)
            .get();
        final byId = <String, FarmMember>{};
        for (final doc in [...owned.docs, ...memberships.docs]) {
          byId[doc.id] = FarmMember.fromMap(doc.id, doc.data());
        }
        final list = byId.values.toList(growable: false);
        list.sort((a, b) => a.role.rank.compareTo(b.role.rank));
        return list;
      },
      toJson: (member) => {'id': member.id, ...member.toMap()},
      fromJson: (json) =>
          FarmMember.fromMap(json['id']?.toString() ?? '', json),
    );
  }

  static List<FarmMember> forSite(List<FarmMember> members, String siteId) =>
      members
          .where((member) => member.siteId == siteId && member.active)
          .toList(growable: false);

  /// دور المستخدم في موقع معيّن: المالك أولًا، ثم العضوية.
  static FarmRole? roleOf({
    required String siteOwnerId,
    required String siteId,
    required String? uid,
    required List<FarmMember> members,
  }) {
    if (uid == null) return null;
    if (uid == siteOwnerId) return FarmRole.owner;
    for (final member in members) {
      if (member.siteId == siteId && member.memberUid == uid && member.active) {
        return member.role;
      }
    }
    return null;
  }

  /// شجرة فريق موقع واحد جاهزة للعرض والإسناد.
  static FarmTeamHierarchy hierarchyFor({
    required String siteId,
    required String siteOwnerId,
    required String siteOwnerName,
    required List<FarmMember> members,
  }) {
    final list = forSite(members, siteId)
        .where((member) => member.memberUid != siteOwnerId)
        .toList(growable: false);
    return FarmTeamHierarchy(
      ownerId: siteOwnerId,
      ownerName: siteOwnerName,
      members: list,
    );
  }

  /// إنشاء كود دعوة لدور محدد. لا يمكن دعوة «مالك»؛ الأدوار تنزل درجة واحدة.
  static Future<FarmInvite?> createInvite({
    required String siteId,
    required String siteName,
    required FarmRole role,
    required String ownerId,
    String? parentUid,
  }) async {
    final uid = _uid;
    if (uid == null || role == FarmRole.owner) return null;
    final code = FarmInvite.generateCode();
    final now = DateTime.now();
    final invite = FarmInvite(
      code: code,
      siteId: siteId,
      siteName: siteName,
      ownerId: ownerId,
      role: role,
      invitedByUid: uid,
      invitedByName: currentUserName,
      parentUid: parentUid ?? uid,
      createdAt: now,
      expiresAt: now.add(const Duration(days: FarmInvite.validDays)),
    );
    await OfflineFarmStore.write(
      collection: invitesCollection,
      docId: code,
      type: OfflineOperationType.set,
      data: invite.toMap(),
    );
    return invite;
  }

  /// الانضمام بكود دعوة: يقرأ الدعوة ثم ينشئ عضوية المستخدم تحت صاحب الدعوة.
  static Future<FarmJoinResult> joinWithCode(String rawCode) async {
    final uid = _uid;
    if (uid == null) return const FarmJoinResult.failure(FarmJoinFailure.notSignedIn);
    final code = FarmInvite.normalizeCode(rawCode);
    if (!FarmInvite.isWellFormed(code)) {
      return const FarmJoinResult.failure(FarmJoinFailure.invalidCode);
    }

    FarmInvite invite;
    try {
      final doc = await _collection(invitesCollection).doc(code).get();
      if (!doc.exists) {
        return const FarmJoinResult.failure(FarmJoinFailure.invalidCode);
      }
      invite = FarmInvite.fromMap(doc.id, doc.data() ?? const {});
    } catch (error) {
      debugPrint('تعذر قراءة الدعوة: $error');
      return const FarmJoinResult.failure(FarmJoinFailure.offline);
    }

    if (!invite.isValid(DateTime.now())) {
      return const FarmJoinResult.failure(FarmJoinFailure.expired);
    }
    if (invite.siteId.isEmpty || invite.invitedByUid.isEmpty) {
      return const FarmJoinResult.failure(FarmJoinFailure.invalidCode);
    }

    final docId = FarmMember.docId(invite.siteId, uid);
    try {
      final existing = await _collection(membersCollection).doc(docId).get();
      if (existing.exists && existing.data()?['active'] != false) {
        return const FarmJoinResult.failure(FarmJoinFailure.alreadyMember);
      }
    } catch (_) {
      // لو فشل الفحص بسبب الشبكة نكمل؛ الكتابة نفسها ستكشف المشكلة.
    }

    final member = FarmMember(
      id: docId,
      siteId: invite.siteId,
      ownerId: invite.ownerId.isEmpty ? invite.invitedByUid : invite.ownerId,
      memberUid: uid,
      memberName: currentUserName,
      role: invite.role,
      parentUid: invite.parentUid ?? invite.invitedByUid,
      joinedAt: DateTime.now(),
    );
    try {
      await OfflineFarmStore.write(
        collection: membersCollection,
        docId: docId,
        type: OfflineOperationType.set,
        data: member.toMap(),
      );
    } catch (error) {
      debugPrint('تعذر حفظ العضوية: $error');
      return const FarmJoinResult.failure(FarmJoinFailure.unknown);
    }
    return FarmJoinResult.success(member);
  }

  /// تغيير دور عضو؛ لا يمكن ترقية أحد إلى «مالك» ولا تغيير المالك نفسه.
  static Future<void> updateRole(FarmMember member, FarmRole role) async {
    if (role == FarmRole.owner || member.isOwner) return;
    await OfflineFarmStore.write(
      collection: membersCollection,
      docId: member.id,
      type: OfflineOperationType.update,
      data: {'role': role.name},
    );
  }

  static Future<void> removeMember(FarmMember member) async {
    if (member.isOwner) return;
    await OfflineFarmStore.write(
      collection: membersCollection,
      docId: member.id,
      type: OfflineOperationType.delete,
    );
  }

  /// مشاركة برنامج سمادي مع فريق موقع: نسخة ثابتة من المراحل، فلا يؤثر
  /// تعديل البرنامج الأصلي على ما استلمه العمال.
  static Future<FertilizerProgramShare?> shareProgram({
    required String siteId,
    required String ownerId,
    required String programId,
    required String programName,
    required List<FertilizerStage> stages,
    String crop = '',
    String emoji = '🌱',
    FarmRole audienceRole = FarmRole.supervisor,
  }) async {
    final uid = _uid;
    if (uid == null || stages.isEmpty) return null;
    final reference = _collection(programSharesCollection).doc();
    final share = FertilizerProgramShare(
      id: reference.id,
      siteId: siteId,
      ownerId: ownerId,
      createdByUid: uid,
      createdByName: currentUserName,
      programId: programId,
      programName: programName,
      crop: crop,
      emoji: emoji,
      audienceRole: audienceRole,
      sharedAt: DateTime.now(),
      stages: stages,
    );
    await OfflineFarmStore.write(
      collection: programSharesCollection,
      docId: share.id,
      type: OfflineOperationType.set,
      data: share.toMap(),
    );
    return share;
  }

  static Future<List<FertilizerProgramShare>> loadProgramShares() async {
    final uid = _uid;
    if (uid == null) return const [];
    await OfflineFarmStore.flush();
    return OfflineFarmStore.cachedList<FertilizerProgramShare>(
      key: _sharesCacheKey(uid),
      fetch: () async {
        final snapshot = await _collection(programSharesCollection).get();
        final shares = snapshot.docs
            .map((doc) => FertilizerProgramShare.fromMap(doc.id, doc.data()))
            .where((share) => share.createdByUid == uid || share.ownerId == uid)
            .toList(growable: false);
        shares.sort((a, b) => b.sharedAt.compareTo(a.sharedAt));
        return shares;
      },
      toJson: (share) => {'id': share.id, ...share.toMap()},
      fromJson: (json) =>
          FertilizerProgramShare.fromMap(json['id']?.toString() ?? '', json),
    );
  }

  static Future<void> deleteProgramShare(FertilizerProgramShare share) async {
    await OfflineFarmStore.write(
      collection: programSharesCollection,
      docId: share.id,
      type: OfflineOperationType.delete,
    );
  }

  /// تحويل مراحل برنامج مشترك إلى مهام مسنَدة لعضو (أو للمهندس نفسه)،
  /// وهي الخطوة التي تجعل البرنامج «ينزل» على الهرم.
  static Future<int> distributeProgramTasks({
    required FertilizerProgramShare share,
    required String ownerId,
    String? assignedToUid,
    String? assignedToName,
    DateTime? startFrom,
  }) async {
    final tasks = share.buildTasks(
      ownerId: ownerId,
      assignedToUid: assignedToUid,
      assignedToName: assignedToName,
      assignedByUid: _uid,
      startFrom: startFrom,
    );
    var created = 0;
    for (final task in tasks) {
      final saved = await FarmTaskService.addTask(task);
      if (saved != null) created++;
    }
    return created;
  }

  static Future<void> logFailure(Object error) async {
    debugPrint('تعذر تنفيذ عملية فريق المزرعة: $error');
  }
}

/// نماذج فريق المزرعة الهرمي: الأدوار، الأعضاء، دعوات الانضمام، والبرنامج
/// السمادي المشترك بين المهندس ومن يعمل تحته.
///
/// الطبقة نقية بلا Flutter أو Firebase حتى تُختبر مباشرة وتُستخدم في Firestore
/// والتخزين المحلي بنفس الشكل.
library;

import 'dart:math';

import 'farm_workspace_models.dart';

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String _asText(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

/// دور العضو في المزرعة، مرتّبًا من الأعلى للأسفل (المثلث الهرمي).
enum FarmRole {
  owner('مالك المزرعة', 0, 'صاحب القرار النهائي والمالك لكل البيانات'),
  engineer('مهندس المشروع', 1, 'يضع البرنامج السمادي ويوزّع المهام على الفريق'),
  supervisor('مشرف الحقل', 2, 'يدير العمال وينفّذ المهام ويسلّمها لمن تحته'),
  worker('عامل', 3, 'يستلم مهامه وينفّذها ويعلّمها كمنجزة');

  const FarmRole(this.label, this.rank, this.description);

  final String label;

  /// 0 = أعلى الهرم.
  final int rank;
  final String description;

  static FarmRole fromName(Object? value) {
    final name = value?.toString() ?? '';
    for (final role in FarmRole.values) {
      if (role.name == name) return role;
    }
    return FarmRole.worker;
  }

  /// هل يستطيع هذا الدور دعوة [target]؟ الدعوة تنزل درجة واحدة على الأقل،
  /// ولا يمكن منح دور المالك لأحد.
  bool canInvite(FarmRole target) =>
      target != FarmRole.owner && target.rank > rank;

  /// الأدوار التي يمكن لهذا الدور دعوتها.
  List<FarmRole> get invitableRoles =>
      FarmRole.values.where(canInvite).toList(growable: false);

  /// هل يضع برامج التسميد ويوزّعها؟ المالك والمهندس فقط.
  bool get canShareProgram => rank <= FarmRole.engineer.rank;

  /// هل يرى التكاليف والأرباح؟
  bool get canViewFinance => rank <= FarmRole.engineer.rank;

  /// هل ينشئ المهام ويسندها لغيره؟
  bool get canManageTasks => rank < FarmRole.worker.rank;

  /// هل يرى كل أعضاء المزرعة؟
  bool get canViewTeam => true;
}

/// عضو في فريق مزرعة معيّنة، وله مدير مباشر واحد (أو المالك في القمة).
class FarmMember {
  final String id;
  final String siteId;
  final String ownerId;
  final String memberUid;
  final String memberName;
  final String phone;
  final FarmRole role;
  final String? parentUid;
  final DateTime joinedAt;
  final bool active;

  const FarmMember({
    required this.id,
    required this.siteId,
    required this.ownerId,
    required this.memberUid,
    required this.memberName,
    this.phone = '',
    required this.role,
    this.parentUid,
    required this.joinedAt,
    this.active = true,
  });

  /// معرّف المستند: مزرعة واحدة + مستخدم واحد = عضو واحد.
  static String docId(String siteId, String memberUid) =>
      '${siteId}_$memberUid';

  factory FarmMember.fromMap(String id, Map<String, dynamic> data) => FarmMember(
        id: id,
        siteId: _asText(data['site_id']),
        ownerId: _asText(data['owner_id']),
        memberUid: _asText(data['member_uid']),
        memberName: _asText(data['member_name'], 'عضو'),
        phone: _asText(data['phone']),
        role: FarmRole.fromName(data['role']),
        parentUid: _asText(data['parent_uid']).isEmpty
            ? null
            : _asText(data['parent_uid']),
        joinedAt: _parseDate(data['joined_at']) ?? DateTime.now(),
        active: data['active'] != false,
      );

  Map<String, dynamic> toMap() => {
        'site_id': siteId,
        'owner_id': ownerId,
        'member_uid': memberUid,
        'member_name': memberName,
        'phone': phone,
        'role': role.name,
        'parent_uid': parentUid,
        'joined_at': joinedAt.toIso8601String(),
        'active': active,
      };

  FarmMember copyWith({
    String? memberName,
    String? phone,
    FarmRole? role,
    String? parentUid,
    bool? active,
  }) =>
      FarmMember(
        id: id,
        siteId: siteId,
        ownerId: ownerId,
        memberUid: memberUid,
        memberName: memberName ?? this.memberName,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        parentUid: parentUid ?? this.parentUid,
        joinedAt: joinedAt,
        active: active ?? this.active,
      );

  bool get isOwner => role == FarmRole.owner;

  /// هل هذا العضو مدير مباشر لـ [other]؟
  bool isManagerOf(FarmMember other) => other.parentUid == memberUid;
}

/// دعوة انضمام بكود قصير يشاركه المهندس مع من يعمل معه.
class FarmInvite {
  final String code;
  final String siteId;
  final String siteName;
  final String ownerId;
  final FarmRole role;
  final String invitedByUid;
  final String invitedByName;
  final String? parentUid;
  final DateTime createdAt;
  final DateTime expiresAt;

  const FarmInvite({
    required this.code,
    required this.siteId,
    required this.siteName,
    this.ownerId = '',
    required this.role,
    required this.invitedByUid,
    this.invitedByName = '',
    this.parentUid,
    required this.createdAt,
    required this.expiresAt,
  });

  static const int codeLength = 6;
  static const int validDays = 14;

  /// حروف بلا تشابه بصري (بدون O/0 أو I/1) حتى يُقرأ الكود بسهولة.
  static const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String normalizeCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  static String generateCode({Random? random, int length = codeLength}) {
    final source = random ?? Random.secure();
    final buffer = StringBuffer();
    for (var index = 0; index < length; index++) {
      buffer.write(alphabet[source.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  static bool isWellFormed(String raw) {
    final code = normalizeCode(raw);
    if (code.length != codeLength) return false;
    for (final rune in code.split('')) {
      if (!alphabet.contains(rune)) return false;
    }
    return true;
  }

  factory FarmInvite.fromMap(String code, Map<String, dynamic> data) {
    final createdAt = _parseDate(data['created_at']) ?? DateTime.now();
    final invitedByUid = _asText(data['invited_by_uid']);
    return FarmInvite(
      code: _asText(data['code'], code),
      siteId: _asText(data['site_id']),
      siteName: _asText(data['site_name'], 'مزرعة'),
      ownerId: _asText(data['owner_id'], invitedByUid),
      role: FarmRole.fromName(data['role']),
      invitedByUid: invitedByUid,
      invitedByName: _asText(data['invited_by_name']),
      parentUid: _asText(data['parent_uid']).isEmpty
          ? null
          : _asText(data['parent_uid']),
      createdAt: createdAt,
      expiresAt:
          _parseDate(data['expires_at']) ??
              createdAt.add(const Duration(days: validDays)),
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'site_id': siteId,
        'site_name': siteName,
        'owner_id': ownerId.isEmpty ? invitedByUid : ownerId,
        'role': role.name,
        'invited_by_uid': invitedByUid,
        'invited_by_name': invitedByName,
        'parent_uid': parentUid,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      };

  bool isValid(DateTime now) => now.isBefore(expiresAt);

  /// عدد الأيام المتبقية، أو صفر لو انتهت.
  int daysLeft(DateTime now) {
    if (!isValid(now)) return 0;
    return expiresAt.difference(now).inDays + 1;
  }

  /// نص المشاركة الجاهز (واتساب/رسالة قصيرة).
  String shareText() {
    final roleLabel = role.label;
    return 'انضم لفريق مزرعة «$siteName» في تطبيق نباتي.\n'
        'دورك: $roleLabel.\n'
        'كود الدعوة: $code\n'
        'الكود صالح $validDays يومًا. افتح التطبيق ← فريق المزرعة ← «انضم بكود».';
  }
}

/// مرحلة واحدة في البرنامج السمادي (يوم من بداية البرنامج + العنوان).
class FertilizerStage {
  final int dayFromStart;
  final String title;
  final String notes;

  const FertilizerStage({
    required this.dayFromStart,
    required this.title,
    this.notes = '',
  });

  factory FertilizerStage.fromMap(Map<String, dynamic> data) => FertilizerStage(
        dayFromStart: _asInt(data['day_from_start']),
        title: _asText(data['title'], 'خطوة تسميد'),
        notes: _asText(data['notes']),
      );

  Map<String, dynamic> toMap() => {
        'day_from_start': dayFromStart,
        'title': title,
        'notes': notes,
      };

  static int _asInt(Object? value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

/// برنامج سمادي شاركه المهندس مع فريق مزرعة (نسخة ثابتة وقت المشاركة حتى
/// لا يتغير البرنامج على العمال لو عدّله المهندس في «مزرعتي»).
class FertilizerProgramShare {
  final String id;
  final String siteId;
  final String ownerId;
  final String createdByUid;
  final String createdByName;
  final String programId;
  final String programName;
  final String crop;
  final String emoji;
  final FarmRole audienceRole;
  final DateTime sharedAt;
  final List<FertilizerStage> stages;

  const FertilizerProgramShare({
    required this.id,
    required this.siteId,
    required this.ownerId,
    required this.createdByUid,
    this.createdByName = '',
    this.programId = '',
    required this.programName,
    this.crop = '',
    this.emoji = '🌱',
    this.audienceRole = FarmRole.supervisor,
    required this.sharedAt,
    this.stages = const [],
  });

  factory FertilizerProgramShare.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawStages = data['stages'];
    return FertilizerProgramShare(
      id: id,
      siteId: _asText(data['site_id']),
      ownerId: _asText(data['owner_id']),
      createdByUid: _asText(data['created_by_uid']),
      createdByName: _asText(data['created_by_name']),
      programId: _asText(data['program_id']),
      programName: _asText(data['program_name'], 'برنامج سمادي'),
      crop: _asText(data['crop']),
      emoji: _asText(data['emoji'], '🌱'),
      audienceRole: FarmRole.fromName(data['audience_role']),
      sharedAt: _parseDate(data['shared_at']) ?? DateTime.now(),
      stages: rawStages is List
          ? rawStages
              .whereType<Map>()
              .map((stage) =>
                  FertilizerStage.fromMap(Map<String, dynamic>.from(stage)))
              .toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'site_id': siteId,
        'owner_id': ownerId,
        'created_by_uid': createdByUid,
        'created_by_name': createdByName,
        'program_id': programId,
        'program_name': programName,
        'crop': crop,
        'emoji': emoji,
        'audience_role': audienceRole.name,
        'shared_at': sharedAt.toIso8601String(),
        'stages': stages.map((stage) => stage.toMap()).toList(growable: false),
      };

  int get stageCount => stages.length;

  int? get lastStageDay =>
      stages.isEmpty ? null : stages.map((s) => s.dayFromStart).reduce(max);

  /// تحويل مراحل البرنامج إلى مهام تسميد جاهزة للحفظ، ويمكن إسنادها لعضو
  /// واحد فينزل البرنامج من المهندس إلى المشرف ثم إلى العمال.
  List<FarmTask> buildTasks({
    required String ownerId,
    String? assignedToUid,
    String? assignedToName,
    String? assignedByUid,
    DateTime? startFrom,
    int maxTasks = 40,
  }) {
    if (stages.isEmpty || maxTasks <= 0) return const [];
    final base = startFrom ?? DateTime.now();
    final sorted = List<FertilizerStage>.of(stages)
      ..sort((a, b) => a.dayFromStart.compareTo(b.dayFromStart));
    final members = <String>[
      ownerId,
      if (assignedToUid != null && assignedToUid.isNotEmpty) assignedToUid,
    ];
    return sorted.take(maxTasks).map((stage) {
      final day = DateTime(base.year, base.month, base.day)
          .add(Duration(days: stage.dayFromStart));
      return FarmTask(
        id: '',
        ownerId: ownerId,
        siteId: siteId,
        title: 'تسميد: ${stage.title}',
        notes: stage.notes.isEmpty
            ? 'من برنامج «$programName» — اليوم ${stage.dayFromStart}'
            : '${stage.notes}\nمن برنامج «$programName» — اليوم ${stage.dayFromStart}',
        dueAt: DateTime(day.year, day.month, day.day, 7),
        kind: TaskKind.fertilizing,
        assignedToUid: assignedToUid,
        assignedToName: assignedToName,
        assignedByUid: assignedByUid,
        memberUids: members,
      );
    }).toList(growable: false);
  }
}

/// شجرة الفريق: من فوق لتحت، مع صلاحية كل دور في الإسناد.
class FarmTeamHierarchy {
  final String ownerId;
  final String ownerName;
  final List<FarmMember> members;

  const FarmTeamHierarchy({
    required this.ownerId,
    this.ownerName = '',
    this.members = const [],
  });

  List<FarmMember> get activeMembers =>
      members.where((member) => member.active).toList(growable: false);

  FarmMember? memberByUid(String uid) {
    for (final member in activeMembers) {
      if (member.memberUid == uid) return member;
    }
    return null;
  }

  String nameOf(String uid) {
    if (uid == ownerId) {
      return ownerName.trim().isEmpty ? 'مالك المزرعة' : ownerName.trim();
    }
    return memberByUid(uid)?.memberName ?? 'عضو';
  }

  /// المدير المباشر لعضو، أو `null` لو كان في القمة أو عضوا يتيمًا.
  FarmMember? managerOf(String uid) {
    final member = memberByUid(uid);
    if (member == null || member.parentUid == null) return null;
    return memberByUid(member.parentUid!);
  }

  List<FarmMember> childrenOf(String uid) {
    final children = activeMembers
        .where((member) => member.parentUid == uid)
        .toList(growable: false);
    children.sort((a, b) => a.role.rank.compareTo(b.role.rank));
    return children;
  }

  /// كل من تحت [uid] في الهرم (أبناء وأحفاد...).
  List<FarmMember> descendantsOf(String uid) {
    final result = <FarmMember>[];
    final queue = <String>[uid];
    final seen = <String>{uid};
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final child in childrenOf(current)) {
        if (!seen.add(child.memberUid)) continue;
        result.add(child);
        queue.add(child.memberUid);
      }
    }
    return result;
  }

  /// مستوى العضو: المالك 0، ومن تحته 1 وهكذا. العضو غير المرتبط يُعامل
  /// كالمستوى 1 حتى لا يختفي من العرض.
  int levelOf(String uid) {
    if (uid == ownerId) return 0;
    var level = 1;
    var cursor = memberByUid(uid);
    final seen = <String>{};
    while (cursor != null && cursor.parentUid != null) {
      if (!seen.add(cursor.memberUid)) break;
      if (cursor.parentUid == ownerId) return level;
      final parent = memberByUid(cursor.parentUid!);
      if (parent == null) return level;
      level++;
      cursor = parent;
    }
    return level;
  }

  int get maxLevel {
    var deepest = 1;
    for (final member in activeMembers) {
      final level = levelOf(member.memberUid);
      if (level > deepest) deepest = level;
    }
    return deepest;
  }

  /// أعضاء المستوى المطلوب؛ المستوى 0 هو المالك (ليس عضوًا في القائمة).
  List<FarmMember> membersAtLevel(int level) {
    final list = activeMembers
        .where((member) => levelOf(member.memberUid) == level)
        .toList(growable: false);
    list.sort((a, b) {
      final byRole = a.role.rank.compareTo(b.role.rank);
      return byRole != 0 ? byRole : a.memberName.compareTo(b.memberName);
    });
    return list;
  }

  /// صفوف الهرم من القمة للقاع، جاهزة للرسم.
  List<List<FarmMember>> get levels =>
      [for (var level = 1; level <= maxLevel; level++) membersAtLevel(level)];

  /// سلسلة الإدارة من العضو حتى المالك (بدون العضو نفسه).
  List<FarmMember> chainToOwner(String uid) {
    final chain = <FarmMember>[];
    final seen = <String>{uid};
    var manager = managerOf(uid);
    while (manager != null && seen.add(manager.memberUid)) {
      chain.add(manager);
      manager = managerOf(manager.memberUid);
    }
    return chain;
  }

  /// من يحق له [actorUid] إسناد مهمة له؟ المالك/المهندس لأي دور أدنى،
  /// والمشرف لمن تحته فقط — أي أن المهام تنزل درجة درجة.
  bool canAssign({
    required String actorUid,
    required FarmRole actorRole,
    required String targetUid,
  }) {
    if (targetUid == actorUid) return true;
    final target = memberByUid(targetUid);
    if (target == null) return false;
    if (!actorRole.canManageTasks) return false;
    if (actorRole.rank == FarmRole.owner.rank) return true;
    if (actorRole.rank == FarmRole.engineer.rank) return true;
    // المشرف: subordinates فقط.
    return descendantsOf(actorUid)
        .any((member) => member.memberUid == targetUid);
  }

  List<FarmMember> assignableBy(String actorUid, FarmRole actorRole) {
    if (!actorRole.canManageTasks) return const [];
    if (actorRole.rank <= FarmRole.engineer.rank) return activeMembers;
    return descendantsOf(actorUid);
  }

  /// عدد من تحت عضو معيّن في الهرم (للعرض والتقارير).
  int teamSizeOf(String uid) => descendantsOf(uid).length;
}

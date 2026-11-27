import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/models/farm_team_models.dart';
import 'package:agri_app/models/farm_workspace_models.dart';

void main() {
  group('FarmRole', () {
    test('owner can invite every lower role but never another owner', () {
      expect(FarmRole.owner.canInvite(FarmRole.engineer), isTrue);
      expect(FarmRole.owner.canInvite(FarmRole.supervisor), isTrue);
      expect(FarmRole.owner.canInvite(FarmRole.worker), isTrue);
      expect(FarmRole.owner.canInvite(FarmRole.owner), isFalse);
      expect(FarmRole.owner.invitableRoles.length, 3);
    });

    test('worker cannot invite or manage tasks, but can complete them', () {
      expect(FarmRole.worker.invitableRoles, isEmpty);
      expect(FarmRole.worker.canManageTasks, isFalse);
      expect(FarmRole.worker.canShareProgram, isFalse);
      expect(FarmRole.worker.canViewFinance, isFalse);
    });

    test('only owner and engineer share programs and see finance', () {
      expect(FarmRole.engineer.canShareProgram, isTrue);
      expect(FarmRole.engineer.canViewFinance, isTrue);
      expect(FarmRole.supervisor.canShareProgram, isFalse);
      expect(FarmRole.supervisor.canManageTasks, isTrue);
    });

    test('fromName falls back to worker for unknown values', () {
      expect(FarmRole.fromName('supervisor'), FarmRole.supervisor);
      expect(FarmRole.fromName('hacker'), FarmRole.worker);
      expect(FarmRole.fromName(null), FarmRole.worker);
    });
  });

  group('FarmInvite', () {
    test('codes are normalized, readable and well formed', () {
      final code = FarmInvite.generateCode();
      expect(code.length, FarmInvite.codeLength);
      expect(FarmInvite.isWellFormed(code), isTrue);
      expect(FarmInvite.isWellFormed('ab-cd 12'), isFalse);
      expect(FarmInvite.normalizeCode(' k7m2qp '), 'K7M2QP');
      expect(FarmInvite.isWellFormed('K7M2QP'), isTrue);
      expect(FarmInvite.isWellFormed('K7M2'), isFalse);
      expect(FarmInvite.generateCode().contains(RegExp('[O0I1]')), isFalse);
    });

    test('validity window and remaining days', () {
      final now = DateTime(2026, 11, 27, 10);
      final invite = FarmInvite(
        code: 'ABC123',
        siteId: 'site-1',
        siteName: 'مزرعة النيل',
        role: FarmRole.worker,
        invitedByUid: 'engineer-1',
        createdAt: now,
        expiresAt: now.add(const Duration(days: 14)),
      );
      expect(invite.isValid(now), isTrue);
      expect(invite.isValid(now.add(const Duration(days: 20))), isFalse);
      expect(invite.daysLeft(now), 15);
      expect(invite.daysLeft(now.add(const Duration(days: 30))), 0);
      expect(invite.shareText(), contains('ABC123'));
    });

    test('map round trip keeps owner and role', () {
      final createdAt = DateTime(2026, 11, 20, 9);
      final invite = FarmInvite(
        code: 'ZXCVBN',
        siteId: 'site-1',
        siteName: 'مزرعة',
        ownerId: 'owner-9',
        role: FarmRole.supervisor,
        invitedByUid: 'eng-1',
        invitedByName: 'م. أحمد',
        parentUid: 'eng-1',
        createdAt: createdAt,
        expiresAt: createdAt.add(const Duration(days: 14)),
      );
      final restored = FarmInvite.fromMap('ZXCVBN', invite.toMap());
      expect(restored.ownerId, 'owner-9');
      expect(restored.role, FarmRole.supervisor);
      expect(restored.parentUid, 'eng-1');
      expect(restored.invitedByName, 'م. أحمد');
    });

    test('old invites without owner_id fall back to the inviter', () {
      final restored = FarmInvite.fromMap('AAAAAA', {
        'site_id': 's',
        'site_name': 'مزرعة',
        'role': 'worker',
        'invited_by_uid': 'eng-7',
        'created_at': '2026-11-01T08:00:00.000',
        'expires_at': '2026-11-15T08:00:00.000',
      });
      expect(restored.ownerId, 'eng-7');
    });
  });

  group('FarmMember', () {
    test('doc id and map round trip', () {
      final member = FarmMember(
        id: FarmMember.docId('site-1', 'worker-1'),
        siteId: 'site-1',
        ownerId: 'owner-1',
        memberUid: 'worker-1',
        memberName: 'محمد',
        role: FarmRole.worker,
        parentUid: 'sup-1',
        joinedAt: DateTime(2026, 11, 25),
      );
      expect(member.id, 'site-1_worker-1');
      final restored = FarmMember.fromMap(member.id, member.toMap());
      expect(restored.memberName, 'محمد');
      expect(restored.role, FarmRole.worker);
      expect(restored.parentUid, 'sup-1');
      expect(restored.active, isTrue);
    });

    test('isManagerOf checks the direct parent only', () {
      FarmMember member(String uid, FarmRole role, String? parent) => FarmMember(
            id: uid,
            siteId: 's',
            ownerId: 'o',
            memberUid: uid,
            memberName: uid,
            role: role,
            parentUid: parent,
            joinedAt: DateTime(2026),
          );
      final supervisor = member('sup', FarmRole.supervisor, 'eng');
      expect(supervisor.isManagerOf(member('w1', FarmRole.worker, 'sup')), isTrue);
      expect(supervisor.isManagerOf(member('w2', FarmRole.worker, 'eng')), isFalse);
    });
  });

  group('FarmTeamHierarchy', () {
    final members = [
      FarmMember(
        id: 's_eng',
        siteId: 's',
        ownerId: 'owner',
        memberUid: 'eng',
        memberName: 'المهندس أحمد',
        role: FarmRole.engineer,
        parentUid: 'owner',
        joinedAt: DateTime(2026),
      ),
      FarmMember(
        id: 's_sup',
        siteId: 's',
        ownerId: 'owner',
        memberUid: 'sup',
        memberName: 'المشرف سعيد',
        role: FarmRole.supervisor,
        parentUid: 'eng',
        joinedAt: DateTime(2026),
      ),
      FarmMember(
        id: 's_w1',
        siteId: 's',
        ownerId: 'owner',
        memberUid: 'w1',
        memberName: 'عامل 1',
        role: FarmRole.worker,
        parentUid: 'sup',
        joinedAt: DateTime(2026),
      ),
      FarmMember(
        id: 's_w2',
        siteId: 's',
        ownerId: 'owner',
        memberUid: 'w2',
        memberName: 'عامل 2',
        role: FarmRole.worker,
        parentUid: 'sup',
        joinedAt: DateTime(2026),
      ),
      FarmMember(
        id: 's_w3',
        siteId: 's',
        ownerId: 'owner',
        memberUid: 'w3',
        memberName: 'عامل 3',
        role: FarmRole.worker,
        parentUid: 'eng',
        joinedAt: DateTime(2026),
      ),
    ];
    final hierarchy = FarmTeamHierarchy(
      ownerId: 'owner',
      ownerName: 'المالك',
      members: members,
    );

    test('levels go from the owner down', () {
      expect(hierarchy.levelOf('owner'), 0);
      expect(hierarchy.levelOf('eng'), 1);
      expect(hierarchy.levelOf('sup'), 2);
      expect(hierarchy.levelOf('w1'), 3);
      expect(hierarchy.maxLevel, 3);
      expect(hierarchy.levels.length, 3);
      expect(hierarchy.membersAtLevel(1).single.memberUid, 'eng');
      expect(hierarchy.membersAtLevel(3).length, 2);
      expect(hierarchy.nameOf('owner'), 'المالك');
      expect(hierarchy.nameOf('sup'), 'المشرف سعيد');
    });

    test('descendants and chain to owner', () {
      expect(
        hierarchy.descendantsOf('eng').map((m) => m.memberUid).toSet(),
        {'sup', 'w1', 'w2', 'w3'},
      );
      expect(hierarchy.teamSizeOf('sup'), 2);
      expect(hierarchy.managerOf('w1')?.memberUid, 'sup');
      expect(
        hierarchy.chainToOwner('w1').map((m) => m.memberUid).toList(),
        ['sup', 'eng'],
      );
    });

    test('tasks cascade one level at a time', () {
      expect(
        hierarchy.canAssign(
          actorUid: 'sup',
          actorRole: FarmRole.supervisor,
          targetUid: 'w1',
        ),
        isTrue,
      );
      expect(
        hierarchy.canAssign(
          actorUid: 'sup',
          actorRole: FarmRole.supervisor,
          targetUid: 'w3',
        ),
        isFalse,
      );
      expect(
        hierarchy.canAssign(
          actorUid: 'eng',
          actorRole: FarmRole.engineer,
          targetUid: 'w1',
        ),
        isTrue,
      );
      expect(
        hierarchy.canAssign(
          actorUid: 'w1',
          actorRole: FarmRole.worker,
          targetUid: 'w2',
        ),
        isFalse,
      );
      expect(
        hierarchy.assignableBy('sup', FarmRole.supervisor).length,
        2,
      );
      expect(
        hierarchy.assignableBy('eng', FarmRole.engineer).length,
        members.length,
      );
      expect(hierarchy.assignableBy('w1', FarmRole.worker), isEmpty);
    });

    test('inactive members disappear from the tree', () {
      final withInactive = FarmTeamHierarchy(
        ownerId: 'owner',
        members: [
          ...members.take(3),
          members[3].copyWith(active: false),
        ],
      );
      expect(withInactive.memberByUid('w2'), isNull);
      expect(withInactive.membersAtLevel(3).length, 1);
    });
  });

  group('FertilizerProgramShare', () {
    final stages = [
      const FertilizerStage(dayFromStart: 10, title: 'دفعة يوريا', notes: 'كيس/فدان'),
      const FertilizerStage(dayFromStart: 0, title: 'سماد تأسيسي'),
      const FertilizerStage(dayFromStart: 25, title: 'بوتاسيوم'),
    ];

    test('map round trip and summary values', () {
      final share = FertilizerProgramShare(
        id: 'share-1',
        siteId: 'site-1',
        ownerId: 'owner-1',
        createdByUid: 'eng-1',
        createdByName: 'م. أحمد',
        programId: 'program-1',
        programName: 'برنامج طماطم',
        crop: 'طماطم',
        audienceRole: FarmRole.worker,
        sharedAt: DateTime(2026, 11, 1),
        stages: stages,
      );
      final restored =
          FertilizerProgramShare.fromMap('share-1', share.toMap());
      expect(restored.programName, 'برنامج طماطم');
      expect(restored.stageCount, 3);
      expect(restored.lastStageDay, 25);
      expect(restored.audienceRole, FarmRole.worker);
      expect(restored.stages.first.title, 'دفعة يوريا');
    });

    test('buildTasks creates dated, assigned fertilizing tasks', () {
      final share = FertilizerProgramShare(
        id: 'share-1',
        siteId: 'site-1',
        ownerId: 'owner-1',
        createdByUid: 'eng-1',
        programName: 'برنامج طماطم',
        sharedAt: DateTime(2026, 11, 1),
        stages: stages,
      );
      final tasks = share.buildTasks(
        ownerId: 'owner-1',
        assignedToUid: 'sup-1',
        assignedToName: 'المشرف سعيد',
        assignedByUid: 'eng-1',
        startFrom: DateTime(2026, 11, 20, 15),
      );
      expect(tasks.length, 3);
      expect(tasks.first.title, contains('سماد تأسيسي'));
      expect(tasks.first.dueAt, DateTime(2026, 11, 20, 7));
      expect(tasks[1].dueAt, DateTime(2026, 11, 30, 7));
      expect(tasks[2].dueAt, DateTime(2026, 12, 15, 7));
      expect(tasks.first.kind, TaskKind.fertilizing);
      expect(tasks.first.siteId, 'site-1');
      expect(tasks.first.assignedToUid, 'sup-1');
      expect(tasks.first.assignedToName, 'المشرف سعيد');
      expect(tasks.first.assignedByUid, 'eng-1');
      expect(tasks.first.memberUids, containsAll(['owner-1', 'sup-1']));
      expect(tasks.first.notes, contains('برنامج طماطم'));
      expect(tasks.first.notes, contains('اليوم 0'));
    });

    test('buildTasks respects maxTasks and empty stages', () {
      final share = FertilizerProgramShare(
        id: 's',
        siteId: 'site',
        ownerId: 'owner',
        createdByUid: 'eng',
        programName: 'برنامج',
        sharedAt: DateTime(2026),
        stages: stages,
      );
      expect(share.buildTasks(ownerId: 'o', maxTasks: 1).length, 1);
      expect(share.buildTasks(ownerId: 'o', maxTasks: 0), isEmpty);
      final empty = FertilizerProgramShare(
        id: 's',
        siteId: 'site',
        ownerId: 'owner',
        createdByUid: 'eng',
        programName: 'برنامج',
        sharedAt: DateTime(2026),
      );
      expect(empty.buildTasks(ownerId: 'o'), isEmpty);
      expect(empty.lastStageDay, isNull);
    });
  });
}

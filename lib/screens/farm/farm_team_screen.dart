import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/farm_team_models.dart';
import '../../models/farm_workspace_models.dart';
import '../../models/my_farm_model.dart';
import '../../services/farm_share_service.dart';
import '../../services/farm_site_service.dart';
import '../../services/farm_task_service.dart';
import '../../services/farm_team_service.dart';
import '../../services/my_farm_service.dart';
import 'farm_sites_screen.dart';
import 'farm_tasks_screen.dart';

/// فريق المزرعة الهرمي: مالك ← مهندس ← مشرف ← عامل.
///
/// من هنا يدعو المهندس فريقه بكود، يشارك برنامجه السمادي، ويحوّله لمهام
/// مسنَدة تنزل درجة درجة على الهرم.
class FarmTeamScreen extends StatefulWidget {
  const FarmTeamScreen({super.key});

  @override
  State<FarmTeamScreen> createState() => _FarmTeamScreenState();
}

class _FarmTeamScreenState extends State<FarmTeamScreen> {
  static const Color _green = Color(0xFF047857);

  List<FarmSite> _sites = const [];
  List<FarmMember> _members = const [];
  List<FertilizerProgramShare> _shares = const [];
  List<MyFarmProgram> _programs = const [];
  String? _selectedSiteId;
  bool _loading = true;
  String? _error;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        FarmSiteService.loadSites(),
        FarmTeamService.loadMembers(),
        FarmTeamService.loadProgramShares(),
      ]);
      final sites = results[0] as List<FarmSite>;
      final members = results[1] as List<FarmMember>;
      final shares = results[2] as List<FertilizerProgramShare>;
      var programs = <MyFarmProgram>[];
      final uid = _uid;
      if (uid != null) {
        try {
          programs = await MyFarmService.getUserPrograms(uid)
              .first
              .timeout(const Duration(seconds: 8));
        } catch (_) {
          programs = const [];
        }
      }
      if (!mounted) return;
      setState(() {
        _sites = sites;
        _members = members;
        _shares = shares;
        _programs = programs.where((p) => p.status == 'active').toList();
        _selectedSiteId = (_selectedSiteId != null &&
                sites.any((site) => site.id == _selectedSiteId))
            ? _selectedSiteId
            : (sites.isEmpty ? null : sites.first.id);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل بيانات الفريق. تحقق من الاتصال وأعد المحاولة.';
        _loading = false;
      });
    }
  }

  FarmSite? get _site {
    for (final site in _sites) {
      if (site.id == _selectedSiteId) return site;
    }
    return null;
  }

  FarmRole? get _myRole {
    final site = _site;
    if (site == null) return null;
    return FarmTeamService.roleOf(
      siteOwnerId: site.ownerId,
      siteId: site.id,
      uid: _uid,
      members: _members,
    );
  }

  FarmTeamHierarchy get _hierarchy {
    final site = _site;
    if (site == null) {
      return const FarmTeamHierarchy(ownerId: '');
    }
    return FarmTeamService.hierarchyFor(
      siteId: site.id,
      siteOwnerId: site.ownerId,
      siteOwnerName: site.ownerId == _uid
          ? FarmTeamService.currentUserName
          : _memberName(site.ownerId),
      members: _members,
    );
  }

  String _memberName(String uid) {
    for (final member in _members) {
      if (member.memberUid == uid) return member.memberName;
    }
    return 'مالك المزرعة';
  }

  List<FertilizerProgramShare> get _siteShares => _shares
      .where((share) => share.siteId == _selectedSiteId)
      .toList(growable: false);

  Future<void> _invite() async {
    final site = _site;
    final role = _myRole;
    if (site == null || role == null) return;
    final invitable = role.invitableRoles;
    if (invitable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('دورك لا يسمح بدعوة أعضاء.')),
      );
      return;
    }
    final selectedRole = await showModalBottomSheet<FarmRole>(
      context: context,
      builder: (context) => _RolePickerSheet(
        title: 'دعوة عضو جديد',
        subtitle: 'اختر دور العضو؛ ستظهر دعوته في فريقه تحتك مباشرة.',
        roles: invitable,
        selected: invitable.first,
      ),
    );
    if (selectedRole == null || !mounted) return;
    final invite = await FarmTeamService.createInvite(
      siteId: site.id,
      siteName: site.name,
      ownerId: site.ownerId,
      role: selectedRole,
      parentUid: _uid,
    );
    if (invite == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _InviteCodeDialog(invite: invite),
    );
    await _load();
  }

  Future<void> _join() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الانضمام بكود دعوة'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          maxLength: FarmInvite.codeLength,
          decoration: const InputDecoration(
            labelText: 'كود الدعوة',
            hintText: 'مثال: K7M2QP',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('انضم'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || !mounted) return;
    final result = await FarmTeamService.joinWithCode(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.success) await _load();
  }

  Future<void> _shareProgram(MyFarmProgram program) async {
    final site = _site;
    if (site == null) return;
    final role = _myRole;
    if (role == null || !role.canShareProgram) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مشاركة البرنامج متاحة للمالك والمهندس فقط.')),
      );
      return;
    }
    final audience = await showModalBottomSheet<FarmRole>(
      context: context,
      builder: (context) => _RolePickerSheet(
        title: 'مشاركة البرنامج السمادي',
        subtitle: 'مع من تشارك «${program.templateName}»؟',
        roles: const [FarmRole.supervisor, FarmRole.worker],
        selected: FarmRole.supervisor,
      ),
    );
    if (audience == null || !mounted) return;
    final stages = _stagesFor(program);
    if (stages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا البرنامج لا يحتوي خطوات تسميد.')),
      );
      return;
    }
    final share = await FarmTeamService.shareProgram(
      siteId: site.id,
      ownerId: site.ownerId,
      programId: program.id,
      programName: program.templateName,
      crop: program.sectionName,
      emoji: program.templateEmoji,
      audienceRole: audience,
      stages: stages,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(share == null
            ? 'تعذر مشاركة البرنامج.'
            : 'تمت مشاركة البرنامج مع ${audience.label} (${stages.length} خطوة).'),
      ),
    );
    await _load();
  }

  List<FertilizerStage> _stagesFor(MyFarmProgram program) {
    final tasks = program.tasks;
    final fertilizing = tasks.where((task) {
      final title = (task['title'] ?? '').toString();
      return title.contains('سماد') || title.contains('تسميد');
    }).toList(growable: false);
    final source = fertilizing.isNotEmpty ? fertilizing : tasks;
    final stages = <FertilizerStage>[];
    for (final task in source) {
      final day = task['day_from_start'];
      final dayValue = day is num
          ? day.round()
          : int.tryParse(day?.toString() ?? '') ?? 0;
      final title = (task['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      stages.add(FertilizerStage(
        dayFromStart: dayValue,
        title: title,
        notes: (task['description'] ?? task['notes'] ?? '').toString(),
      ));
    }
    stages.sort((a, b) => a.dayFromStart.compareTo(b.dayFromStart));
    return stages;
  }

  Future<void> _distribute(FertilizerProgramShare share) async {
    final site = _site;
    final myRole = _myRole;
    if (site == null || myRole == null) return;
    final members = _hierarchy.assignableBy(_uid ?? '', myRole);
    final target = await showModalBottomSheet<FarmMember?>(
      context: context,
      builder: (context) => _AssigneeSheet(
        members: members,
        canAssignSelf: true,
        selfName: FarmTeamService.currentUserName,
      ),
    );
    if (!mounted) return;
    final assignTo = target?.memberUid;
    final count = await FarmTeamService.distributeProgramTasks(
      share: share,
      ownerId: site.ownerId,
      assignedToUid: assignTo,
      assignedToName: target?.memberName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(count == 0
            ? 'تعذر إنشاء المهام.'
            : 'تم إنشاء $count مهمة تسميد'
                '${target == null ? ' في مهامك' : ' لـ ${target.memberName}'}'),
        action: SnackBarAction(
          label: 'المهام',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FarmTasksScreen()),
          ),
        ),
      ),
    );
    await FarmTaskService.rescheduleAll();
  }

  Future<void> _memberActions(FarmMember member) async {
    final myRole = _myRole;
    if (myRole == null) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(member.memberName),
              subtitle: Text(
                '${member.role.label} · تحت ${_hierarchy.nameOf(member.parentUid ?? _hierarchy.ownerId)}',
              ),
            ),
            if (myRole.rank <= FarmRole.engineer.rank)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('تغيير الدور'),
                onTap: () async {
                  Navigator.pop(context);
                  final role = await showModalBottomSheet<FarmRole>(
                    context: this.context,
                    builder: (context) => _RolePickerSheet(
                      title: 'دور ${member.memberName}',
                      subtitle: 'الأدوار تنزل درجة واحدة على الأقل من دورك.',
                      roles: myRole.invitableRoles,
                      selected: member.role,
                    ),
                  );
                  if (role == null) return;
                  await FarmTeamService.updateRole(member, role);
                  await _load();
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('إزالة من الفريق',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await FarmTeamService.removeMember(member);
                await _load();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('فريق المزرعة', style: TextStyle(color: Colors.white)),
        backgroundColor: _green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorState()
                : _sites.isEmpty
                    ? _noSitesState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          children: [
                            _siteSelector(),
                            const SizedBox(height: 12),
                            _pyramidCard(isDark),
                            const SizedBox(height: 12),
                            _actionsRow(),
                            const SizedBox(height: 20),
                            _programsSection(isDark),
                            const SizedBox(height: 20),
                            _sharesSection(isDark),
                          ],
                        ),
                      ),
      ),
      floatingActionButton: _sites.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _join,
              backgroundColor: _green,
              icon: const Icon(Icons.group_add),
              label: const Text('انضم بكود'),
            ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 12),
              Text(_error ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );

  Widget _noSitesState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.groups_outlined, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('أضف مزرعة أولًا',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              const Text(
                'الفريق يُبنى حول مزرعة. أضف موقعك وقطعه ثم عُد لتدعو المهندس أو العمال.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FarmSitesScreen()),
                  );
                  await _load();
                },
                icon: const Icon(Icons.add_location_alt),
                label: const Text('إدارة المزارع'),
              ),
            ],
          ),
        ),
      );

  Widget _siteSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final site in _sites)
          ChoiceChip(
            label: Text(site.name),
            selected: site.id == _selectedSiteId,
            selectedColor: _green.withValues(alpha: 0.15),
            onSelected: (_) => setState(() => _selectedSiteId = site.id),
          ),
      ],
    );
  }

  Widget _pyramidCard(bool isDark) {
    final site = _site;
    if (site == null) return const SizedBox.shrink();
    final myRole = _myRole;
    final hierarchy = _hierarchy;
    final ownerName = site.ownerId == _uid
        ? FarmTeamService.currentUserName
        : _memberName(site.ownerId);
    final levels = hierarchy.levels;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF047857), Color(0xFF10B981)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree, color: Colors.white, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      myRole == null
                          ? 'لست عضوًا في هذا الفريق بعد'
                          : 'دورك: ${myRole.label}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (myRole != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${hierarchy.activeMembers.length} عضو',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _pyramidRow(
            [
              _pyramidNode(
                ownerName,
                FarmRole.owner.label,
                isMe: site.ownerId == _uid,
                highlight: true,
              ),
            ],
          ),
          if (levels.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'لا يوجد أعضاء بعد. ادعُ مهندسًا أو مشرفًا بكود، وستنزل المهام عليهم.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          for (var index = 0; index < levels.length; index++) ...[
            const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
            _pyramidRow([
              for (final member in levels[index])
                _pyramidNode(
                  member.memberName,
                  member.role.label,
                  isMe: member.memberUid == _uid,
                  onTap: () => _memberActions(member),
                ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _pyramidRow(List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
      );

  Widget _pyramidNode(
    String name,
    String role, {
    bool isMe = false,
    bool highlight = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFFFDE68A)
              : Colors.white.withValues(alpha: isMe ? 0.28 : 0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? Colors.white : Colors.white.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: TextStyle(
                color: highlight ? const Color(0xFF7C2D12) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Text(
              isMe ? '$role (أنت)' : role,
              style: TextStyle(
                color: highlight
                    ? const Color(0xFF9A3412)
                    : Colors.white.withValues(alpha: 0.8),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsRow() {
    final myRole = _myRole;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: myRole == null || myRole.invitableRoles.isEmpty
                ? null
                : _invite,
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('دعوة عضو'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _join,
            icon: const Icon(Icons.group_add, size: 18),
            label: const Text('انضم بكود'),
          ),
        ),
      ],
    );
  }

  Widget _programsSection(bool isDark) {
    final myRole = _myRole;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'برامجي السمادية',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          'شارك البرنامج مع المشرف أو العامل، ثم وزّعه كمهام تنزل على الهرم.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        if (myRole == null || !myRole.canShareProgram)
          const Text(
            'مشاركة البرنامج متاحة لمالك المزرعة والمهندس.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          )
        else if (_programs.isEmpty)
          const Text(
            'لا توجد برامج نشطة في «مزرعتي». أنشئ برنامجًا أولًا ثم شاركه.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          )
        else
          ..._programs.map((program) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Text(program.templateEmoji,
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            program.templateName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '${program.sectionName} · ${program.tasks.length} خطوة',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'مشاركة مع الفريق',
                      icon: const Icon(Icons.share, color: _green),
                      onPressed: () => _shareProgram(program),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _sharesSection(bool isDark) {
    final shares = _siteShares;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'برامج مشتركة مع الفريق',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (shares.isEmpty)
          const Text(
            'لا يوجد برنامج مشترك بعد.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          )
        else
          ...shares.map((share) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(share.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            share.programName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            share.audienceRole.label,
                            style: const TextStyle(fontSize: 10, color: _green),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${share.stageCount} خطوة'
                      '${share.lastStageDay == null ? '' : ' · حتى اليوم ${share.lastStageDay}'}'
                      ' · شاركه ${share.createdByName}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _green,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () => _distribute(share),
                            icon: const Icon(Icons.playlist_add_check, size: 16),
                            label: const Text('توزيع كمهام',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'مشاركة النص',
                          icon: const Icon(Icons.share, size: 18),
                          onPressed: () => FarmShareService.shareText(
                            'البرنامج السمادي «${share.programName}» '
                            '(${share.stageCount} خطوة) من ${share.createdByName}. '
                            'افتح نباتي ← فريق المزرعة لرؤية التفاصيل.',
                            subject: 'البرنامج السمادي',
                          ),
                        ),
                        IconButton(
                          tooltip: 'حذف المشاركة',
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: share.createdByUid == _uid
                              ? () async {
                                  await FarmTeamService.deleteProgramShare(share);
                                  await _load();
                                }
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}

/// اختيار دور من قائمة محدودة.
class _RolePickerSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<FarmRole> roles;
  final FarmRole selected;

  const _RolePickerSheet({
    required this.title,
    required this.subtitle,
    required this.roles,
    required this.selected,
  });

  @override
  State<_RolePickerSheet> createState() => _RolePickerSheetState();
}

class _RolePickerSheetState extends State<_RolePickerSheet> {
  late FarmRole _role = widget.selected;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ...widget.roles.map((role) => ListTile(
                    onTap: () => setState(() => _role = role),
                    leading: Icon(
                      _role == role
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: const Color(0xFF047857),
                    ),
                    title: Text(role.label),
                    subtitle: Text(role.description,
                        style: const TextStyle(fontSize: 11)),
                    contentPadding: EdgeInsets.zero,
                  )),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF047857)),
                  onPressed: () => Navigator.pop(context, _role),
                  child: const Text('تأكيد'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// عرض كود الدعوة بعد إنشائه مع زر مشاركة.
class _InviteCodeDialog extends StatelessWidget {
  final FarmInvite invite;

  const _InviteCodeDialog({required this.invite});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('كود الدعوة جاهز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              invite.code,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: Color(0xFF047857),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${invite.role.label} في «${invite.siteName}»\n'
              'صالح ${invite.daysLeft(DateTime.now())} يومًا.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          FilledButton.icon(
            onPressed: () => FarmShareService.shareText(
              invite.shareText(),
              subject: 'دعوة لفريق المزرعة',
            ),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('مشاركة الكود'),
          ),
        ],
      ),
    );
  }
}

/// اختيار عضو لإسناد المهام له.
class _AssigneeSheet extends StatelessWidget {
  final List<FarmMember> members;
  final bool canAssignSelf;
  final String selfName;

  const _AssigneeSheet({
    required this.members,
    this.canAssignSelf = false,
    this.selfName = 'أنا',
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'مين هينفّذ المهام؟',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'المهام تنزل درجة واحدة كل مرة: المهندس ← المشرف ← العامل.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFF047857)),
              title: Text(selfName),
              subtitle: const Text('في مهامي أنا'),
              onTap: () => Navigator.pop(context),
            ),
            if (members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'لا يوجد أعضاء تحتك في هذا الفريق. ادعُ مشرفًا أو عاملًا أولًا.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ...members.map((member) => ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF047857).withValues(alpha: 0.1),
                    child: const Icon(Icons.engineering,
                        size: 16, color: Color(0xFF047857)),
                  ),
                  title: Text(member.memberName),
                  subtitle: Text(member.role.label,
                      style: const TextStyle(fontSize: 11)),
                  onTap: () => Navigator.pop(context, member),
                )),
          ],
        ),
      ),
    );
  }
}

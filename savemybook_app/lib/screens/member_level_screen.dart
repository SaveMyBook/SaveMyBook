import 'package:flutter/material.dart';
import '../models/member_level.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';

class MemberLevelScreen extends StatefulWidget {
  const MemberLevelScreen({super.key});

  @override
  State<MemberLevelScreen> createState() => _MemberLevelScreenState();
}

class _MemberLevelScreenState extends State<MemberLevelScreen> {
  final ApiService _api = ApiService();
  MemberLevelInfo _info = MemberLevelInfo.empty;
  bool _isLoading = true;
  int _selectedIndex = 0;

  static const _badgeIcons = [
    Icons.eco_outlined,
    Icons.auto_awesome_outlined,
    Icons.workspace_premium_outlined,
    Icons.diamond_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await _api.fetchMemberLevel();
    if (!mounted) return;

    final currentIndex = info.currentLevel == null
        ? 0
        : info.levels.indexWhere((l) => l.levelId == info.currentLevel!.levelId);

    setState(() {
      _info = info;
      _selectedIndex = currentIndex < 0 ? 0 : currentIndex;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          const AppHeader(title: '會員等級', icon: Icons.workspace_premium_outlined),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView()
                : _info.levels.isEmpty
                    ? const EmptyView(icon: Icons.emoji_events_outlined, message: '尚未設定會員等級制度')
                    : RefreshIndicator(
                        color: c.accent,
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                          children: [
                            _buildBadgeCarousel(c),
                            const SizedBox(height: 24),
                            _buildProgressTrack(c),
                            const SizedBox(height: 28),
                            _buildCurrentCard(c),
                            const SizedBox(height: 12),
                            _buildBenefitsCard(c),
                          ],
                        ),
                      )),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCarousel(AppColors c) {
    final level = _info.levels[_selectedIndex];
    final icon = _badgeIcons[_selectedIndex % _badgeIcons.length];
    final unlocked = _info.points >= level.minPoints;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left_rounded, color: c.iconInactive),
              onPressed: _selectedIndex == 0 ? null : () => setState(() => _selectedIndex -= 1),
            ),
            PopIn(
              triggerKey: _selectedIndex,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 110,
                height: 140,
                decoration: BoxDecoration(
                  color: unlocked ? c.accent.withValues(alpha: 0.12) : c.inputFill,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 52, color: unlocked ? c.accent : c.iconInactive),
                    const SizedBox(height: 12),
                    Text(
                      level.levelName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: unlocked ? c.accent : c.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right_rounded, color: c.iconInactive),
              onPressed: _selectedIndex >= _info.levels.length - 1
                  ? null
                  : () => setState(() => _selectedIndex += 1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_info.levels.length, (i) {
            final active = i == _selectedIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: active ? c.accent : c.iconInactive,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildProgressTrack(AppColors c) {
    final levels = _info.levels;
    final maxPoints = levels.last.minPoints == 0 ? 1 : levels.last.minPoints;
    final progress = (_info.points / maxPoints).clamp(0.0, 1.0);

    return Column(
      children: [
        SizedBox(
          height: 14,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
            Container(
              height: 4,
              decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.toDouble()),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, animated, _) => FractionallySizedBox(
                widthFactor: animated,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: levels.map((l) {
                  final reached = _info.points >= l.minPoints;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: reached ? c.accent : c.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: reached ? c.accent : c.divider, width: 2),
                    ),
                  );
                }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: levels
              .map((l) => Expanded(
                    child: Text(
                      l.levelName,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: c.textSecondary),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCurrentCard(AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '目前等級：${_info.currentLevel?.levelName ?? '尚未評級'}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            '累積點數 ${_info.points} 點（已完成 ${_info.completedOrders} 筆交易）',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          if (_info.nextLevel != null) ...[
            const SizedBox(height: 6),
            Text(
              '再累積 ${_info.pointsToNext} 點即可升級為「${_info.nextLevel!.levelName}」',
              style: const TextStyle(fontSize: 13, color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBenefitsCard(AppColors c) {
    final level = _info.levels[_selectedIndex];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${level.levelName} 權益',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            level.benefits.isEmpty ? '尚未設定此等級的權益說明。' : level.benefits,
            style: TextStyle(fontSize: 13, height: 1.6, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

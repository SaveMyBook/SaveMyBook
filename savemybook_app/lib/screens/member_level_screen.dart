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

/// 每個等級的視覺：漸層底色 + 徽章形狀 + 強調色。
class _LevelStyle {
  final List<Color> gradient;
  final Color accent;
  final IconData icon;

  const _LevelStyle(this.gradient, this.accent, this.icon);
}

class _MemberLevelScreenState extends State<MemberLevelScreen> {
  final ApiService _api = ApiService();
  late final PageController _pageController = PageController(viewportFraction: 0.88);

  MemberLevelInfo _info = MemberLevelInfo.empty;
  bool _isLoading = true;
  int _selectedIndex = 0;

  static const _styles = <_LevelStyle>[
    _LevelStyle([Color(0xFF8D6E52), Color(0xFFC29B76)], Color(0xFF8D6E52), Icons.eco_rounded),
    _LevelStyle([Color(0xFF7B8B97), Color(0xFFB6C4CE)], Color(0xFF5E6E7A), Icons.hexagon_rounded),
    _LevelStyle([Color(0xFFB08427), Color(0xFFE7C46A)], Color(0xFF9A711A), Icons.workspace_premium_rounded),
    _LevelStyle([Color(0xFF5C6BC0), Color(0xFF9FA8DA)], Color(0xFF4A57A8), Icons.auto_awesome_rounded),
    _LevelStyle([Color(0xFF6A3FA0), Color(0xFFB388DD)], Color(0xFF57318A), Icons.diamond_rounded),
    _LevelStyle([Color(0xFF23272E), Color(0xFF5A6270)], Color(0xFF23272E), Icons.stars_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final info = await _api.fetchMemberLevel();
    if (!mounted) return;

    final currentIndex = info.currentLevel == null
        ? 0
        : info.levels.indexWhere((l) => l.levelId == info.currentLevel!.levelId);
    final index = currentIndex < 0 ? 0 : currentIndex;

    setState(() {
      _info = info;
      _selectedIndex = index;
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) _pageController.jumpToPage(index);
    });
  }

  _LevelStyle _styleFor(int index) => _styles[index % _styles.length];

  int get _currentIndex => _info.currentLevel == null
      ? -1
      : _info.levels.indexWhere((l) => l.levelId == _info.currentLevel!.levelId);

  List<String> _benefitsOf(MemberLevel level) {
    final raw = level.benefits.trim();
    if (raw.isEmpty) return const [];
    return raw
        .split(RegExp(r'[\n、;；,，]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: SwitchIn(
        child: _isLoading
            ? Column(
                children: const [
                  AppHeader(title: '會員等級', icon: Icons.workspace_premium_outlined),
                  Expanded(child: LoadingView()),
                ],
              )
            : _info.levels.isEmpty
                ? Column(
                    children: const [
                      AppHeader(title: '會員等級', icon: Icons.workspace_premium_outlined),
                      Expanded(
                        child: EmptyView(
                          icon: Icons.emoji_events_outlined,
                          message: '尚未設定會員等級制度',
                        ),
                      ),
                    ],
                  )
                : _buildContent(c),
      ),
    );
  }

  Widget _buildContent(AppColors c) {
    final style = _styleFor(_selectedIndex);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [style.gradient[1], style.gradient[0]],
          stops: const [0, 1],
        ),
      ),
      child: RefreshIndicator(
        color: style.accent,
        backgroundColor: c.card,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHero(c, style)),
            SliverToBoxAdapter(child: _buildRail(style)),
            SliverToBoxAdapter(child: _buildStatusCards(c, style)),
            SliverToBoxAdapter(child: const SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: c.scaffold,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 40),
                child: _buildBenefits(c, style),
              ),
            ),
            // 內容不夠長時把剩下的視窗補上底色，不然下面會漏出漸層。
            SliverFillRemaining(
              hasScrollBody: false,
              child: ColoredBox(color: c.scaffold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(AppColors c, _LevelStyle style) {
    final level = _info.levels[_selectedIndex];
    final currentIndex = _currentIndex;

    final String status;
    if (currentIndex < 0) {
      status = '尚未評級';
    } else if (_selectedIndex == currentIndex) {
      status = '您目前的級別';
    } else if (_selectedIndex < currentIndex) {
      status = '已解鎖';
    } else {
      status = '尚未解鎖';
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SAVEMYBOOK',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(0, 0.25),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: Text(
                            level.levelName,
                            key: ValueKey(level.levelId),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          status,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildBadge(style, level),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(_LevelStyle style, MemberLevel level) {
    return PopIn(
      triggerKey: level.levelId,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(level.levelId),
        tween: Tween(begin: 0.85, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
        builder: (_, value, child) => Transform.scale(scale: value, child: child),
        child: Container(
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.42),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(style.icon, size: 62, color: Colors.white),
        ),
      ),
    );
  }

  /// Trip 那種一排節點的進度軌，點一下可以跳到該等級。
  Widget _buildRail(_LevelStyle style) {
    final levels = _info.levels;
    final currentIndex = _currentIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          for (var i = 0; i < levels.length; i++) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _pageController.animateToPage(
                i,
                duration: const Duration(milliseconds: 340),
                curve: Curves.easeOutCubic,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _selectedIndex
                      ? Colors.white.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: i == _selectedIndex
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.35),
                    width: i == _selectedIndex ? 2 : 1,
                  ),
                ),
                child: Icon(
                  _styleFor(i).icon,
                  size: 18,
                  color: currentIndex >= 0 && i <= currentIndex
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
            if (i != levels.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  color: currentIndex >= 0 && i < currentIndex
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.28),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// 可左右滑的狀態卡，內容跟著等級走。
  Widget _buildStatusCards(AppColors c, _LevelStyle style) {
    return Column(
      children: [
        const SizedBox(height: 18),
        // 指向卡片的小箭頭，跟 Trip 一樣標出目前看的是哪一級。
        _buildPointer(),
        SizedBox(
          height: 156,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _info.levels.length,
            onPageChanged: (i) => setState(() => _selectedIndex = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _buildStatusCard(c, i),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPointer() {
    final count = _info.levels.length;
    if (count == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const railPadding = 24.0;
        const nodeSize = 38.0;
        final usable = constraints.maxWidth - railPadding * 2;
        final step = count == 1 ? 0.0 : (usable - nodeSize) / (count - 1);
        final centre = railPadding + nodeSize / 2 + step * _selectedIndex;

        return SizedBox(
          height: 10,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: centre - 10,
                child: CustomPaint(
                  size: const Size(20, 10),
                  painter: _CaretPainter(color: AppColors.of(context).card),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(AppColors c, int index) {
    final level = _info.levels[index];
    final style = _styleFor(index);
    final currentIndex = _currentIndex;
    final reached = _info.points >= level.minPoints;

    final Widget body;
    if (index < currentIndex || (currentIndex >= 0 && index == currentIndex && _info.nextLevel == null)) {
      body = Row(
        children: [
          Expanded(
            child: Text(
              index < currentIndex ? '您已高於此級別' : '您已達到最高級別',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.iconInactive),
        ],
      );
    } else {
      final target = level.minPoints == 0 ? 1 : level.minPoints;
      final progress = (_info.points / target).clamp(0.0, 1.0);
      final remaining = (level.minPoints - _info.points).clamp(0, level.minPoints);

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            reached
                ? '已解鎖「${level.levelName}」，繼續交易累積更多點數'
                : '再累積 $remaining 點即可解鎖「${level.levelName}」級別',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedCount(
                value: _info.points.toDouble(),
                decimals: 0,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: style.accent,
                ),
              ),
              Text(
                ' / ${level.minPoints} 點',
                style: TextStyle(fontSize: 14, color: c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: c.inputFill,
                valueColor: AlwaysStoppedAnimation(style.accent),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(child: body),
    );
  }

  Widget _buildBenefits(AppColors c, _LevelStyle style) {
    final level = _info.levels[_selectedIndex];
    final benefits = _benefitsOf(level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${level.levelName}級別獎勵',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(width: 8),
            if (benefits.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: style.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '×${benefits.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: style.accent,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (benefits.isEmpty)
          Text(
            '尚未設定此等級的權益說明。',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          )
        else
          for (var i = 0; i < benefits.length; i++)
            FadeSlideIn(
              index: i,
              offsetY: 12,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: style.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.card_giftcard_rounded, size: 20, color: style.accent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        benefits[i],
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.cardAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.insights_rounded, size: 20, color: c.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '目前累積 ${_info.points} 點，已完成 ${_info.completedOrders} 筆交易',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CaretPainter extends CustomPainter {
  final Color color;

  _CaretPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CaretPainter oldDelegate) => oldDelegate.color != color;
}

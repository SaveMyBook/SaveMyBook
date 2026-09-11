import 'package:flutter/material.dart';
import '../models/member_level.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/level_style.dart';
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
  late final PageController _pageController = PageController(viewportFraction: _viewportFraction);

  MemberLevelInfo _info = MemberLevelInfo.empty;
  bool _isLoading = true;
  int _selectedIndex = 0;

  static const _viewportFraction = 0.92;
  static const _pageInset = 4.0;
  static const _railPadding = 34.0;
  static const _nodeSize = 38.0;
  static const _caretHalf = 10.0;
  static const _cardRadius = 20.0;


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

  LevelStyle _styleFor(int index) => LevelStyle.at(index);

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

  Widget _buildHero(AppColors c, LevelStyle style) {
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

  Widget _buildBadge(LevelStyle style, MemberLevel level) {
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
  Widget _buildRail(LevelStyle style) {
    final levels = _info.levels;
    final currentIndex = _currentIndex;

    return Padding(
      // 內縮量刻意跟指標的安全範圍對齊，讓指標真的能指到節點而不必被夾住。
      padding: const EdgeInsets.symmetric(horizontal: _railPadding),
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
                width: _nodeSize,
                height: _nodeSize,
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
  Widget _buildStatusCards(AppColors c, LevelStyle style) {
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
        final usable = constraints.maxWidth - _railPadding * 2;
        final step = count == 1 ? 0.0 : (usable - _nodeSize) / (count - 1);
        final nodeCentre = _railPadding + _nodeSize / 2 + step * _selectedIndex;

        // 卡片是 viewportFraction 0.92 的 PageView，左右各再縮排 _pageInset。
        // 安全範圍還要扣掉卡片本身的圓角，不然指標會壓在圓弧上懸空。
        final cardLeft = constraints.maxWidth * ((1 - _viewportFraction) / 2) + _pageInset;
        final cardRight = constraints.maxWidth * (1 - (1 - _viewportFraction) / 2) - _pageInset;
        final safeLeft = cardLeft + _cardRadius + _caretHalf;
        final safeRight = cardRight - _cardRadius - _caretHalf;

        final centre = safeRight <= safeLeft
            ? (cardLeft + cardRight) / 2
            : nodeCentre.clamp(safeLeft, safeRight).toDouble();

        return SizedBox(
          height: 10,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: centre - _caretHalf,
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
      // 進度以「這一級的區間」計算：從目前等級門檻走到下一級門檻。
      // 直接拿總點數除以門檻的話，等級越高會一直看起來快滿了。
      final floor = index == 0 ? 0 : _info.levels[index - 1].minPoints;
      final span = level.minPoints - floor;
      final walked = (_info.points - floor).clamp(0, span <= 0 ? 1 : span);
      final progress = span <= 0 ? 1.0 : (walked / span).clamp(0.0, 1.0).toDouble();
      final remaining = (level.minPoints - _info.points).clamp(0, level.minPoints);

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reached
                      ? '已解鎖「${level.levelName}」'
                      : '再 $remaining 點解鎖「${level.levelName}」',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: style.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: style.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProgressTrack(
            progress: progress,
            color: style.accent,
            track: c.inputFill,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$floor',
                style: TextStyle(fontSize: 11, color: c.textHint),
              ),
              const Spacer(),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${_info.points}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: style.accent,
                      ),
                    ),
                    TextSpan(
                      text: ' / ${level.minPoints} 點',
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${level.minPoints}',
                style: TextStyle(fontSize: 11, color: c.textHint),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(_cardRadius),
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

  Widget _buildBenefits(AppColors c, LevelStyle style) {
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

/// 會員等級用的進度條：比預設的 LinearProgressIndicator 粗，
/// 末端有一顆光點標出「你現在在這裡」，一眼就看得出走到哪。
class _ProgressTrack extends StatelessWidget {
  final double progress;
  final Color color;
  final Color track;
  final double height;

  const _ProgressTrack({
    required this.progress,
    required this.color,
    required this.track,
    this.height = 12,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final filled = (width * value).clamp(0.0, width);

          return SizedBox(
            height: height + 6,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: track,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
                Container(
                  width: filled,
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.75), color],
                    ),
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
                if (value > 0.02)
                  Positioned(
                    left: (filled - (height + 6) / 2).clamp(0.0, width - (height + 6)),
                    child: Container(
                      width: height + 6,
                      height: height + 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

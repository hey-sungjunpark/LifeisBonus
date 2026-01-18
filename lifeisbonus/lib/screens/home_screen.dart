import 'package:flutter/material.dart';

import 'placeholder_screen.dart';
import 'record_screen.dart';
import 'plan_screen.dart';
import 'message_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _HomeBody(),
      const RecordScreen(),
      const PlanScreen(),
      const MessageScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FB),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: _HomeBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        children: const [
          _TodayBonusCard(),
          SizedBox(height: 16),
          _RemainingBonusCard(),
          SizedBox(height: 16),
          _LifeJourneyCard(),
          SizedBox(height: 16),
          _PeopleCard(),
          SizedBox(height: 90),
        ],
      ),
    );
  }
}

class _TodayBonusCard extends StatelessWidget {
  const _TodayBonusCard();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final weekday = weekdays[now.weekday - 1];
    final dateLabel = '${now.year}년 ${now.month}월 ${now.day}일 $weekday';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFB356FF),
            Color(0xFFFF4FA6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 6),
              Text(
                '오늘의 보너스 게임',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '매일은 소중한 선물입니다. 오늘도 즐겁게 보내세요!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              dateLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemainingBonusCard extends StatelessWidget {
  const _RemainingBonusCard();

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      title: '남은 보너스 게임',
      leading: Icons.calendar_today_rounded,
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(child: _AgePicker(label: '현재 나이', value: '28')),
              SizedBox(width: 14),
              Expanded(child: _AgePicker(label: '목표 나이', value: '80')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _StatItem(label: '지난 년수', value: '28', color: Color(0xFFB356FF)),
              _StatItem(label: '남은 년수', value: '52', color: Color(0xFFFF4FA6)),
              _StatItem(label: '진행률', value: '35%', color: Color(0xFF6A6A6A)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              Text(
                '인생 진행률',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7A7A7A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              Text(
                '35%',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7A7A7A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E1EE),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: 0.35,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB356FF), Color(0xFFFF4FA6)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Text(
                '출생',
                style: TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
              ),
              Spacer(),
              _CurrentAgeBadge(label: '현재 28세'),
              Spacer(),
              Text(
                '80세',
                style: TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LifeJourneyCard extends StatelessWidget {
  const _LifeJourneyCard();

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      title: '인생의 여정',
      leading: Icons.workspace_premium_rounded,
      child: Column(
        children: [
          const SizedBox(height: 6),
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Color(0xFFE6E1EE), width: 10),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.favorite_rounded, color: Color(0xFFFF4FA6)),
                  SizedBox(height: 6),
                  Text(
                    '28',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB356FF),
                    ),
                  ),
                  Text(
                    '10,220일 살아서\n+18,980일\n남았어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Color(0xFF9B9B9B)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _StageRow(
            icon: Icons.toys_rounded,
            label: '유년기',
            range: '0-10세',
            active: true,
          ),
          const SizedBox(height: 10),
          const _StageRow(
            icon: Icons.menu_book_rounded,
            label: '청소년기',
            range: '11-20세',
            active: true,
          ),
          const SizedBox(height: 10),
          const _StageRow(
            icon: Icons.rocket_launch_rounded,
            label: '청년기',
            range: '21-35세',
            active: false,
            highlight: true,
          ),
          const SizedBox(height: 10),
          const _StageRow(
            icon: Icons.work_rounded,
            label: '중년기',
            range: '36-60세',
            active: false,
          ),
          const SizedBox(height: 10),
          const _StageRow(
            icon: Icons.filter_vintage_rounded,
            label: '노년기',
            range: '61세+',
            active: false,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F0FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '현재 28세로 인생의 35%를 경험했습니다\n앞으로 52년의 소중한 시간이 남아있습니다 ✨',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF8A8A8A)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleCard extends StatelessWidget {
  const _PeopleCard();

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      title: '같은 추억을 가진 사람들',
      leading: Icons.group_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFFF3E6FF), Color(0xFFFDE9F6)],
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          const Text(
            '127명',
            style: TextStyle(
              fontSize: 22,
              color: Color(0xFFB356FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '나와 비슷한 기록과 계획을 가진 사람들이 있습니다',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: const [
                _PeopleRow(label: '같은 학교 출신', value: '23명'),
                SizedBox(height: 8),
                _PeopleRow(label: '같은 동네 거주', value: '15명'),
                SizedBox(height: 8),
                _PeopleRow(label: '비슷한 목표', value: '89명'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [Color(0xFFB356FF), Color(0xFFFF4FA6)],
                ),
              ),
              child: Center(
                child: Text(
                  '프리미엄으로 연결하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.title,
    required this.leading,
    required this.child,
    this.gradient,
  });

  final String title;
  final IconData leading;
  final Widget child;
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(leading, color: const Color(0xFFB356FF), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4C4C4C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AgePicker extends StatelessWidget {
  const _AgePicker({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF7A7A7A),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3E3E3)),
          ),
          child: Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
        ),
      ],
    );
  }
}

class _CurrentAgeBadge extends StatelessWidget {
  const _CurrentAgeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE7D6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFFFF7A3D),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.icon,
    required this.label,
    required this.range,
    required this.active,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String range;
  final bool active;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final borderColor = highlight ? const Color(0xFFC8A6FF) : Colors.transparent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFF7F0FF) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF8A8A8A)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: highlight ? const Color(0xFF8E5BFF) : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                range,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
              ),
              const Spacer(),
              if (active)
                const Icon(Icons.check_circle, color: Color(0xFF27C068), size: 16)
              else if (highlight)
                const Icon(Icons.circle, color: Color(0xFFB356FF), size: 10),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5E5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: highlight ? 0.62 : (active ? 1 : 0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: highlight
                        ? const LinearGradient(
                            colors: [Color(0xFFB356FF), Color(0xFFFF4FA6)],
                          )
                        : null,
                    color: active ? const Color(0xFF27C068) : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleRow extends StatelessWidget {
  const _PeopleRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E6FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8E5BFF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, -8),
          ),
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            label: '홈',
            icon: Icons.home_rounded,
            active: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            label: '기록',
            icon: Icons.menu_book_rounded,
            active: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _NavItem(
            label: '계획',
            icon: Icons.blur_circular_rounded,
            active: currentIndex == 2,
            onTap: () => onTap(2),
          ),
          _NavItem(
            label: '쪽지',
            icon: Icons.chat_bubble_outline_rounded,
            active: currentIndex == 3,
            onTap: () => onTap(3),
          ),
          _NavItem(
            label: '설정',
            icon: Icons.settings_rounded,
            active: currentIndex == 4,
            onTap: () => onTap(4),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    this.active = false,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFFF7A3D) : const Color(0xFFB0B0B0);
    final bgColor = active ? const Color(0xFFFFF0E6) : Colors.transparent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

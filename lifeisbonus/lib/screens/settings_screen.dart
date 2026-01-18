import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _alertsEnabled = true;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Text(
            '설정',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF7A3D),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '앱 설정과 계정 정보를 관리하세요',
            style: TextStyle(fontSize: 12, color: Color(0xFF9B9B9B)),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: Color(0xFFFFE3D3),
                  child: Text(
                    '김',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB356FF),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '김보너스',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '보너스 게임 28년차',
                        style: TextStyle(fontSize: 11, color: Color(0xFF8A8A8A)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '무료 멤버',
                        style: TextStyle(fontSize: 11, color: Color(0xFF8A8A8A)),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    '편집',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A7A7A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(title: '계정'),
          _SettingsCard(
            child: Column(
              children: const [
                _SettingRow(
                  icon: Icons.person_outline,
                  label: '프로필 설정',
                ),
                Divider(height: 1),
                _SettingRow(
                  icon: Icons.workspace_premium_rounded,
                  label: '프리미엄 구독',
                  trailing: _Badge(label: '무료'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(title: '앱 설정'),
          _SettingsCard(
            child: Column(
              children: [
                _SettingToggleRow(
                  icon: Icons.notifications_none_rounded,
                  label: '알림 설정',
                  value: _alertsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _alertsEnabled = value;
                    });
                  },
                ),
                const Divider(height: 1),
                _SettingToggleRow(
                  icon: Icons.dark_mode_outlined,
                  label: '다크 모드',
                  value: _darkMode,
                  onChanged: (value) {
                    setState(() {
                      _darkMode = value;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(title: '지원'),
          _SettingsCard(
            child: Column(
              children: const [
                _SettingRow(
                  icon: Icons.help_outline_rounded,
                  label: '도움말',
                ),
                Divider(height: 1),
                _SettingRow(
                  icon: Icons.privacy_tip_outlined,
                  label: '개인정보 처리방침',
                ),
                Divider(height: 1),
                _SettingRow(
                  icon: Icons.description_outlined,
                  label: '서비스 이용약관',
                ),
                Divider(height: 1),
                _SettingRow(
                  icon: Icons.support_agent_rounded,
                  label: '고객센터',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: const [
              Text(
                '인생은 보너스',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
              ),
              SizedBox(height: 4),
              Text(
                '버전 1.0.0',
                style: TextStyle(fontSize: 11, color: Color(0xFFB0B0B0)),
              ),
              SizedBox(height: 4),
              Text(
                '© 2024 Life Bonus. All rights reserved.',
                style: TextStyle(fontSize: 10, color: Color(0xFFB0B0B0)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              side: const BorderSide(color: Color(0xFFFFD4D4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.logout, color: Color(0xFFFF6B6B)),
            label: const Text(
              '로그아웃',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9B9B9B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _IconBubble(icon: icon),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          trailing ?? const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
        ],
      ),
    );
  }
}

class _SettingToggleRow extends StatelessWidget {
  const _SettingToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _IconBubble(icon: icon),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFF7A3D),
          ),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F4F4),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: Color(0xFF8A8A8A)),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF8E5BFF),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

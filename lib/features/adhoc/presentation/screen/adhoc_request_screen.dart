import 'package:flutter/material.dart';

import 'add_adhoc_request_screen.dart';

class AdhocRequestScreen extends StatefulWidget {
  const AdhocRequestScreen({super.key});

  @override
  State<AdhocRequestScreen> createState() => _AdhocRequestScreenState();
}

class _AdhocRequestScreenState extends State<AdhocRequestScreen> {
  static const _green = Color(0xFF1A6B3C);
  static const _loginGreen = Color(0xFF3E9B73);
  static const _logoutMaroon = Color(0xFFB40D1A);
  static const _bg = Color(0xFFF5F5F4);

  final Set<int> _expanded = {};

  final List<_AdhocItem> _items = const [
    _AdhocItem(
      dateLabel: '9th Mar, Monday',
      isLogin: true,
      time: '2:03 AM',
      status: 'Scheduled',
    ),
    _AdhocItem(
      dateLabel: '9th Mar, Monday',
      isLogin: false,
      time: '2:03 AM',
      status: 'Scheduled',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _green),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ADHOC Request',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _green,
            fontFamily: 'Manrope',
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF444444),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(Icons.filter_list_rounded, size: 18),
              label: const Text(
                'Filter',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Manrope'),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildAddButton(context),
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'No ADHOC requests found.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
            fontFamily: 'Manrope',
          ),
        ),
      );
    }

    String? currentGroup;
    final widgets = <Widget>[];

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.dateLabel != currentGroup) {
        currentGroup = item.dateLabel;
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 6));
        widgets.add(_buildDateLabel(item.dateLabel));
        widgets.add(const SizedBox(height: 12));
      } else {
        widgets.add(const SizedBox(height: 10));
      }
      widgets.add(_buildCard(i, item));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  Widget _buildDateLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF333333),
        fontFamily: 'Manrope',
      ),
    );
  }

  Widget _buildCard(int index, _AdhocItem item) {
    final accent = item.isLogin ? _loginGreen : _logoutMaroon;
    final tagBg =
        item.isLogin ? const Color(0xFFE8F5EE) : const Color(0xFFFFF0EE);
    final icon = item.isLogin ? Icons.login : Icons.logout;
    final label = item.isLogin ? 'Login' : 'Logout';
    final isExpanded = _expanded.contains(index);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.transparent,
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expanded.remove(index);
            } else {
              _expanded.add(index);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: accent, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: accent,
                      fontFamily: 'Manrope',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tagBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.time,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accent,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF596064),
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: 32),
                  const Icon(Icons.access_time,
                      size: 14, color: Color(0xFF596064)),
                  const SizedBox(width: 6),
                  Text(
                    item.status,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF596064),
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Manrope',
                    ),
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 14),
                Container(height: 1, color: const Color(0xFFE8E8E8)),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'ADHOC request details will appear here.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF596064),
                      height: 1.35,
                      fontFamily: 'Manrope',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddAdhocRequestScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text(
              'Add ADHOC',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Manrope',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdhocItem {
  const _AdhocItem({
    required this.dateLabel,
    required this.isLogin,
    required this.time,
    required this.status,
  });

  final String dateLabel;
  final bool isLogin;
  final String time;
  final String status;
}

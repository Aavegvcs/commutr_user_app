import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/features/adhoc/bloc/adhoc_bloc.dart';
import 'package:commutr_main/features/adhoc/bloc/adhoc_event.dart';
import 'package:commutr_main/features/adhoc/bloc/adhoc_state.dart';
import 'package:commutr_main/features/adhoc/data/model/adhoc_list_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'add_adhoc_request_screen.dart';

class AdhocRequestScreen extends StatelessWidget {
  final int empId;

  const AdhocRequestScreen({super.key, required this.empId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdhocBloc>(
      create: (_) => sl<AdhocBloc>()..add(FetchAdhocList(empId: empId)),
      child: _AdhocRequestView(empId: empId),
    );
  }
}

class _AdhocRequestView extends StatefulWidget {
  final int empId;

  const _AdhocRequestView({required this.empId});

  @override
  State<_AdhocRequestView> createState() => _AdhocRequestViewState();
}

class _AdhocRequestViewState extends State<_AdhocRequestView> {
  static const _green = Color(0xFF1A6B3C);
  static const _loginGreen = Color(0xFF3E9B73);
  static const _logoutMaroon = Color(0xFFB40D1A);
  static const _bg = Color(0xFFF5F5F4);

  final Set<int> _expanded = {};
  List<AdhocRequestItem> _lastItems = [];

  void _refresh() {
    context.read<AdhocBloc>().add(FetchAdhocList(empId: widget.empId));
  }

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
      body: BlocConsumer<AdhocBloc, AdhocState>(
        listener: (context, state) {
          if (state is AdhocCancelSuccess) {
            _showCancelSuccessDialog();
          } else if (state is AdhocCancelError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is AdhocListLoading) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(_green),
              ),
            );
          }
          if (state is AdhocListError) {
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              color: _green,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                              fontFamily: 'Manrope',
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _refresh,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _green,
                              side: const BorderSide(color: Color(0xFFB8DEC9)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text('Retry',
                                style: TextStyle(fontFamily: 'Manrope')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          final items = state is AdhocListLoaded
              ? state.items
              : state is AdhocCancelling
                  ? _lastItems
                  : <AdhocRequestItem>[];
          if (state is AdhocListLoaded) _lastItems = state.items;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            color: _green,
            child: _buildBody(items),
          );
        },
      ),
      bottomNavigationBar: _buildAddButton(context),
    );
  }

  Widget _buildBody(List<AdhocRequestItem> items) {
    if (items.isEmpty) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(
            child: Text(
              'No ADHOC requests found.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
                fontFamily: 'Manrope',
              ),
            ),
          ),
        ),
      );
    }

    String? currentGroup;
    final widgets = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.requestDate != currentGroup) {
        currentGroup = item.requestDate;
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 6));
        widgets.add(_buildDateLabel(item.requestDate));
        widgets.add(const SizedBox(height: 12));
      } else {
        widgets.add(const SizedBox(height: 10));
      }
      widgets.add(_buildCard(i, item));
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
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

  Widget _buildCard(int index, AdhocRequestItem item) {
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
                      item.shiftTime,
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showCancelDialog(item),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB40D1A),
                          side: const BorderSide(color: Color(0xFFB40D1A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Manrope',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          'Scheduled',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Manrope',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(AdhocRequestItem item) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel ADHOC Request',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'Manrope',
          ),
        ),
        content: Text(
          'Are you sure you want to cancel the ${item.isLogin ? "Login" : "Logout"} request for ${item.requestDate}?',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF596064),
            fontFamily: 'Manrope',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'No',
              style: TextStyle(
                color: Color(0xFF596064),
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(
                color: Color(0xFFB40D1A),
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        context.read<AdhocBloc>().add(
              CancelAdhocRequest(reqId: item.reqId, empId: item.empId),
            );
      }
    });
  }

  void _showCancelSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: _green, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Request Cancelled',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Manrope',
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your ADHOC request has been cancelled successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF596064),
                fontFamily: 'Manrope',
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _refresh();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Manrope',
                ),
              ),
            ),
          ),
        ],
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
              ).then((_) => _refresh());
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

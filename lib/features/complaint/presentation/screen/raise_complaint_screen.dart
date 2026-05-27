import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../bloc/complaint_bloc.dart';
import '../../bloc/complaint_event.dart';
import '../../bloc/complaint_state.dart';
import '../../data/model/complaint_response.dart';
import 'complaint_detail_screen.dart';
import 'create_complaint_screen.dart';

class RaiseComplaintScreen extends StatelessWidget {
  const RaiseComplaintScreen({super.key, required this.empId});

  final int empId;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final initialFrom = DateTime(now.year, now.month - 1, now.day);

    return BlocProvider<ComplaintBloc>(
      create: (_) => sl<ComplaintBloc>()
        ..add(FetchComplaintList(
          empId: empId,
          fromDate: _fmtApi(initialFrom),
          toDate: _fmtApi(now),
        )),
      child: _RaiseComplaintView(empId: empId, initialFrom: initialFrom, initialTo: now),
    );
  }
}

class _RaiseComplaintView extends StatefulWidget {
  const _RaiseComplaintView({
    required this.empId,
    required this.initialFrom,
    required this.initialTo,
  });

  final int empId;
  final DateTime initialFrom;
  final DateTime initialTo;

  @override
  State<_RaiseComplaintView> createState() => _RaiseComplaintViewState();
}

class _RaiseComplaintViewState extends State<_RaiseComplaintView> {
  late DateTime _fromDate;
  late DateTime _toDate;

  @override
  void initState() {
    super.initState();
    _fromDate = widget.initialFrom;
    _toDate = widget.initialTo;
  }

  void _openCreateComplaint() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CreateComplaintScreen(empId: widget.empId),
      ),
    ).then((_) {
      if (mounted) _fetch();
    });
  }

  void _fetch() {
    context.read<ComplaintBloc>().add(FetchComplaintList(
          empId: widget.empId,
          fromDate: _fmtApi(_fromDate),
          toDate: _fmtApi(_toDate),
        ));
  }

  void _openFilter() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        fromDate: _fromDate,
        toDate: _toDate,
        onApply: (from, to) {
          setState(() {
            _fromDate = from;
            _toDate = to;
          });
          _fetch();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A6B3C), size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Raise Complaint',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A6B3C),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openFilter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Filter',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.filter_alt_outlined,
                        size: 16, color: Color(0xFF6B7280)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          BlocConsumer<ComplaintBloc, ComplaintState>(
            listener: (context, state) {
              if (state is ComplaintListError) {
                AppSnackbar.error(context, state.message);
              }
            },
            builder: (context, state) {
              if (state is ComplaintListLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF1A6B3C)),
                  ),
                );
              }
              if (state is ComplaintListError) {
                return _ErrorBody(message: state.message);
              }
              final items = state is ComplaintListLoaded
                  ? state.items
                  : <ComplaintListItem>[];
              return _ComplaintBody(items: items, empId: widget.empId);
            },
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F4),
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: _AddComplaintButton(onTap: _openCreateComplaint),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtApi(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

String _fmtDisplay(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.fromDate,
    required this.toDate,
    required this.onApply,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final void Function(DateTime from, DateTime to) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _from = widget.fromDate;
    _to = widget.toDate;
  }

  Widget _pickerTheme(BuildContext ctx, Widget? child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1A6B3C)),
        ),
        child: child!,
      );

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: _to,
      builder: _pickerTheme,
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime.now(),
      builder: _pickerTheme,
    );
    if (picked != null) setState(() => _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back,
                    color: Color(0xFF1A6B3C), size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'Filter',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A6B3C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Date pickers row
          Row(
            children: [
              Expanded(
                child: _FilterDateField(
                  label: 'FROM DATE',
                  date: _from,
                  onTap: _pickFrom,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FilterDateField(
                  label: 'TO DATE',
                  date: _to,
                  onTap: _pickTo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Apply button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onApply(_from, _to);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A5C38),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                'Apply',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDateField extends StatelessWidget {
  const _FilterDateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _fmtDisplay(date),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                const Icon(Icons.calendar_month_outlined,
                    size: 18, color: Color(0xFF6B7280)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFBA1A1A)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplaintBody extends StatelessWidget {
  const _ComplaintBody({required this.items, required this.empId});

  final List<ComplaintListItem> items;
  final int empId;

  int get _activeCount =>
      items.where((i) => i.complainStatus.toLowerCase() == 'open').length;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(activeCount: _activeCount),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const _EmptyState()
          else
            ...items.map((item) => _ComplaintCard(item: item, empId: empId)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Recent Cases',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF191C1E),
          ),
        ),
        if (activeCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5EE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$activeCount Active',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A6B3C),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFB0BEC5)),
            SizedBox(height: 16),
            Text(
              'No Complaints Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap "Add Complaint" to raise a new case.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.item, required this.empId});

  final ComplaintListItem item;
  final int empId;

  Color get _statusColor {
    final s = item.complainStatus.toLowerCase();
    if (s == 'open') return const Color(0xFF1A6B3C);
    if (s == 'closed' || s == 'resolved') return const Color(0xFF2563EB);
    return const Color(0xFF888888);
  }

  Color get _statusBg {
    final s = item.complainStatus.toLowerCase();
    if (s == 'open') return const Color(0xFFE8F5EE);
    if (s == 'closed' || s == 'resolved') return const Color(0xFFEFF6FF);
    return const Color(0xFFF3F4F6);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFF1A6B3C), width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'ID: ${item.complaintId}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF737785),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.complainDate.isNotEmpty) ...[
                  const Text(
                    '  •  ',
                    style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                  ),
                  Text(
                    item.complainDate,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF737785),
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.complainStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.complaintType,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            if (item.complainMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Message:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.complainMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF555555),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ComplaintDetailScreen(
                        empId: empId,
                        complaintId: item.complaintId,
                        complaintType: item.complaintType,
                      ),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A6B3C),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: Color(0xFF1A6B3C)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

class _AddComplaintButton extends StatelessWidget {
  const _AddComplaintButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF1A5C38),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'Add Complaint',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../bloc/complaint_bloc.dart';
import '../../bloc/complaint_event.dart';
import '../../bloc/complaint_state.dart';
import '../../data/model/complaint_response.dart';

class ComplaintDetailScreen extends StatelessWidget {
  const ComplaintDetailScreen({
    super.key,
    required this.empId,
    required this.complaintId,
    required this.complaintType,
  });

  final int empId;
  final int complaintId;
  final String complaintType;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ComplaintBloc>(
      create: (_) => sl<ComplaintBloc>()
        ..add(FetchComplaintDetail(empId: empId, complaintId: complaintId)),
      child: _ComplaintDetailView(complaintType: complaintType),
    );
  }
}

class _ComplaintDetailView extends StatelessWidget {
  const _ComplaintDetailView({required this.complaintType});

  final String complaintType;

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
          'Complaint Detail',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A6B3C),
          ),
        ),
      ),
      body: BlocConsumer<ComplaintBloc, ComplaintState>(
        listener: (context, state) {
          if (state is ComplaintDetailError) {
            AppSnackbar.error(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is ComplaintDetailLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A6B3C)),
              ),
            );
          }
          if (state is ComplaintDetailError) {
            return _ErrorBody(message: state.message);
          }
          if (state is ComplaintDetailLoaded) {
            return _DetailBody(detail: state.detail);
          }
          return const SizedBox.shrink();
        },
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 52, color: Color(0xFFBA1A1A)),
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

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final ComplaintDetailItem detail;

  Color get _statusColor {
    final s = detail.status.toLowerCase();
    if (s == 'open') return const Color(0xFF1A6B3C);
    if (s == 'closed' || s == 'resolved') return const Color(0xFF2563EB);
    return const Color(0xFF888888);
  }

  Color get _statusBg {
    final s = detail.status.toLowerCase();
    if (s == 'open') return const Color(0xFFE8F5EE);
    if (s == 'closed' || s == 'resolved') return const Color(0xFFEFF6FF);
    return const Color(0xFFF3F4F6);
  }

  Color get _replyStatusColor {
    final s = detail.transportReply.toLowerCase();
    if (s == 'pending') return const Color(0xFFF59E0B);
    if (s == 'resolved') return const Color(0xFF1A6B3C);
    return const Color(0xFF888888);
  }

  Color get _replyStatusBg {
    final s = detail.transportReply.toLowerCase();
    if (s == 'pending') return const Color(0xFFFEF3C7);
    if (s == 'resolved') return const Color(0xFFE8F5EE);
    return const Color(0xFFF3F4F6);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: const Border(
                left: BorderSide(color: Color(0xFF1A6B3C), width: 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      detail.complaintType,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        detail.status.toUpperCase(),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 4),
                    Text(
                      'ID: ${detail.complaintId}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF737785),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.schedule, size: 14, color: Color(0xFF9AA0A6)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        detail.complainDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF737785),
                          fontWeight: FontWeight.w700,

                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Complaint message section
          _SectionLabel('COMPLAINT MESSAGE'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              detail.complainMessage.isNotEmpty ? detail.complainMessage : '—',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF333333),
                height: 1.6,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Summary info card
          _SectionLabel('DETAILS'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _InfoRow(label: 'Complaint ID', value: '${detail.complaintId}'),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                _InfoRow(label: 'Type', value: detail.complaintType),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                _InfoRow(label: 'Filed On', value: detail.complainDate),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                _InfoRow(
                  label: 'Status',
                  value: detail.status,
                  valueColor: _statusColor,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF1A1A1A),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value.isNotEmpty ? value : '—',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

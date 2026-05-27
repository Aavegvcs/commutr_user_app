import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/features/auth/presentation/screens/mobile_no_verification.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_state.dart';
import 'package:commutr_main/features/trip_detail/data/model/user_details_roaster_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TeamCabScreen extends StatelessWidget {
  const TeamCabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RosterBloc>()..add(const FetchRosterUserDetails()),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F4),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F5F4),
          elevation: 0,
          title: const Text(
            'Team Cab',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A6B3C),
              fontFamily: 'Manrope',
            ),
          ),
        ),
        body: const _TeamCabBody(),
      ),
    );
  }
}

class _TeamCabBody extends StatelessWidget {
  const _TeamCabBody();

  void _handleSessionExpired(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFB40D1A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MobileNoVerification()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RosterBloc, RosterState>(
      listener: (context, state) {
        if (state is RosterUnauthorized) {
          _handleSessionExpired(context, state.message);
        }
      },
      builder: (context, state) {
        if (state is RosterLoading || state is RosterInitial) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1A6B3C)),
          );
        }

        if (state is RosterError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFF1A6B3C), size: 40),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF737785), fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context
                      .read<RosterBloc>()
                      .add(const FetchRosterUserDetails()),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Color(0xFF1A6B3C)),
                  ),
                ),
              ],
            ),
          );
        }

        if (state is RosterLoaded) {
          final members = state.details.drList;

          if (members.isEmpty) {
            return const Center(
              child: Text(
                'No team members found',
                style: TextStyle(color: Color(0xFF737785), fontSize: 14),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _TeamMemberCard(member: members[index]),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final DrModel member;

  const _TeamMemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFB2EDD4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: Color(0xFF1A6B3C),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.empName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  fontFamily: 'Manrope',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ID: ${member.empId}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF737785),
                  fontFamily: 'Manrope',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

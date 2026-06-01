import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';
import 'package:commutr_main/features/notification/bloc/notification_bloc.dart';
import 'package:commutr_main/features/notification/data/model/notification_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final contactNumber =
        sl<AuthLocalStorage>().getAuthData()?.data?.user?.contactNumber ?? '';
    return BlocProvider(
      create: (_) => sl<NotificationBloc>()..add(FetchNotifications(contactNumber)),
      child: const _NotificationsView(),
    );
  }
}
class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  void _refresh(BuildContext context) {
    final userId =
        sl<AuthLocalStorage>().getAuthData()?.data?.user?.contactNumber ?? '';
    context.read<NotificationBloc>().add(FetchNotifications(userId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF1A5C3A),
                      size: 24,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      color: Color(0xFF1A5C3A),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: BlocBuilder<NotificationBloc, NotificationState>(
                builder: (context, state) {
                  if (state is NotificationLoading ||
                      state is NotificationInitial) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is NotificationError) {
                    return RefreshIndicator(
                      onRefresh: () async => _refresh(context),
                      child: ListView(
                        children: [
                          SizedBox(
                            height: 300,
                            child: Center(child: Text(state.message)),
                          ),
                        ],
                      ),
                    );
                  }

                  final items = state is NotificationLoaded
                      ? state.items
                      : <NotificationItem>[];

                  if (items.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async => _refresh(context),
                      child: ListView(
                        children: const [
                          SizedBox(
                            height: 300,
                            child: Center(child: Text('No notifications')),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => _refresh(context),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isFirst = index == 0;
                        return _NotificationCard(
                          timeLabel: item.sentOn,
                          showDot: isFirst,
                          title: item.textSubject,
                          bodyText: item.textMessage,
                          isRead: !isFirst,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String timeLabel;
  final bool showDot;
  final String title;
  final String bodyText;
  final bool isRead;

  const _NotificationCard({
    required this.timeLabel,
    required this.showDot,
    required this.title,
    required this.bodyText,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: isRead ? const Color(0xFFE8E8E8) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isRead
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                timeLabel,
                style: const TextStyle(
                  color: Color.fromARGB(62, 17, 15, 30),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              if (showDot) ...[
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFB22222),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFBA1A1A),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bodyText,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

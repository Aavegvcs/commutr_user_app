import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/storage/auth_local_storage.dart';
import '../../weekly_off/data/repository/weekly_off_repository.dart';
import 'chat_inapp.dart';

void showChatPopup(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final h = MediaQuery.sizeOf(sheetContext).height * 0.92;
      return Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: SizedBox(
            height: h,
            width: double.infinity,
            child: const ChatPopup(),
          ),
        ),
      );
    },
  );
}

class ChatPopup extends StatefulWidget {
  const ChatPopup({super.key});

  @override
  State<ChatPopup> createState() => _ChatPopupState();
}

class _ChatPopupState extends State<ChatPopup> {
  static String _userTypeFromRoles(List<dynamic>? roles) {
    if (roles == null || roles.isEmpty) return 'manager';
    final first = roles.first;
    if (first is String) return first.toLowerCase();
    if (first is Map && first['name'] != null) {
      return first['name'].toString().toLowerCase();
    }
    return 'manager';
  }

  @override
  void initState() {
    super.initState();
    // _fetchWeeklyOff();
  }

  Future<void> _fetchWeeklyOff() async {
    final auth = AuthLocalStorage().getAuthData();
    final token = auth?.data?.accessToken ?? '';
    if (token.isEmpty) return;

    try {
      await sl<WeeklyOffRepository>().showWeeklyOff();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final storage = AuthLocalStorage();
    final auth = storage.getAuthData();
    final token = auth?.data?.accessToken ?? '';
    final userId = auth?.data?.user?.userId ?? '';
    final tenantId = auth?.data?.user?.tenantId ?? '';

    if (token.isEmpty || userId.isEmpty || tenantId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Transport Assistant',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Sign in to use the assistant.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return EtsChatWebViewPage(
      accessToken: token,
      userId: userId,
      tenantId: tenantId,
      userType: _userTypeFromRoles(auth?.data?.roles),
    );
  }
}

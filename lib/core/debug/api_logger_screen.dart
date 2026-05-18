import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_log_entry.dart';
import 'api_logger_service.dart';

class ApiLoggerScreen extends StatefulWidget {
  const ApiLoggerScreen({super.key});

  @override
  State<ApiLoggerScreen> createState() => _ApiLoggerScreenState();
}

class _ApiLoggerScreenState extends State<ApiLoggerScreen> {
  ApiLogStatus? _filter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        title: const Text(
          'API Logger',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        actions: [
          _FilterChipRow(
            current: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.delete_sweep_outlined, size: 22),
            onPressed: () {
              ApiLoggerService.instance.clearAll();
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: ApiLoggerService.instance,
        builder: (context, _) {
          final all = ApiLoggerService.instance.entries;
          final entries = _filter == null
              ? all
              : all.where((e) => e.status == _filter).toList();

          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_tethering_outlined,
                      size: 52, color: Colors.white24),
                  const SizedBox(height: 12),
                  Text(
                    all.isEmpty ? 'No requests yet' : 'No matching requests',
                    style: const TextStyle(color: Colors.white38, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFF222222)),
            itemBuilder: (context, i) => _LogTile(entry: entries[i]),
          );
        },
      ),
    );
  }
}

// ── Filter chip row ──────────────────────────────────────────────────────────

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({required this.current, required this.onChanged});

  final ApiLogStatus? current;
  final ValueChanged<ApiLogStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(
          label: 'All',
          active: current == null,
          color: Colors.white,
          onTap: () => onChanged(null),
        ),
        _Chip(
          label: '2xx',
          active: current == ApiLogStatus.success,
          color: const Color(0xFF4CAF50),
          onTap: () => onChanged(
            current == ApiLogStatus.success ? null : ApiLogStatus.success,
          ),
        ),
        _Chip(
          label: 'Err',
          active: current == ApiLogStatus.error,
          color: const Color(0xFFF44336),
          onTap: () => onChanged(
            current == ApiLogStatus.error ? null : ApiLogStatus.error,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? color : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? color : Colors.white38,
          ),
        ),
      ),
    );
  }
}

// ── Log tile ─────────────────────────────────────────────────────────────────

class _LogTile extends StatefulWidget {
  const _LogTile({required this.entry});
  final ApiLogEntry entry;

  @override
  State<_LogTile> createState() => _LogTileState();
}

class _LogTileState extends State<_LogTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final statusColor = _statusColor(e.status, e.statusCode);
    final methodColor = _methodColor(e.method);
    final uri = Uri.tryParse(e.url);
    final path = uri?.path ?? e.url;

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row: method badge + path + status + duration ─────────────
            Row(
              children: [
                _Badge(label: e.method, color: methodColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    path,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (e.statusCode != null)
                  Text(
                    '${e.statusCode}',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                if (e.status == ApiLogStatus.pending)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white38,
                    ),
                  ),
                const SizedBox(width: 6),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white38,
                  size: 18,
                ),
              ],
            ),

            // ── Sub-row: timestamp + duration ────────────────────────────
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  _formatTime(e.timestamp),
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                if (e.duration != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${e.duration!.inMilliseconds} ms',
                    style: TextStyle(color: statusColor.withValues(alpha: 0.7), fontSize: 11),
                  ),
                ],
                if (e.errorMessage != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.errorMessage!,
                      style: const TextStyle(
                          color: Color(0xFFF44336), fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),

            // ── Expanded detail ──────────────────────────────────────────
            if (_expanded) ...[
              const SizedBox(height: 10),
              _DetailSection(
                title: 'URL',
                content: e.url,
              ),
              if (e.requestHeaders != null && e.requestHeaders!.isNotEmpty)
                _DetailSection(
                  title: 'REQUEST HEADERS',
                  content: _prettyJson(e.requestHeaders),
                ),
              if (e.requestBody != null)
                _DetailSection(
                  title: 'REQUEST BODY',
                  content: _prettyJson(e.requestBody),
                ),
              if (e.responseBody != null)
                _DetailSection(
                  title: 'RESPONSE BODY',
                  content: _prettyJson(e.responseBody),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(ApiLogStatus status, int? code) {
    switch (status) {
      case ApiLogStatus.success:
        return const Color(0xFF4CAF50);
      case ApiLogStatus.error:
        return const Color(0xFFF44336);
      case ApiLogStatus.pending:
        return Colors.white54;
    }
  }

  Color _methodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return const Color(0xFF61AFEF);
      case 'POST':
        return const Color(0xFF98C379);
      case 'PUT':
        return const Color(0xFFE5C07B);
      case 'DELETE':
        return const Color(0xFFE06C75);
      case 'PATCH':
        return const Color(0xFFC678DD);
      default:
        return Colors.white54;
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String _prettyJson(dynamic value) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(value);
    } catch (_) {
      return value.toString();
    }
  }
}

// ── Badge ────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Detail section (code block) ───────────────────────────────────────────────

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.content});
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: const Icon(Icons.copy, size: 13, color: Colors.white24),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: SelectableText(
              content,
              style: const TextStyle(
                color: Color(0xFFABB2BF),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

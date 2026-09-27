import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/session_history.dart';
import '../services/api_client.dart';
import '../services/resource_access.dart';
import '../widgets/fixed_back_layout.dart';
import '../widgets/loading_skeleton.dart';
import 'result_page.dart';
import 'script_practice_page.dart';
import 'time_challenge_page.dart';

Future<void> openSavedSession(
  BuildContext context, {
  required String userId,
  required Map<String, dynamic> session,
  required VoidCallback onStartPractice,
  required VoidCallback onBackToHome,
}) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (resultContext) => ResultPage(
        sessionData: session,
        onBack: () => Navigator.pop(resultContext),
        onBackToHome: () {
          Navigator.popUntil(resultContext, (route) => route.isFirst);
          onBackToHome();
        },
        onPracticeAgain: () async {
          final resource = session['challengeId'] is Map
              ? session['challengeId']
              : session['resourceId'];
          if (resource is! Map) {
            Navigator.popUntil(resultContext, (route) => route.isFirst);
            onStartPractice();
            return;
          }
          try {
            final current = await ResourceAccess.fetchCurrentLevel(userId);
            if (!resultContext.mounted) return;
            final level = ResourceAccess.parseLevel(resource['difficulty']);
            if (level != null && !ResourceAccess.allows(current, level)) {
              ScaffoldMessenger.of(resultContext).showSnackBar(
                SnackBar(content: Text(ResourceAccess.lockedMessage(level))),
              );
              return;
            }
            Navigator.pushReplacement(
              resultContext,
              MaterialPageRoute(
                builder: (_) => session['challengeId'] is Map
                    ? TimedChallengePage(
                        challenge: resource,
                        userId: userId,
                        onBackToHome: onBackToHome,
                      )
                    : ScriptPracticePage(
                        script: resource,
                        userId: userId,
                        onBackToHome: onBackToHome,
                      ),
              ),
            );
          } catch (_) {
            if (!resultContext.mounted) return;
            ScaffoldMessenger.of(resultContext).showSnackBar(
              const SnackBar(
                content: Text(
                  'Unable to verify your current level. Please try again.',
                ),
              ),
            );
          }
        },
      ),
    ),
  );
}

class SessionHistoryPage extends StatefulWidget {
  final String userId;
  final VoidCallback onStartPractice;
  final VoidCallback onBackToHome;

  const SessionHistoryPage({
    super.key,
    required this.userId,
    required this.onStartPractice,
    required this.onBackToHome,
  });

  @override
  State<SessionHistoryPage> createState() => _SessionHistoryPageState();
}

class _SessionHistoryPageState extends State<SessionHistoryPage> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextCursor;
  int _totalSessions = 0;
  String? _error;
  bool _failedMore = false;
  bool _refreshing = false;
  int _generation = 0;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_loading &&
        !_refreshing &&
        !_loadingMore &&
        _error == null &&
        _nextCursor != null &&
        _scrollController.hasClients &&
        _scrollController.position.extentAfter < 240) {
      _load(more: true);
    }
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loadingMore || _refreshing || _nextCursor == null)) return;
    final generation = more ? _generation : ++_generation;
    final cursor = more ? _nextCursor : null;
    setState(() {
      _error = null;
      if (more) {
        _loadingMore = true;
      } else {
        _refreshing = true;
        _loadingMore = false;
        _loading = _sessions.isEmpty;
      }
    });
    try {
      final response = await ApiClient.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/sessions/${widget.userId}',
        ).replace(queryParameters: {'limit': '20', 'before': ?cursor}),
      );
      if (response.statusCode != 200) throw StateError('History unavailable');
      final incoming = (jsonDecode(response.body) as List).map(
        (row) => Map<String, dynamic>.from(row as Map),
      );
      if (!mounted || generation != _generation) return;
      final seen = <String>{};
      final combined = <Map<String, dynamic>>[];
      for (final row in [
        ...(more ? _sessions : <Map<String, dynamic>>[]),
        ...incoming,
      ]) {
        final id = row['_id']?.toString();
        if (id == null || seen.add(id)) combined.add(row);
      }
      setState(() {
        _sessions = newestSessions(combined);
        _totalSessions =
            int.tryParse(response.headers['x-total-count'] ?? '') ??
            _sessions.length;
        final next = response.headers['x-next-cursor'];
        _nextCursor = next == null || next.isEmpty || next == cursor
            ? null
            : next;
        _loading = false;
        _failedMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _failedMore = more;
        _error = more
            ? 'Unable to load more sessions. Please try again.'
            : 'Unable to load sessions. Please try again.';
      });
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loadingMore = false;
          _refreshing = false;
        });
        // Also fill short first pages, without polling or repeating a cursor.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeLoadMore();
        });
      }
    }
  }

  String _date(Map session) {
    final date = DateTime.tryParse(
      session['createdAt']?.toString() ?? '',
    )?.toLocal();
    if (date == null) return 'Date unknown';
    return '${date.month}/${date.day}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F5F5),
    body: FixedBackLayout(
      child: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            const Text(
              'Session History',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'All your saved practice sessions',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const SkeletonList(count: 4)
            else if (_sessions.isEmpty && _error == null)
              const Text('No sessions recorded yet. Start practicing!')
            else
              for (final entry in _sessions.asMap().entries)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    title: Text(
                      'Session #${_totalSessions - entry.key}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${_date(entry.value)}\n${entry.value['language'] ?? 'English'}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      '${(entry.value['overallScore'] as num? ?? 0).toInt()}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3F7CF4),
                      ),
                    ),
                    onTap: () async {
                      await openSavedSession(
                        context,
                        userId: widget.userId,
                        session: entry.value,
                        onStartPractice: widget.onStartPractice,
                        onBackToHome: widget.onBackToHome,
                      );
                      if (mounted) await _load();
                    },
                  ),
                ),
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            if (_error != null) ...[
              Text(_error!),
              TextButton(
                onPressed: () => _load(more: _failedMore),
                child: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// ============================================================
// sync_status_widget.dart — lib/widgets/sync_status_widget.dart
//
// Widget à mettre dans l'AppBar pour montrer l'état de sync
// Affiche : 🟢 En ligne / 🔴 Hors ligne / ⏳ Sync en cours
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/sync_engine.dart';

class SyncStatusWidget extends StatefulWidget {
  final int teacherId;
  const SyncStatusWidget({super.key, required this.teacherId});

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  bool _isOnline = false;
  bool _isSyncing = false;
  String _lastSyncMessage = '';
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _checkInitial();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online && !_isOnline) {
        // Vient de se connecter → sync
        _triggerSync();
      }
      if (mounted) setState(() => _isOnline = online);
    });
  }

  Future<void> _checkInitial() async {
    final online = await SyncEngine.isOnline();
    if (mounted) setState(() => _isOnline = online);
  }

  Future<void> _triggerSync() async {
    if (_isSyncing) return;
    if (mounted) setState(() => _isSyncing = true);

    final report = await SyncEngine.syncAll(teacherId: widget.teacherId);

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _lastSyncMessage = report.message;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isOnline ? _triggerSync : null,
      child: Tooltip(
        message: _isSyncing
            ? 'Synchronisation...'
            : _isOnline
            ? 'En ligne — Appuyer pour synchroniser\n$_lastSyncMessage'
            : 'Hors ligne — Données sauvegardées localement',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _isSyncing
                ? Colors.amber.withOpacity(0.3)
                : _isOnline
                ? Colors.green.withOpacity(0.3)
                : Colors.red.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isSyncing
                  ? Colors.amber
                  : _isOnline
                  ? Colors.green
                  : Colors.red,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSyncing)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.amber,
                  ),
                )
              else
                Icon(
                  _isOnline ? Icons.cloud_done : Icons.cloud_off,
                  size: 14,
                  color: _isOnline ? Colors.green : Colors.red,
                ),
              const SizedBox(width: 4),
              Text(
                _isSyncing
                    ? 'Sync...'
                    : _isOnline
                    ? 'En ligne'
                    : 'Hors ligne',
                style: TextStyle(
                  fontSize: 11,
                  color: _isSyncing
                      ? Colors.amber.shade800
                      : _isOnline
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

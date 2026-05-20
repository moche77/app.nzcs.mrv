import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/data_models.dart';
import 'data_service.dart';

/// FirebaseSyncService
///
/// Provides bidirectional synchronization between the local Hive store and
/// the `nzcsmrvmobile` Firestore project. Designed for multi-device
/// deployments where Receiving, Pyrolysis, Lab, Inventory, and Field
/// operate on separate phones/tablets — identifiers minted on one device
/// become selectable on every other device within seconds.
///
/// Architecture:
///   • Each module maps to a top-level Firestore collection.
///   • Local saves push to Firestore immediately (write-through cache).
///   • Remote changes stream back via snapshot listeners and hydrate Hive,
///     causing UI rebuilds via DataService.notifyListeners().
///   • Offline writes are buffered by Firestore's persistence layer and
///     replayed on reconnect — no custom queue needed.
///
/// All operations are wrapped in defensive try/catch so Firestore failures
/// (no network, no permissions, project misconfiguration) never break the
/// local-only experience.
class FirebaseSyncService {
  final DataService _dataService;
  FirebaseFirestore? _db;
  bool _enabled = false;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _subs = [];

  FirebaseSyncService(this._dataService);

  bool get isEnabled => _enabled;

  /// Wire up Firestore listeners. Safe to call even when Firebase failed
  /// to initialize — simply becomes a no-op.
  Future<void> initialize() async {
    try {
      _db = FirebaseFirestore.instance;
      // Enable offline persistence (default on Android, explicit here for clarity).
      _db!.settings = const Settings(persistenceEnabled: true);
      _enabled = true;
      _attachListeners();
      // Register write-through hooks so local saves propagate to Firestore.
      _dataService.onAfterSave = _syncOne;
      _dataService.onAfterDelete = _deleteOne;
    } catch (e) {
      if (kDebugMode) debugPrint('FirebaseSyncService init failed: $e');
      _enabled = false;
    }
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  void _attachListeners() {
    if (_db == null) return;
    _subs.add(_db!
        .collection('feedstock_logs')
        .snapshots()
        .listen((snap) => _hydrate(snap, 'feedstock'),
            onError: (_) {}));
    _subs.add(_db!
        .collection('production_runs')
        .snapshots()
        .listen((snap) => _hydrate(snap, 'production'),
            onError: (_) {}));
    _subs.add(_db!
        .collection('quality_batches')
        .snapshots()
        .listen((snap) => _hydrate(snap, 'quality'),
            onError: (_) {}));
    _subs.add(_db!
        .collection('inventory_lots')
        .snapshots()
        .listen((snap) => _hydrate(snap, 'inventory'),
            onError: (_) {}));
    _subs.add(_db!
        .collection('application_events')
        .snapshots()
        .listen((snap) => _hydrate(snap, 'application'),
            onError: (_) {}));
    _subs.add(_db!
        .collection('global_qa')
        .snapshots()
        .listen((snap) => _hydrate(snap, 'qa'),
            onError: (_) {}));
    _subs.add(_db!
        .collection('audit_controls')
        .snapshots()
        .listen((snap) => _hydrate(snap, 'audit'),
            onError: (_) {}));
  }

  Future<void> _hydrate(
      QuerySnapshot<Map<String, dynamic>> snap, String module) async {
    try {
      for (final change in snap.docChanges) {
        final docData = change.doc.data();
        if (docData == null) continue;
        switch (module) {
          case 'feedstock':
            await _dataService
                .saveFeedstockLocal(FeedstockLog.fromMap(docData));
            break;
          case 'production':
            await _dataService
                .saveProductionLocal(ProductionRun.fromMap(docData));
            break;
          case 'quality':
            await _dataService
                .saveQualityLocal(QualityBatch.fromMap(docData));
            break;
          case 'inventory':
            await _dataService
                .saveInventoryLocal(InventoryLot.fromMap(docData));
            break;
          case 'application':
            await _dataService
                .saveApplicationLocal(ApplicationEvent.fromMap(docData));
            break;
          case 'qa':
            await _dataService.saveGlobalQALocal(GlobalQA.fromMap(docData));
            break;
          case 'audit':
            await _dataService
                .saveAuditControlLocal(AuditControl.fromMap(docData));
            break;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Hydrate $module failed: $e');
    }
  }

  // Resolve module + id from any data object for write-through.
  Future<void> _syncOne(String module, String id, Map<String, dynamic> data) async {
    if (!_enabled || _db == null) return;
    try {
      final collection = _moduleToCollection(module);
      if (collection == null) return;
      await _db!.collection(collection).doc(id).set(data, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('Sync $module/$id failed: $e');
    }
  }

  Future<void> _deleteOne(String module, String id) async {
    if (!_enabled || _db == null) return;
    try {
      final collection = _moduleToCollection(module);
      if (collection == null) return;
      await _db!.collection(collection).doc(id).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('Delete $module/$id failed: $e');
    }
  }

  String? _moduleToCollection(String module) {
    switch (module) {
      case 'feedstock':
        return 'feedstock_logs';
      case 'production':
        return 'production_runs';
      case 'quality':
        return 'quality_batches';
      case 'inventory':
        return 'inventory_lots';
      case 'application':
        return 'application_events';
      case 'qa':
        return 'global_qa';
      case 'audit':
        return 'audit_controls';
      default:
        return null;
    }
  }
}

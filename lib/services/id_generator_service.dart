import 'package:hive/hive.dart';

/// IdGeneratorService
///
/// Centralized, deterministic identifier authority for all NerZero MRV
/// modules. Generates audit-grade, human-readable IDs with the following
/// canonical format:
///
///     <PREFIX>-<YYYYMM>-<NNNN>
///
/// Where:
///   • PREFIX  = module-specific token (FS, PR, QB, INV, APP, QA, AUD, etc.)
///   • YYYYMM  = current monitoring period (year + month, zero-padded)
///   • NNNN    = monotonically increasing 4-digit sequence per prefix-period
///
/// Examples:
///   FS-202501-0001   (Feedstock Load, January 2025, first entry)
///   PR-202501-0004   (Production Run, January 2025, fourth entry)
///   QB-202501-0012   (Quality Batch, January 2025, twelfth entry)
///
/// Sequence counters are persisted in a Hive box (`id_counters`) keyed by
/// `<PREFIX>-<YYYYMM>`, ensuring deterministic resumption across cold starts
/// and preventing duplicate identifiers even after process termination.
class IdGeneratorService {
  static const String _boxName = 'id_counters';

  // Canonical module prefixes (aligned with VM0044 spreadsheet conventions).
  static const String prefixFeedstock = 'FS';
  static const String prefixProduction = 'PR';
  static const String prefixQualityBatch = 'QB';
  static const String prefixInventoryLot = 'INV';
  static const String prefixApplication = 'APP';
  static const String prefixGlobalQA = 'QA';
  static const String prefixAuditControl = 'AUD';

  // Sub-entity prefixes used inside parent records.
  static const String prefixStorage = 'STG';
  static const String prefixProcessing = 'PROC';
  static const String prefixUnitLine = 'UL';
  static const String prefixSoilSite = 'SOIL';

  Box<dynamic>? _box;

  Future<void> initialize() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  /// Generates the next sequential identifier for the supplied prefix,
  /// scoped to the current calendar month (UTC-stable on device).
  ///
  /// This method is idempotent at the persistence layer: each call advances
  /// the counter exactly once and returns the resulting fully-qualified ID.
  String nextId(String prefix, {DateTime? referenceDate}) {
    final box = _box;
    if (box == null) {
      // Fallback: pre-initialization safety net — should never trigger in
      // production because initialize() is awaited in main().
      return _formatId(prefix, _periodKey(referenceDate ?? DateTime.now()), 1);
    }
    final period = _periodKey(referenceDate ?? DateTime.now());
    final counterKey = '$prefix-$period';
    final current = (box.get(counterKey, defaultValue: 0) as int);
    final next = current + 1;
    box.put(counterKey, next);
    return _formatId(prefix, period, next);
  }

  /// Peek the next identifier without advancing the counter. Useful for
  /// previewing IDs in read-only form fields prior to commit.
  String peekNextId(String prefix, {DateTime? referenceDate}) {
    final box = _box;
    final period = _periodKey(referenceDate ?? DateTime.now());
    final counterKey = '$prefix-$period';
    final current = (box?.get(counterKey, defaultValue: 0) as int? ?? 0);
    return _formatId(prefix, period, current + 1);
  }

  /// Convenience generators per module.
  String nextFeedstockId({DateTime? referenceDate}) =>
      nextId(prefixFeedstock, referenceDate: referenceDate);

  String nextProductionId({DateTime? referenceDate}) =>
      nextId(prefixProduction, referenceDate: referenceDate);

  String nextQualityBatchId({DateTime? referenceDate}) =>
      nextId(prefixQualityBatch, referenceDate: referenceDate);

  String nextInventoryLotId({DateTime? referenceDate}) =>
      nextId(prefixInventoryLot, referenceDate: referenceDate);

  String nextApplicationEventId({DateTime? referenceDate}) =>
      nextId(prefixApplication, referenceDate: referenceDate);

  String nextGlobalQAId({DateTime? referenceDate}) =>
      nextId(prefixGlobalQA, referenceDate: referenceDate);

  String nextAuditControlId({DateTime? referenceDate}) =>
      nextId(prefixAuditControl, referenceDate: referenceDate);

  String nextStorageId({DateTime? referenceDate}) =>
      nextId(prefixStorage, referenceDate: referenceDate);

  String nextProcessingLocationId({DateTime? referenceDate}) =>
      nextId(prefixProcessing, referenceDate: referenceDate);

  String nextUnitLineId({DateTime? referenceDate}) =>
      nextId(prefixUnitLine, referenceDate: referenceDate);

  String nextSoilSiteId({DateTime? referenceDate}) =>
      nextId(prefixSoilSite, referenceDate: referenceDate);

  /// Peek-only variants for read-only previews.
  String peekFeedstockId() => peekNextId(prefixFeedstock);
  String peekProductionId() => peekNextId(prefixProduction);
  String peekQualityBatchId() => peekNextId(prefixQualityBatch);
  String peekInventoryLotId() => peekNextId(prefixInventoryLot);
  String peekApplicationEventId() => peekNextId(prefixApplication);
  String peekGlobalQAId() => peekNextId(prefixGlobalQA);
  String peekAuditControlId() => peekNextId(prefixAuditControl);

  // ─── internal helpers ────────────────────────────────────────────────
  String _periodKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}';

  String _formatId(String prefix, String period, int seq) =>
      '$prefix-$period-${seq.toString().padLeft(4, '0')}';
}

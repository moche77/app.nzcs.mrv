import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/data_models.dart';

class DataService extends ChangeNotifier {
  static const _feedstockBox = 'feedstock_box';
  static const _productionBox = 'production_box';
  static const _qualityBox = 'quality_box';
  static const _inventoryBox = 'inventory_box';
  static const _applicationBox = 'application_box';
  static const _qaBox = 'qa_box';
  static const _auditBox = 'audit_box';
  static const _factorsBox = 'factors_box';

  late Box _feedstock;
  late Box _production;
  late Box _quality;
  late Box _inventory;
  late Box _application;
  late Box _qa;
  late Box _audit;
  late Box _factors;

  final _uuid = const Uuid();
  String newId() => _uuid.v4();

  EmissionFactors _emissionFactors = EmissionFactors();
  EmissionFactors get emissionFactors => _emissionFactors;

  Future<void> initialize() async {
    _feedstock = await Hive.openBox(_feedstockBox);
    _production = await Hive.openBox(_productionBox);
    _quality = await Hive.openBox(_qualityBox);
    _inventory = await Hive.openBox(_inventoryBox);
    _application = await Hive.openBox(_applicationBox);
    _qa = await Hive.openBox(_qaBox);
    _audit = await Hive.openBox(_auditBox);
    _factors = await Hive.openBox(_factorsBox);

    final stored = _factors.get('current');
    if (stored != null) {
      _emissionFactors =
          EmissionFactors.fromMap(Map<String, dynamic>.from(stored as Map));
    } else {
      await _factors.put('current', _emissionFactors.toMap());
    }
  }

  Future<void> updateEmissionFactors(EmissionFactors f) async {
    _emissionFactors = f;
    await _factors.put('current', f.toMap());
    notifyListeners();
  }

  // ============ FEEDSTOCK ============
  List<FeedstockLog> getFeedstockLogs() => _feedstock.values
      .map((m) => FeedstockLog.fromMap(Map<String, dynamic>.from(m as Map)))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  Future<void> saveFeedstock(FeedstockLog log) async {
    await _feedstock.put(log.id, log.toMap());
    notifyListeners();
  }

  Future<void> deleteFeedstock(String id) async {
    await _feedstock.delete(id);
    notifyListeners();
  }

  // ============ PRODUCTION ============
  List<ProductionRun> getProductionRuns() => _production.values
      .map((m) => ProductionRun.fromMap(Map<String, dynamic>.from(m as Map)))
      .toList()
    ..sort((a, b) => b.productionDate.compareTo(a.productionDate));

  Future<void> saveProduction(ProductionRun run) async {
    await _production.put(run.id, run.toMap());
    notifyListeners();
  }

  Future<void> deleteProduction(String id) async {
    await _production.delete(id);
    notifyListeners();
  }

  // ============ QUALITY ============
  List<QualityBatch> getQualityBatches() => _quality.values
      .map((m) => QualityBatch.fromMap(Map<String, dynamic>.from(m as Map)))
      .toList()
    ..sort((a, b) => b.samplingDate.compareTo(a.samplingDate));

  Future<void> saveQuality(QualityBatch q) async {
    await _quality.put(q.id, q.toMap());
    notifyListeners();
  }

  Future<void> deleteQuality(String id) async {
    await _quality.delete(id);
    notifyListeners();
  }

  // ============ INVENTORY ============
  List<InventoryLot> getInventoryLots() => _inventory.values
      .map((m) => InventoryLot.fromMap(Map<String, dynamic>.from(m as Map)))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  Future<void> saveInventory(InventoryLot lot) async {
    await _inventory.put(lot.id, lot.toMap());
    notifyListeners();
  }

  Future<void> deleteInventory(String id) async {
    await _inventory.delete(id);
    notifyListeners();
  }

  // ============ APPLICATION ============
  List<ApplicationEvent> getApplicationEvents() => _application.values
      .map((m) =>
          ApplicationEvent.fromMap(Map<String, dynamic>.from(m as Map)))
      .toList()
    ..sort((a, b) => b.applicationDate.compareTo(a.applicationDate));

  Future<void> saveApplication(ApplicationEvent e) async {
    await _application.put(e.id, e.toMap());
    notifyListeners();
  }

  Future<void> deleteApplication(String id) async {
    await _application.delete(id);
    notifyListeners();
  }

  // ============ GLOBAL QA ============
  List<GlobalQA> getGlobalQA() => _qa.values
      .map((m) => GlobalQA.fromMap(Map<String, dynamic>.from(m as Map)))
      .toList()
    ..sort((a, b) => b.dateReviewed.compareTo(a.dateReviewed));

  Future<void> saveGlobalQA(GlobalQA q) async {
    await _qa.put(q.id, q.toMap());
    notifyListeners();
  }

  Future<void> deleteGlobalQA(String id) async {
    await _qa.delete(id);
    notifyListeners();
  }

  // ============ AUDIT CONTROLS ============
  List<AuditControl> getAuditControls() => _audit.values
      .map((m) => AuditControl.fromMap(Map<String, dynamic>.from(m as Map)))
      .toList()
    ..sort((a, b) => b.dateChecked.compareTo(a.dateChecked));

  Future<void> saveAuditControl(AuditControl c) async {
    await _audit.put(c.id, c.toMap());
    notifyListeners();
  }

  Future<void> deleteAuditControl(String id) async {
    await _audit.delete(id);
    notifyListeners();
  }
}

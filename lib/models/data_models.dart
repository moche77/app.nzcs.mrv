// Data models mirror the 7 sheets of the VM0044 MRV workbook.
// All quantities use dry-basis mass accounting per VM0044 methodology.

class FeedstockLog {
  final String id;
  final DateTime date;
  final String loadId;
  final String category;
  final String supplier;
  final String sourceFacility;
  final String sourceAddress;
  final String eligibilityStatus;
  final String baselineDisposalPathway;
  final String bolNumber;
  final String transportMode;
  final double distanceMiles;
  final String fuelType;
  final double grossWeight;
  final String moistureBasis;
  final double netWeightDry;
  final String scaleTicketRef;
  final String visualInspection;
  final String observedContamination;
  final String acceptanceStatus; // accepted / rejected / pending
  final String initialStorageId;
  final String processingLocationId;
  final String comments;
  final String enteredBy;
  final DateTime createdAt;

  FeedstockLog({
    required this.id,
    required this.date,
    required this.loadId,
    required this.category,
    required this.supplier,
    required this.sourceFacility,
    required this.sourceAddress,
    required this.eligibilityStatus,
    required this.baselineDisposalPathway,
    required this.bolNumber,
    required this.transportMode,
    required this.distanceMiles,
    required this.fuelType,
    required this.grossWeight,
    required this.moistureBasis,
    required this.netWeightDry,
    required this.scaleTicketRef,
    required this.visualInspection,
    required this.observedContamination,
    required this.acceptanceStatus,
    required this.initialStorageId,
    required this.processingLocationId,
    required this.comments,
    required this.enteredBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'loadId': loadId,
        'category': category,
        'supplier': supplier,
        'sourceFacility': sourceFacility,
        'sourceAddress': sourceAddress,
        'eligibilityStatus': eligibilityStatus,
        'baselineDisposalPathway': baselineDisposalPathway,
        'bolNumber': bolNumber,
        'transportMode': transportMode,
        'distanceMiles': distanceMiles,
        'fuelType': fuelType,
        'grossWeight': grossWeight,
        'moistureBasis': moistureBasis,
        'netWeightDry': netWeightDry,
        'scaleTicketRef': scaleTicketRef,
        'visualInspection': visualInspection,
        'observedContamination': observedContamination,
        'acceptanceStatus': acceptanceStatus,
        'initialStorageId': initialStorageId,
        'processingLocationId': processingLocationId,
        'comments': comments,
        'enteredBy': enteredBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FeedstockLog.fromMap(Map<dynamic, dynamic> m) => FeedstockLog(
        id: m['id'] as String,
        date: DateTime.parse(m['date'] as String),
        loadId: m['loadId'] as String? ?? '',
        category: m['category'] as String? ?? '',
        supplier: m['supplier'] as String? ?? '',
        sourceFacility: m['sourceFacility'] as String? ?? '',
        sourceAddress: m['sourceAddress'] as String? ?? '',
        eligibilityStatus: m['eligibilityStatus'] as String? ?? '',
        baselineDisposalPathway: m['baselineDisposalPathway'] as String? ?? '',
        bolNumber: m['bolNumber'] as String? ?? '',
        transportMode: m['transportMode'] as String? ?? '',
        distanceMiles: (m['distanceMiles'] as num?)?.toDouble() ?? 0,
        fuelType: m['fuelType'] as String? ?? '',
        grossWeight: (m['grossWeight'] as num?)?.toDouble() ?? 0,
        moistureBasis: m['moistureBasis'] as String? ?? '',
        netWeightDry: (m['netWeightDry'] as num?)?.toDouble() ?? 0,
        scaleTicketRef: m['scaleTicketRef'] as String? ?? '',
        visualInspection: m['visualInspection'] as String? ?? '',
        observedContamination: m['observedContamination'] as String? ?? '',
        acceptanceStatus: m['acceptanceStatus'] as String? ?? '',
        initialStorageId: m['initialStorageId'] as String? ?? '',
        processingLocationId: m['processingLocationId'] as String? ?? '',
        comments: m['comments'] as String? ?? '',
        enteredBy: m['enteredBy'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}

class ProductionRun {
  final String id;
  final DateTime productionDate;
  final String runId;
  final String unitLineId;
  final String linkedFeedstockLoadIds;
  final double feedstockInputDry;
  final double reactorTemperature;
  final double residenceTimeMin;
  final String oxygenLimitedConfirmation;
  final double electricityKwh;
  final double supplementalFuelLiters;
  final String supplementalFuelType;
  final double biocharProducedDry;
  final String comments;
  final String enteredBy;
  final DateTime createdAt;

  double get massYield =>
      feedstockInputDry > 0 ? biocharProducedDry / feedstockInputDry : 0;

  ProductionRun({
    required this.id,
    required this.productionDate,
    required this.runId,
    required this.unitLineId,
    required this.linkedFeedstockLoadIds,
    required this.feedstockInputDry,
    required this.reactorTemperature,
    required this.residenceTimeMin,
    required this.oxygenLimitedConfirmation,
    required this.electricityKwh,
    required this.supplementalFuelLiters,
    required this.supplementalFuelType,
    required this.biocharProducedDry,
    required this.comments,
    required this.enteredBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'productionDate': productionDate.toIso8601String(),
        'runId': runId,
        'unitLineId': unitLineId,
        'linkedFeedstockLoadIds': linkedFeedstockLoadIds,
        'feedstockInputDry': feedstockInputDry,
        'reactorTemperature': reactorTemperature,
        'residenceTimeMin': residenceTimeMin,
        'oxygenLimitedConfirmation': oxygenLimitedConfirmation,
        'electricityKwh': electricityKwh,
        'supplementalFuelLiters': supplementalFuelLiters,
        'supplementalFuelType': supplementalFuelType,
        'biocharProducedDry': biocharProducedDry,
        'comments': comments,
        'enteredBy': enteredBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ProductionRun.fromMap(Map<dynamic, dynamic> m) => ProductionRun(
        id: m['id'] as String,
        productionDate: DateTime.parse(m['productionDate'] as String),
        runId: m['runId'] as String? ?? '',
        unitLineId: m['unitLineId'] as String? ?? '',
        linkedFeedstockLoadIds: m['linkedFeedstockLoadIds'] as String? ?? '',
        feedstockInputDry: (m['feedstockInputDry'] as num?)?.toDouble() ?? 0,
        reactorTemperature: (m['reactorTemperature'] as num?)?.toDouble() ?? 0,
        residenceTimeMin: (m['residenceTimeMin'] as num?)?.toDouble() ?? 0,
        oxygenLimitedConfirmation:
            m['oxygenLimitedConfirmation'] as String? ?? '',
        electricityKwh: (m['electricityKwh'] as num?)?.toDouble() ?? 0,
        supplementalFuelLiters:
            (m['supplementalFuelLiters'] as num?)?.toDouble() ?? 0,
        supplementalFuelType: m['supplementalFuelType'] as String? ?? '',
        biocharProducedDry: (m['biocharProducedDry'] as num?)?.toDouble() ?? 0,
        comments: m['comments'] as String? ?? '',
        enteredBy: m['enteredBy'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}

class QualityBatch {
  final String id;
  final String batchLotId;
  final String productionRunIdsCovered;
  final double batchQuantityDry;
  final DateTime samplingDate;
  final String samplingMethodRef;
  final String labCoaRef;
  final double moisturePct;
  final double ashPct;
  final double totalCarbonPct;
  final double hCorgMolar;
  final String acceptanceStatus; // accepted / rejected / pending
  final String comments;
  final String enteredBy;
  final DateTime createdAt;

  QualityBatch({
    required this.id,
    required this.batchLotId,
    required this.productionRunIdsCovered,
    required this.batchQuantityDry,
    required this.samplingDate,
    required this.samplingMethodRef,
    required this.labCoaRef,
    required this.moisturePct,
    required this.ashPct,
    required this.totalCarbonPct,
    required this.hCorgMolar,
    required this.acceptanceStatus,
    required this.comments,
    required this.enteredBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'batchLotId': batchLotId,
        'productionRunIdsCovered': productionRunIdsCovered,
        'batchQuantityDry': batchQuantityDry,
        'samplingDate': samplingDate.toIso8601String(),
        'samplingMethodRef': samplingMethodRef,
        'labCoaRef': labCoaRef,
        'moisturePct': moisturePct,
        'ashPct': ashPct,
        'totalCarbonPct': totalCarbonPct,
        'hCorgMolar': hCorgMolar,
        'acceptanceStatus': acceptanceStatus,
        'comments': comments,
        'enteredBy': enteredBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory QualityBatch.fromMap(Map<dynamic, dynamic> m) => QualityBatch(
        id: m['id'] as String,
        batchLotId: m['batchLotId'] as String? ?? '',
        productionRunIdsCovered:
            m['productionRunIdsCovered'] as String? ?? '',
        batchQuantityDry: (m['batchQuantityDry'] as num?)?.toDouble() ?? 0,
        samplingDate: DateTime.parse(m['samplingDate'] as String),
        samplingMethodRef: m['samplingMethodRef'] as String? ?? '',
        labCoaRef: m['labCoaRef'] as String? ?? '',
        moisturePct: (m['moisturePct'] as num?)?.toDouble() ?? 0,
        ashPct: (m['ashPct'] as num?)?.toDouble() ?? 0,
        totalCarbonPct: (m['totalCarbonPct'] as num?)?.toDouble() ?? 0,
        hCorgMolar: (m['hCorgMolar'] as num?)?.toDouble() ?? 0,
        acceptanceStatus: m['acceptanceStatus'] as String? ?? '',
        comments: m['comments'] as String? ?? '',
        enteredBy: m['enteredBy'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}

class InventoryLot {
  final String id;
  final DateTime date;
  final String inventoryLotId;
  final String linkedBiocharBatchIds;
  final String storageLocationId;
  final double beginningInventory;
  final double biocharAdded;
  final double biocharRemoved;
  final double endingInventory;
  final String reconciliationStatus; // pass / fail
  final double allocatedQuantity;
  final String allocationStatus; // unallocated / allocated / excluded
  final String comments;
  final String enteredBy;
  final DateTime createdAt;

  InventoryLot({
    required this.id,
    required this.date,
    required this.inventoryLotId,
    required this.linkedBiocharBatchIds,
    required this.storageLocationId,
    required this.beginningInventory,
    required this.biocharAdded,
    required this.biocharRemoved,
    required this.endingInventory,
    required this.reconciliationStatus,
    required this.allocatedQuantity,
    required this.allocationStatus,
    required this.comments,
    required this.enteredBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'inventoryLotId': inventoryLotId,
        'linkedBiocharBatchIds': linkedBiocharBatchIds,
        'storageLocationId': storageLocationId,
        'beginningInventory': beginningInventory,
        'biocharAdded': biocharAdded,
        'biocharRemoved': biocharRemoved,
        'endingInventory': endingInventory,
        'reconciliationStatus': reconciliationStatus,
        'allocatedQuantity': allocatedQuantity,
        'allocationStatus': allocationStatus,
        'comments': comments,
        'enteredBy': enteredBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory InventoryLot.fromMap(Map<dynamic, dynamic> m) => InventoryLot(
        id: m['id'] as String,
        date: DateTime.parse(m['date'] as String),
        inventoryLotId: m['inventoryLotId'] as String? ?? '',
        linkedBiocharBatchIds: m['linkedBiocharBatchIds'] as String? ?? '',
        storageLocationId: m['storageLocationId'] as String? ?? '',
        beginningInventory:
            (m['beginningInventory'] as num?)?.toDouble() ?? 0,
        biocharAdded: (m['biocharAdded'] as num?)?.toDouble() ?? 0,
        biocharRemoved: (m['biocharRemoved'] as num?)?.toDouble() ?? 0,
        endingInventory: (m['endingInventory'] as num?)?.toDouble() ?? 0,
        reconciliationStatus: m['reconciliationStatus'] as String? ?? '',
        allocatedQuantity:
            (m['allocatedQuantity'] as num?)?.toDouble() ?? 0,
        allocationStatus: m['allocationStatus'] as String? ?? '',
        comments: m['comments'] as String? ?? '',
        enteredBy: m['enteredBy'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}

class ApplicationEvent {
  final String id;
  final String applicationEventId;
  final DateTime applicationDate;
  final String biocharInventoryLotIds;
  final double allocatedQuantityApplied;
  final String applicationStatus; // completed / partial / excluded
  final String soilSiteId;
  final String soilSiteLocation;
  final String soilLandUseCategory;
  final String soilApplicationMethod;
  final String soilIncorporationConfirmation;
  final String nonSoilUseCategory;
  final String nonSoilProductRef;
  final String deliveryRecordRef;
  final String operatorAttestation;
  final String comments;
  final String enteredBy;
  final DateTime createdAt;

  ApplicationEvent({
    required this.id,
    required this.applicationEventId,
    required this.applicationDate,
    required this.biocharInventoryLotIds,
    required this.allocatedQuantityApplied,
    required this.applicationStatus,
    required this.soilSiteId,
    required this.soilSiteLocation,
    required this.soilLandUseCategory,
    required this.soilApplicationMethod,
    required this.soilIncorporationConfirmation,
    required this.nonSoilUseCategory,
    required this.nonSoilProductRef,
    required this.deliveryRecordRef,
    required this.operatorAttestation,
    required this.comments,
    required this.enteredBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'applicationEventId': applicationEventId,
        'applicationDate': applicationDate.toIso8601String(),
        'biocharInventoryLotIds': biocharInventoryLotIds,
        'allocatedQuantityApplied': allocatedQuantityApplied,
        'applicationStatus': applicationStatus,
        'soilSiteId': soilSiteId,
        'soilSiteLocation': soilSiteLocation,
        'soilLandUseCategory': soilLandUseCategory,
        'soilApplicationMethod': soilApplicationMethod,
        'soilIncorporationConfirmation': soilIncorporationConfirmation,
        'nonSoilUseCategory': nonSoilUseCategory,
        'nonSoilProductRef': nonSoilProductRef,
        'deliveryRecordRef': deliveryRecordRef,
        'operatorAttestation': operatorAttestation,
        'comments': comments,
        'enteredBy': enteredBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ApplicationEvent.fromMap(Map<dynamic, dynamic> m) =>
      ApplicationEvent(
        id: m['id'] as String,
        applicationEventId: m['applicationEventId'] as String? ?? '',
        applicationDate: DateTime.parse(m['applicationDate'] as String),
        biocharInventoryLotIds:
            m['biocharInventoryLotIds'] as String? ?? '',
        allocatedQuantityApplied:
            (m['allocatedQuantityApplied'] as num?)?.toDouble() ?? 0,
        applicationStatus: m['applicationStatus'] as String? ?? '',
        soilSiteId: m['soilSiteId'] as String? ?? '',
        soilSiteLocation: m['soilSiteLocation'] as String? ?? '',
        soilLandUseCategory: m['soilLandUseCategory'] as String? ?? '',
        soilApplicationMethod: m['soilApplicationMethod'] as String? ?? '',
        soilIncorporationConfirmation:
            m['soilIncorporationConfirmation'] as String? ?? '',
        nonSoilUseCategory: m['nonSoilUseCategory'] as String? ?? '',
        nonSoilProductRef: m['nonSoilProductRef'] as String? ?? '',
        deliveryRecordRef: m['deliveryRecordRef'] as String? ?? '',
        operatorAttestation: m['operatorAttestation'] as String? ?? '',
        comments: m['comments'] as String? ?? '',
        enteredBy: m['enteredBy'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}

class GlobalQA {
  final String id;
  final String monitoringPeriod; // YYYY-MM
  final String completenessConfirmation; // yes / no
  final String reviewerName;
  final DateTime dateReviewed;
  final String comments;
  final String enteredBy;
  final DateTime createdAt;

  GlobalQA({
    required this.id,
    required this.monitoringPeriod,
    required this.completenessConfirmation,
    required this.reviewerName,
    required this.dateReviewed,
    required this.comments,
    required this.enteredBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'monitoringPeriod': monitoringPeriod,
        'completenessConfirmation': completenessConfirmation,
        'reviewerName': reviewerName,
        'dateReviewed': dateReviewed.toIso8601String(),
        'comments': comments,
        'enteredBy': enteredBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GlobalQA.fromMap(Map<dynamic, dynamic> m) => GlobalQA(
        id: m['id'] as String,
        monitoringPeriod: m['monitoringPeriod'] as String? ?? '',
        completenessConfirmation:
            m['completenessConfirmation'] as String? ?? '',
        reviewerName: m['reviewerName'] as String? ?? '',
        dateReviewed: DateTime.parse(m['dateReviewed'] as String),
        comments: m['comments'] as String? ?? '',
        enteredBy: m['enteredBy'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}

class AuditControl {
  final String id;
  final String controlName;
  final String rationale;
  final String status; // pass / fail / pending
  final String evidence;
  final DateTime dateChecked;
  final String checkedBy;
  final String comments;
  final DateTime createdAt;

  AuditControl({
    required this.id,
    required this.controlName,
    required this.rationale,
    required this.status,
    required this.evidence,
    required this.dateChecked,
    required this.checkedBy,
    required this.comments,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'controlName': controlName,
        'rationale': rationale,
        'status': status,
        'evidence': evidence,
        'dateChecked': dateChecked.toIso8601String(),
        'checkedBy': checkedBy,
        'comments': comments,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AuditControl.fromMap(Map<dynamic, dynamic> m) => AuditControl(
        id: m['id'] as String,
        controlName: m['controlName'] as String? ?? '',
        rationale: m['rationale'] as String? ?? '',
        status: m['status'] as String? ?? '',
        evidence: m['evidence'] as String? ?? '',
        dateChecked: DateTime.parse(m['dateChecked'] as String),
        checkedBy: m['checkedBy'] as String? ?? '',
        comments: m['comments'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}

/// Configurable emission factors and methodological constants (admin-editable)
class EmissionFactors {
  double defaultCarbonPct;
  double permanenceFactor;
  double co2ConversionFactor;
  double gridElectricityEf; // tCO2e / MWh
  double supplementalFuelEf; // kg CO2e / liter
  double fuelUnitConversion; // t / kg

  EmissionFactors({
    this.defaultCarbonPct = 88.47,
    this.permanenceFactor = 0.9704,
    this.co2ConversionFactor = 3.67,
    this.gridElectricityEf = 0.39,
    this.supplementalFuelEf = 2.68,
    this.fuelUnitConversion = 0.001,
  });

  Map<String, dynamic> toMap() => {
        'defaultCarbonPct': defaultCarbonPct,
        'permanenceFactor': permanenceFactor,
        'co2ConversionFactor': co2ConversionFactor,
        'gridElectricityEf': gridElectricityEf,
        'supplementalFuelEf': supplementalFuelEf,
        'fuelUnitConversion': fuelUnitConversion,
      };

  factory EmissionFactors.fromMap(Map<dynamic, dynamic> m) => EmissionFactors(
        defaultCarbonPct:
            (m['defaultCarbonPct'] as num?)?.toDouble() ?? 88.47,
        permanenceFactor:
            (m['permanenceFactor'] as num?)?.toDouble() ?? 0.9704,
        co2ConversionFactor:
            (m['co2ConversionFactor'] as num?)?.toDouble() ?? 3.67,
        gridElectricityEf:
            (m['gridElectricityEf'] as num?)?.toDouble() ?? 0.39,
        supplementalFuelEf:
            (m['supplementalFuelEf'] as num?)?.toDouble() ?? 2.68,
        fuelUnitConversion:
            (m['fuelUnitConversion'] as num?)?.toDouble() ?? 0.001,
      );
}

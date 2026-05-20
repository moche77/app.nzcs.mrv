import '../models/data_models.dart';

/// VM0044 Calculation Engine — mirrors the Excel DASHBOARD sheet formulas exactly.
class CalculationEngine {
  final List<FeedstockLog> feedstock;
  final List<ProductionRun> production;
  final List<QualityBatch> quality;
  final List<InventoryLot> inventory;
  final List<ApplicationEvent> applications;
  final EmissionFactors factors;

  CalculationEngine({
    required this.feedstock,
    required this.production,
    required this.quality,
    required this.inventory,
    required this.applications,
    required this.factors,
  });

  // === Core Volumes (Dry Basis) ===

  /// Total Feedstock Accepted (t dry) — SUMIFS on accepted loads
  double get totalFeedstockAccepted => feedstock
      .where((f) => f.acceptanceStatus.toLowerCase() == 'accepted')
      .fold(0.0, (s, f) => s + f.netWeightDry);

  /// Total Biochar Produced (t dry)
  double get totalBiocharProduced =>
      production.fold(0.0, (s, p) => s + p.biocharProducedDry);

  /// Total Biochar in Inventory (Ending) (t dry)
  double get totalBiocharInventory =>
      inventory.fold(0.0, (s, l) => s + l.endingInventory);

  /// Total Quantity Allocated (t dry)
  double get totalAllocated => inventory
      .where((l) => l.allocationStatus.toLowerCase() == 'allocated')
      .fold(0.0, (s, l) => s + l.allocatedQuantity);

  /// Total Quantity Applied/Used (t dry)
  double get totalApplied => applications
      .where((a) => a.applicationStatus.toLowerCase() == 'completed')
      .fold(0.0, (s, a) => s + a.allocatedQuantityApplied);

  // === Quality & Integrity Gates ===

  int get qualitySamplesLogged => quality.length;

  int get qualityAccepted => quality
      .where((q) => q.acceptanceStatus.toLowerCase() == 'accepted')
      .length;

  double get qualityAcceptanceRate =>
      qualitySamplesLogged > 0 ? qualityAccepted / qualitySamplesLogged : 0;

  int get inventoryReconciliationFailures => inventory
      .where((l) => l.reconciliationStatus.toLowerCase() == 'fail')
      .length;

  // === tCO2e Removal Estimate ===

  /// Basis Quantity (t dry) = Total Applied
  double get basisQuantity => totalApplied;

  /// Weighted Avg Total Carbon (%) — SUMPRODUCT(C, qty)/SUM(C)
  /// Excel formula: SUMPRODUCT('3_Quality'!C:C, '3_Quality'!I:I)/SUM('3_Quality'!C:C)
  /// Where C = batch quantity, I = total carbon %
  double get weightedAvgCarbon {
    final totalQty = quality.fold(0.0, (s, q) => s + q.batchQuantityDry);
    if (totalQty <= 0) return factors.defaultCarbonPct;
    final weighted = quality.fold(
        0.0, (s, q) => s + (q.batchQuantityDry * q.totalCarbonPct));
    return weighted / totalQty;
  }

  /// Carbon Stored (t C) = basis × (avgC / 100)
  double get carbonStored => basisQuantity * (weightedAvgCarbon / 100.0);

  /// CO2e gross (tCO2e) = Carbon Stored × 3.67
  double get co2eGross => carbonStored * factors.co2ConversionFactor;

  /// CO2e net permanence-adjusted (tCO2e) = gross × permanence
  double get co2eNet => co2eGross * factors.permanenceFactor;

  // === Net Climate Benefit ===

  /// Scope 2 Electricity = Σ(kWh)/1000 × Grid EF
  double get scope2Emissions {
    final totalKwh = production.fold(0.0, (s, p) => s + p.electricityKwh);
    return (totalKwh / 1000.0) * factors.gridElectricityEf;
  }

  /// Supplemental Fuel Emissions = Σ(liters) × fuelEF × unitConversion
  double get supplementalFuelEmissions {
    final totalLiters =
        production.fold(0.0, (s, p) => s + p.supplementalFuelLiters);
    return totalLiters * factors.supplementalFuelEf * factors.fuelUnitConversion;
  }

  double get totalDeduction => scope2Emissions + supplementalFuelEmissions;

  /// NET CLIMATE BENEFIT = co2eNet - totalDeduction
  double get netClimateBenefit => co2eNet - totalDeduction;

  // === Integrity Red Flags ===

  String get appliedVsAllocatedFlag =>
      totalApplied > totalAllocated ? 'RED FLAG' : 'OK';

  String get allocatedVsProducedFlag =>
      totalAllocated > totalBiocharProduced ? 'RED FLAG' : 'OK';

  String get producedVsFeedstockFlag =>
      totalBiocharProduced > totalFeedstockAccepted ? 'REVIEW' : 'OK';

  // === Monthly Rollup ===

  /// Returns monthly net climate benefit for the period 2025-01 through 2026-12
  List<MonthlyRollup> getMonthlyRollups({String? filter}) {
    final months = <String>[];
    for (var y = 2025; y <= 2026; y++) {
      for (var m = 1; m <= 12; m++) {
        months.add('$y-${m.toString().padLeft(2, '0')}');
      }
    }
    return months.map((mp) {
      final parts = mp.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0, 23, 59, 59);

      // Filtering: if filter is set, only compute the matching month
      if (filter != null && filter.isNotEmpty && filter != mp) {
        return MonthlyRollup(
          period: mp,
          appliedQuantity: 0,
          weightedCarbonPct: 0,
          removals: 0,
          scope2: 0,
          fuel: 0,
          netBenefit: 0,
        );
      }

      final monthApps = applications.where((a) =>
          a.applicationStatus.toLowerCase() == 'completed' &&
          !a.applicationDate.isBefore(start) &&
          !a.applicationDate.isAfter(end));
      final appliedQty =
          monthApps.fold(0.0, (s, a) => s + a.allocatedQuantityApplied);

      // Weighted carbon by batch quantity for batches sampled in this month
      final monthQuality = quality.where((q) =>
          !q.samplingDate.isBefore(start) && !q.samplingDate.isAfter(end));
      double weightedC;
      final qtySum =
          monthQuality.fold(0.0, (s, q) => s + q.batchQuantityDry);
      if (qtySum > 0) {
        final weighted = monthQuality.fold(
            0.0, (s, q) => s + (q.batchQuantityDry * q.totalCarbonPct));
        weightedC = weighted / qtySum;
      } else {
        weightedC = weightedAvgCarbon;
      }

      final removals = appliedQty *
          (weightedC / 100.0) *
          factors.co2ConversionFactor *
          factors.permanenceFactor;

      final monthProd = production.where((p) =>
          !p.productionDate.isBefore(start) &&
          !p.productionDate.isAfter(end));
      final monthKwh = monthProd.fold(0.0, (s, p) => s + p.electricityKwh);
      final monthFuel =
          monthProd.fold(0.0, (s, p) => s + p.supplementalFuelLiters);

      final scope2 = (monthKwh / 1000.0) * factors.gridElectricityEf;
      final fuel =
          monthFuel * factors.supplementalFuelEf * factors.fuelUnitConversion;

      return MonthlyRollup(
        period: mp,
        appliedQuantity: appliedQty,
        weightedCarbonPct: weightedC,
        removals: removals,
        scope2: scope2,
        fuel: fuel,
        netBenefit: removals - scope2 - fuel,
      );
    }).toList();
  }

  Map<String, double> getAnnualRollups() {
    final months = getMonthlyRollups();
    final annual = <String, double>{};
    for (final m in months) {
      final year = m.period.split('-')[0];
      annual[year] = (annual[year] ?? 0) + m.netBenefit;
    }
    return annual;
  }
}

class MonthlyRollup {
  final String period;
  final double appliedQuantity;
  final double weightedCarbonPct;
  final double removals;
  final double scope2;
  final double fuel;
  final double netBenefit;

  MonthlyRollup({
    required this.period,
    required this.appliedQuantity,
    required this.weightedCarbonPct,
    required this.removals,
    required this.scope2,
    required this.fuel,
    required this.netBenefit,
  });
}

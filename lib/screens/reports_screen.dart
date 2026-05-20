import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/calculation_engine.dart';
import '../services/pdf_report_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _generatingPdf = false;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final engine = CalculationEngine(
      feedstock: data.getFeedstockLogs(),
      production: data.getProductionRuns(),
      quality: data.getQualityBatches(),
      inventory: data.getInventoryLots(),
      applications: data.getApplicationEvents(),
      factors: data.emissionFactors,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Export')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _summaryCard(engine),
            const SizedBox(height: 16),
            _pdfReportCard(context, engine, data),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                'CSV EXPORTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            _exportTile(context, 'Executive Summary (CSV)',
                'Dashboard totals and tCO₂e calculations',
                () => _exportSummary(context, engine)),
            _exportTile(context, 'Feedstock Log (CSV)',
                '${data.getFeedstockLogs().length} records',
                () => _exportFeedstock(context, data)),
            _exportTile(context, 'Production Runs (CSV)',
                '${data.getProductionRuns().length} records',
                () => _exportProduction(context, data)),
            _exportTile(context, 'Quality Batches (CSV)',
                '${data.getQualityBatches().length} records',
                () => _exportQuality(context, data)),
            _exportTile(context, 'Inventory & Allocation (CSV)',
                '${data.getInventoryLots().length} records',
                () => _exportInventory(context, data)),
            _exportTile(context, 'Application Events (CSV)',
                '${data.getApplicationEvents().length} records',
                () => _exportApplication(context, data)),
            _exportTile(context, 'Monthly Net Climate Benefit (CSV)',
                'YYYY-MM rollup analytics',
                () => _exportMonthly(context, engine)),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'CSV exports copy content to clipboard for spreadsheet pasting.\nPDF reports open native print/share dialog.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(CalculationEngine e) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Period Snapshot',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _row('Feedstock Accepted',
                '${Fmt.num2(e.totalFeedstockAccepted)} t dry'),
            _row('Biochar Produced',
                '${Fmt.num2(e.totalBiocharProduced)} t dry'),
            _row('Applied / Used', '${Fmt.num2(e.totalApplied)} t dry'),
            _row('Weighted Avg C', Fmt.pct(e.weightedAvgCarbon)),
            _row('CO₂e (net, perm-adj)',
                '${Fmt.num2(e.co2eNet)} tCO₂e'),
            _row('Net Climate Benefit',
                '${Fmt.num2(e.netClimateBenefit)} tCO₂e'),
          ],
        ),
      ),
    );
  }

  Widget _pdfReportCard(
      BuildContext context, CalculationEngine engine, DataService data) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_outlined,
                      color: AppTheme.primaryGreen, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('VM0044 Verifier Submittal Package',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(
                          'Audit-grade PDF with all 7 modules, calculations, attestation',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generatingPdf
                    ? null
                    : () => _generatePdf(context, engine, data),
                icon: _generatingPdf
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_outlined),
                label: Text(_generatingPdf
                    ? 'GENERATING...'
                    : 'GENERATE & PRINT PDF REPORT'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context, CalculationEngine engine,
      DataService data) async {
    setState(() => _generatingPdf = true);
    try {
      final auth = context.read<AuthService>();
      final userLabel = auth.currentUser != null
          ? '${auth.currentUser!.fullName} (${auth.currentUser!.username})'
          : 'unknown';
      await PdfReportService.printReport(
        engine: engine,
        feedstock: data.getFeedstockLogs(),
        production: data.getProductionRuns(),
        quality: data.getQualityBatches(),
        inventory: data.getInventoryLots(),
        applications: data.getApplicationEvents(),
        qa: data.getGlobalQA(),
        audit: data.getAuditControls(),
        generatedBy: userLabel,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF generation failed: $e'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(l, style: const TextStyle(fontSize: 13))),
            Text(v,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _exportTile(
      BuildContext context, String title, String subtitle, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.file_download_outlined,
            color: AppTheme.primaryGreen),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<void> _copyToClipboard(
      BuildContext context, String csv, String name) async {
    await Clipboard.setData(ClipboardData(text: csv));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name copied to clipboard'),
        backgroundColor: AppTheme.successGreen,
      ),
    );
  }

  void _exportSummary(BuildContext context, CalculationEngine e) {
    final rows = [
      ['Metric', 'Value', 'Unit'],
      ['Total Feedstock Accepted', e.totalFeedstockAccepted, 't dry'],
      ['Total Biochar Produced', e.totalBiocharProduced, 't dry'],
      ['Total Inventory (Ending)', e.totalBiocharInventory, 't dry'],
      ['Total Allocated', e.totalAllocated, 't dry'],
      ['Total Applied', e.totalApplied, 't dry'],
      ['Weighted Avg Carbon', e.weightedAvgCarbon, '%'],
      ['Carbon Stored', e.carbonStored, 't C'],
      ['CO2e Gross', e.co2eGross, 'tCO2e'],
      ['CO2e Net (perm-adjusted)', e.co2eNet, 'tCO2e'],
      ['Scope 2 Electricity', e.scope2Emissions, 'tCO2e'],
      ['Supplemental Fuel', e.supplementalFuelEmissions, 'tCO2e'],
      ['NET CLIMATE BENEFIT', e.netClimateBenefit, 'tCO2e'],
    ];
    _copyToClipboard(context, const ListToCsvConverter().convert(rows),
        'Executive Summary');
  }

  void _exportFeedstock(BuildContext context, DataService d) {
    final rows = [
      ['Date', 'Load ID', 'Category', 'Supplier', 'BOL', 'Net (t dry)',
          'Acceptance', 'Eligibility'],
      ...d.getFeedstockLogs().map((l) => [
            Fmt.date(l.date),
            l.loadId,
            l.category,
            l.supplier,
            l.bolNumber,
            l.netWeightDry,
            l.acceptanceStatus,
            l.eligibilityStatus,
          ]),
    ];
    _copyToClipboard(context, const ListToCsvConverter().convert(rows),
        'Feedstock CSV');
  }

  void _exportProduction(BuildContext context, DataService d) {
    final rows = [
      ['Date', 'Run ID', 'Unit', 'Input (t)', 'Reactor T (°C)', 'Residence (min)',
          'kWh', 'Fuel (L)', 'Output (t)', 'Yield'],
      ...d.getProductionRuns().map((r) => [
            Fmt.date(r.productionDate),
            r.runId,
            r.unitLineId,
            r.feedstockInputDry,
            r.reactorTemperature,
            r.residenceTimeMin,
            r.electricityKwh,
            r.supplementalFuelLiters,
            r.biocharProducedDry,
            r.massYield,
          ]),
    ];
    _copyToClipboard(context, const ListToCsvConverter().convert(rows),
        'Production CSV');
  }

  void _exportQuality(BuildContext context, DataService d) {
    final rows = [
      ['Sampling Date', 'Lot ID', 'Quantity (t)', 'Moisture %', 'Ash %',
          'Carbon %', 'H/Corg', 'COA Ref', 'Acceptance'],
      ...d.getQualityBatches().map((q) => [
            Fmt.date(q.samplingDate),
            q.batchLotId,
            q.batchQuantityDry,
            q.moisturePct,
            q.ashPct,
            q.totalCarbonPct,
            q.hCorgMolar,
            q.labCoaRef,
            q.acceptanceStatus,
          ]),
    ];
    _copyToClipboard(context, const ListToCsvConverter().convert(rows),
        'Quality CSV');
  }

  void _exportInventory(BuildContext context, DataService d) {
    final rows = [
      ['Date', 'Lot ID', 'Storage', 'Begin', 'Added', 'Removed', 'Ending',
          'Reconciliation', 'Allocated', 'Status'],
      ...d.getInventoryLots().map((l) => [
            Fmt.date(l.date),
            l.inventoryLotId,
            l.storageLocationId,
            l.beginningInventory,
            l.biocharAdded,
            l.biocharRemoved,
            l.endingInventory,
            l.reconciliationStatus,
            l.allocatedQuantity,
            l.allocationStatus,
          ]),
    ];
    _copyToClipboard(context, const ListToCsvConverter().convert(rows),
        'Inventory CSV');
  }

  void _exportApplication(BuildContext context, DataService d) {
    final rows = [
      ['Date', 'Event ID', 'Lots', 'Quantity (t)', 'Status', 'Site/Use',
          'Method', 'Attestation'],
      ...d.getApplicationEvents().map((e) => [
            Fmt.date(e.applicationDate),
            e.applicationEventId,
            e.biocharInventoryLotIds,
            e.allocatedQuantityApplied,
            e.applicationStatus,
            e.soilSiteId.isNotEmpty
                ? '${e.soilSiteId} (${e.soilLandUseCategory})'
                : e.nonSoilUseCategory,
            e.soilApplicationMethod,
            e.operatorAttestation,
          ]),
    ];
    _copyToClipboard(context, const ListToCsvConverter().convert(rows),
        'Application CSV');
  }

  void _exportMonthly(BuildContext context, CalculationEngine e) {
    final months = e.getMonthlyRollups();
    final rows = [
      ['Period', 'Applied (t)', 'Avg C %', 'Removals (tCO2e)',
          'Scope 2 (tCO2e)', 'Fuel (tCO2e)', 'Net Benefit (tCO2e)'],
      ...months.map((m) => [
            m.period,
            m.appliedQuantity,
            m.weightedCarbonPct,
            m.removals,
            m.scope2,
            m.fuel,
            m.netBenefit,
          ]),
    ];
    _copyToClipboard(context, const ListToCsvConverter().convert(rows),
        'Monthly Rollup CSV');
  }
}

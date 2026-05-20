import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/data_models.dart';
import '../services/calculation_engine.dart';
import '../utils/formatters.dart';

/// Generates audit-grade PDF reports for Verra VM0044 verifier submittal packages.
class PdfReportService {
  static const PdfColor primaryGreen = PdfColor.fromInt(0xFF1B5E20);
  static const PdfColor emerald = PdfColor.fromInt(0xFF2E7D32);
  static const PdfColor surfaceGray = PdfColor.fromInt(0xFFF5F7F5);
  static const PdfColor textPrimary = PdfColor.fromInt(0xFF1A1A1A);
  static const PdfColor textSecondary = PdfColor.fromInt(0xFF5F6368);
  static const PdfColor dividerGray = PdfColor.fromInt(0xFFE0E0E0);
  static const PdfColor goldAccent = PdfColor.fromInt(0xFFFFB300);
  static const PdfColor dangerRed = PdfColor.fromInt(0xFFC62828);

  /// Generates the comprehensive verifier submittal package.
  static Future<pw.Document> buildExecutiveReport({
    required CalculationEngine engine,
    required List<FeedstockLog> feedstock,
    required List<ProductionRun> production,
    required List<QualityBatch> quality,
    required List<InventoryLot> inventory,
    required List<ApplicationEvent> applications,
    required List<GlobalQA> qa,
    required List<AuditControl> audit,
    required String generatedBy,
    String? facilityName,
  }) async {
    final doc = pw.Document(
      title: 'NerZero MRV — VM0044 Verifier Submittal',
      author: 'NerZero MRV Application',
      creator: 'Net Zero Carbon Solutions Ohio LLC',
      subject: 'VM0044 Audit-Grade MRV Report',
    );

    final facility = facilityName ?? 'Net Zero Carbon Solutions Ohio LLC';
    final generated = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
        header: (ctx) => _pageHeader(facility),
        footer: (ctx) => _pageFooter(ctx, generated),
        build: (ctx) => [
          _coverBlock(facility, generated, generatedBy),
          pw.SizedBox(height: 16),
          _executiveSummarySection(engine),
          pw.SizedBox(height: 14),
          _coreVolumesSection(engine),
          pw.SizedBox(height: 14),
          _qualityGatesSection(engine),
          pw.SizedBox(height: 14),
          _co2RemovalSection(engine),
          pw.SizedBox(height: 14),
          _netBenefitSection(engine),
          pw.SizedBox(height: 14),
          _redFlagSection(engine),
          pw.SizedBox(height: 14),
          _emissionFactorsSection(engine.factors),
          pw.NewPage(),
          _monthlyRollupSection(engine),
          pw.NewPage(),
          _feedstockSection(feedstock),
          pw.NewPage(),
          _productionSection(production),
          pw.NewPage(),
          _qualitySection(quality),
          pw.NewPage(),
          _inventorySection(inventory),
          pw.NewPage(),
          _applicationSection(applications),
          if (qa.isNotEmpty) ...[
            pw.NewPage(),
            _qaSection(qa),
          ],
          if (audit.isNotEmpty) ...[
            pw.NewPage(),
            _auditSection(audit),
          ],
          pw.NewPage(),
          _attestationPage(generatedBy, generated),
        ],
      ),
    );
    return doc;
  }

  static pw.Widget _pageHeader(String facility) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: primaryGreen, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('NerZero MRV — VM0044 Submittal Package',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryGreen)),
              pw.Text(facility,
                  style: const pw.TextStyle(
                      fontSize: 8.5, color: textSecondary)),
            ],
          ),
          pw.Text('CONFIDENTIAL — VERIFIER USE',
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: dangerRed)),
        ],
      ),
    );
  }

  static pw.Widget _pageFooter(pw.Context ctx, DateTime generated) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: dividerGray),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated ${Fmt.dateTime(generated)}',
              style:
                  const pw.TextStyle(fontSize: 8, color: textSecondary)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style:
                  const pw.TextStyle(fontSize: 8, color: textSecondary)),
        ],
      ),
    );
  }

  static pw.Widget _coverBlock(
      String facility, DateTime generated, String generatedBy) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [primaryGreen, emerald],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('VERRA VM0044 — UNIFIED MRV SUBMITTAL',
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5)),
          pw.SizedBox(height: 4),
          pw.Text('Audit-Grade Carbon Removal Documentation Package',
              style: pw.TextStyle(
                  color: PdfColors.grey300, fontSize: 11)),
          pw.SizedBox(height: 14),
          pw.Container(
              height: 1, color: PdfColors.white.shade(0.3)),
          pw.SizedBox(height: 10),
          _coverRow('Facility', facility),
          _coverRow('Methodology', 'Verra VM0044 (Biochar Carbon Removal)'),
          _coverRow('Report Generated', Fmt.dateTime(generated)),
          _coverRow('Generated By', generatedBy),
          _coverRow('Mass Basis', 'Dry Basis (per VM0044 §5.1)'),
        ],
      ),
    );
  }

  static pw.Widget _coverRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(label,
                style: pw.TextStyle(
                    color: PdfColors.grey300, fontSize: 9.5)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title, [String? subtitle]) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: primaryGreen, width: 1.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryGreen)),
          if (subtitle != null)
            pw.Text(subtitle,
                style: const pw.TextStyle(
                    fontSize: 9, color: textSecondary)),
        ],
      ),
    );
  }

  static pw.Widget _executiveSummarySection(CalculationEngine e) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('1. Executive Summary',
            'Headline metrics — auto-derived from logged activity data'),
        pw.Row(
          children: [
            pw.Expanded(
                child: _kpiBox('NET CLIMATE BENEFIT',
                    Fmt.num2(e.netClimateBenefit), 'tCO₂e', primaryGreen)),
            pw.SizedBox(width: 8),
            pw.Expanded(
                child: _kpiBox('PERMANENCE-ADJ. REMOVALS',
                    Fmt.num2(e.co2eNet), 'tCO₂e', emerald)),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(
                child: _kpiBox('FEEDSTOCK ACCEPTED',
                    Fmt.num2(e.totalFeedstockAccepted), 't dry', textPrimary)),
            pw.SizedBox(width: 8),
            pw.Expanded(
                child: _kpiBox('BIOCHAR APPLIED',
                    Fmt.num2(e.totalApplied), 't dry', textPrimary)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _kpiBox(
      String label, String value, String unit, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: surfaceGray,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: dividerGray),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: textSecondary,
                  letterSpacing: 0.4)),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: color)),
          pw.Text(unit,
              style:
                  const pw.TextStyle(fontSize: 9, color: textSecondary)),
        ],
      ),
    );
  }

  static pw.Widget _coreVolumesSection(CalculationEngine e) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('2. Core Volumes (Dry Basis)',
            'Mass-balance metrics — VM0044 §5.1 compliant'),
        _dataTable([
          ['Metric', 'Value', 'Unit'],
          ['Total Feedstock Accepted',
              Fmt.num2(e.totalFeedstockAccepted), 't dry'],
          ['Total Biochar Produced',
              Fmt.num2(e.totalBiocharProduced), 't dry'],
          ['Total Biochar Inventory (Ending)',
              Fmt.num2(e.totalBiocharInventory), 't dry'],
          ['Total Quantity Allocated',
              Fmt.num2(e.totalAllocated), 't dry'],
          ['Total Quantity Applied/Used',
              Fmt.num2(e.totalApplied), 't dry'],
          [
            'Mass Yield Ratio',
            e.totalFeedstockAccepted > 0
                ? Fmt.pctRatio(e.totalBiocharProduced /
                    e.totalFeedstockAccepted)
                : '—',
            'biochar/feedstock'
          ],
        ]),
      ],
    );
  }

  static pw.Widget _qualityGatesSection(CalculationEngine e) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('3. Quality & Integrity Gates',
            'Lab-derived stability indicators'),
        _dataTable([
          ['Metric', 'Value', 'Unit'],
          ['Quality Samples Logged',
              e.qualitySamplesLogged.toString(), 'count'],
          ['Quality Accepted', e.qualityAccepted.toString(), 'count'],
          [
            'Quality Acceptance Rate',
            e.qualitySamplesLogged > 0
                ? Fmt.pctRatio(e.qualityAcceptanceRate)
                : '—',
            ''
          ],
          ['Inventory Reconciliation Failures',
              e.inventoryReconciliationFailures.toString(), 'count'],
        ]),
      ],
    );
  }

  static pw.Widget _co2RemovalSection(CalculationEngine e) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('4. tCO₂e Removal Estimate',
            'Logged mass × weighted lab carbon × stoichiometric conversion'),
        _dataTable([
          ['Calculation Step', 'Value', 'Unit'],
          ['Basis Quantity (Applied)', Fmt.num2(e.basisQuantity), 't dry'],
          ['Weighted Avg Total Carbon',
              Fmt.pct(e.weightedAvgCarbon), '%'],
          ['Carbon Stored', Fmt.num2(e.carbonStored), 't C'],
          ['CO₂e (gross, × 3.67)', Fmt.num2(e.co2eGross), 'tCO₂e'],
          ['Permanence Factor',
              Fmt.pctRatio(e.factors.permanenceFactor), 'fraction'],
          ['CO₂e Net (perm-adjusted)', Fmt.num2(e.co2eNet), 'tCO₂e'],
        ]),
      ],
    );
  }

  static pw.Widget _netBenefitSection(CalculationEngine e) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('5. Net Climate Benefit',
            'Removals minus Scope 2 + supplemental fuel emissions'),
        _dataTable([
          ['Component', 'Value', 'Unit'],
          ['Net CO₂e Removals', Fmt.num2(e.co2eNet), 'tCO₂e'],
          ['Scope 2 Electricity (deduction)',
              Fmt.num2(e.scope2Emissions), 'tCO₂e'],
          ['Supplemental Fuel (deduction)',
              Fmt.num2(e.supplementalFuelEmissions), 'tCO₂e'],
          ['Total Deduction', Fmt.num2(e.totalDeduction), 'tCO₂e'],
          ['NET CLIMATE BENEFIT', Fmt.num2(e.netClimateBenefit), 'tCO₂e'],
        ], highlightLast: true),
      ],
    );
  }

  static pw.Widget _redFlagSection(CalculationEngine e) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('6. Integrity Red-Flag Checks',
            'Automated cross-module reconciliation'),
        _dataTable([
          ['Check', 'Status', ''],
          ['Applied > Allocated', e.appliedVsAllocatedFlag, ''],
          ['Allocated > Produced', e.allocatedVsProducedFlag, ''],
          ['Produced > Feedstock (Yield > 100%)',
              e.producedVsFeedstockFlag, ''],
        ], statusCol: 1),
      ],
    );
  }

  static pw.Widget _emissionFactorsSection(EmissionFactors f) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('7. Emission Factors (Verifier-Controlled)',
            'Locked per VM0044 PD agreement'),
        _dataTable([
          ['Factor', 'Value', 'Unit'],
          ['Default Total Carbon (%)',
              f.defaultCarbonPct.toStringAsFixed(2), '%'],
          ['Permanence Factor',
              f.permanenceFactor.toStringAsFixed(4), 'fraction'],
          ['C → CO₂ Conversion (44/12)',
              f.co2ConversionFactor.toStringAsFixed(2), ''],
          ['Grid Electricity EF',
              f.gridElectricityEf.toStringAsFixed(3), 'tCO₂e/MWh'],
          ['Supplemental Fuel EF',
              f.supplementalFuelEf.toStringAsFixed(3), 'kg CO₂e/L'],
          ['Fuel Unit Conversion',
              f.fuelUnitConversion.toStringAsFixed(4), 't/kg'],
        ]),
      ],
    );
  }

  static pw.Widget _monthlyRollupSection(CalculationEngine e) {
    final all = e.getMonthlyRollups();
    final nonZero = all.where((m) => m.netBenefit.abs() > 0.001).toList();
    final showRows = nonZero.isEmpty ? all.take(12).toList() : nonZero;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('8. Monthly Net Climate Benefit Rollup',
            'Auto-computed analytics 2025-01 through 2026-12'),
        _dataTable([
          ['Period', 'Applied (t)', 'Avg C %', 'Removals (tCO₂e)',
              'Scope 2 (tCO₂e)', 'Fuel (tCO₂e)', 'Net (tCO₂e)'],
          ...showRows.map((m) => [
                m.period,
                Fmt.num2(m.appliedQuantity),
                Fmt.pct(m.weightedCarbonPct),
                Fmt.num2(m.removals),
                Fmt.num2(m.scope2),
                Fmt.num2(m.fuel),
                Fmt.num2(m.netBenefit),
              ]),
        ], compact: true),
        pw.SizedBox(height: 12),
        pw.Text('Annual Rollups:',
            style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        ...e.getAnnualRollups().entries.map((entry) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(
                '   Year ${entry.key}: ${Fmt.num2(entry.value)} tCO₂e',
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold,
                    color: primaryGreen),
              ),
            )),
      ],
    );
  }

  static pw.Widget _feedstockSection(List<FeedstockLog> logs) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('9. Feedstock Logs (Sheet 1)',
            '${logs.length} record(s) — incoming feedstock with traceability'),
        if (logs.isEmpty)
          _emptyNote()
        else
          _dataTable([
            ['Date', 'Load ID', 'Category', 'Supplier', 'Net (t dry)',
                'Acceptance'],
            ...logs.map((l) => [
                  Fmt.date(l.date),
                  l.loadId,
                  l.category,
                  l.supplier,
                  Fmt.num2(l.netWeightDry),
                  l.acceptanceStatus,
                ]),
          ], compact: true, statusCol: 5),
      ],
    );
  }

  static pw.Widget _productionSection(List<ProductionRun> runs) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('10. Biochar Production Runs (Sheet 2)',
            '${runs.length} record(s) — pyrolysis conversion + mass balance'),
        if (runs.isEmpty)
          _emptyNote()
        else
          _dataTable([
            ['Date', 'Run ID', 'Input (t)', 'Reactor T (°C)',
                'kWh', 'Output (t)', 'Yield'],
            ...runs.map((r) => [
                  Fmt.date(r.productionDate),
                  r.runId,
                  Fmt.num2(r.feedstockInputDry),
                  r.reactorTemperature.toStringAsFixed(0),
                  Fmt.num2(r.electricityKwh),
                  Fmt.num2(r.biocharProducedDry),
                  Fmt.pctRatio(r.massYield),
                ]),
          ], compact: true),
      ],
    );
  }

  static pw.Widget _qualitySection(List<QualityBatch> batches) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('11. Biochar Quality & Sampling (Sheet 3)',
            '${batches.length} record(s) — lab COA carbon stability'),
        if (batches.isEmpty)
          _emptyNote()
        else
          _dataTable([
            ['Sampled', 'Batch ID', 'Qty (t)', 'Moisture %', 'Ash %',
                'Carbon %', 'COA Ref', 'Status'],
            ...batches.map((b) => [
                  Fmt.date(b.samplingDate),
                  b.batchLotId,
                  Fmt.num2(b.batchQuantityDry),
                  Fmt.pct(b.moisturePct),
                  Fmt.pct(b.ashPct),
                  Fmt.pct(b.totalCarbonPct),
                  b.labCoaRef,
                  b.acceptanceStatus,
                ]),
          ], compact: true, statusCol: 7),
      ],
    );
  }

  static pw.Widget _inventorySection(List<InventoryLot> lots) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('12. Inventory & Allocation (Sheet 4)',
            '${lots.length} record(s) — chain of custody'),
        if (lots.isEmpty)
          _emptyNote()
        else
          _dataTable([
            ['Date', 'Lot ID', 'Begin', 'Added', 'Removed', 'Ending',
                'Allocated', 'Status'],
            ...lots.map((l) => [
                  Fmt.date(l.date),
                  l.inventoryLotId,
                  Fmt.num2(l.beginningInventory),
                  Fmt.num2(l.biocharAdded),
                  Fmt.num2(l.biocharRemoved),
                  Fmt.num2(l.endingInventory),
                  Fmt.num2(l.allocatedQuantity),
                  l.allocationStatus,
                ]),
          ], compact: true, statusCol: 7),
      ],
    );
  }

  static pw.Widget _applicationSection(List<ApplicationEvent> events) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('13. Application Events (Sheet 5)',
            '${events.length} record(s) — physical placement evidence'),
        if (events.isEmpty)
          _emptyNote()
        else
          _dataTable([
            ['Date', 'Event ID', 'Qty (t)', 'Status', 'Site/Use',
                'Method'],
            ...events.map((e) => [
                  Fmt.date(e.applicationDate),
                  e.applicationEventId,
                  Fmt.num2(e.allocatedQuantityApplied),
                  e.applicationStatus,
                  e.soilSiteId.isNotEmpty
                      ? '${e.soilSiteId} (${e.soilLandUseCategory})'
                      : e.nonSoilUseCategory,
                  e.soilApplicationMethod,
                ]),
          ], compact: true, statusCol: 3),
      ],
    );
  }

  static pw.Widget _qaSection(List<GlobalQA> qas) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('14. Global QA / Governance (Sheet 6)',
            '${qas.length} record(s) — period-level reviewer attestation'),
        _dataTable([
          ['Period', 'Completeness', 'Reviewer', 'Date Reviewed',
              'Comments'],
          ...qas.map((q) => [
                q.monitoringPeriod,
                q.completenessConfirmation,
                q.reviewerName,
                Fmt.date(q.dateReviewed),
                q.comments,
              ]),
        ], compact: true),
      ],
    );
  }

  static pw.Widget _auditSection(List<AuditControl> controls) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('15. Audit Controls (Sheet 7)',
            '${controls.length} record(s) — verification hygiene'),
        _dataTable([
          ['Control', 'Status', 'Checked By', 'Date', 'Evidence'],
          ...controls.map((c) => [
                c.controlName,
                c.status,
                c.checkedBy,
                Fmt.date(c.dateChecked),
                c.evidence,
              ]),
        ], compact: true, statusCol: 1),
      ],
    );
  }

  static pw.Widget _attestationPage(String generatedBy, DateTime generated) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Verifier Attestation',
            'Signature block for verification submittal'),
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: dividerGray),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'I, the undersigned verifier, attest that I have reviewed the data presented in this MRV submittal package. The figures herein are derived exclusively from logged activity data within the NerZero MRV system, computed per the VM0044 methodology and emission factors disclosed in Section 7.',
                style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.4),
              ),
              pw.SizedBox(height: 24),
              pw.Row(children: [
                pw.Expanded(child: _signatureLine('Verifier Name')),
                pw.SizedBox(width: 18),
                pw.Expanded(child: _signatureLine('Date')),
              ]),
              pw.SizedBox(height: 22),
              pw.Row(children: [
                pw.Expanded(child: _signatureLine('Verifier Signature')),
                pw.SizedBox(width: 18),
                pw.Expanded(child: _signatureLine('Verification Body')),
              ]),
              pw.SizedBox(height: 22),
              _signatureLine('Comments / Findings'),
              pw.SizedBox(height: 26),
              pw.Container(height: 1, color: dividerGray),
              pw.SizedBox(height: 24),
            ],
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: surfaceGray,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Document Provenance',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(
                  'Generated by: $generatedBy   ·   Generated at: ${Fmt.dateTime(generated)}',
                  style: const pw.TextStyle(
                      fontSize: 9, color: textSecondary)),
              pw.Text(
                  'System: NerZero MRV (Phase 1) — Net Zero Carbon Solutions Ohio LLC',
                  style: const pw.TextStyle(
                      fontSize: 9, color: textSecondary)),
              pw.Text(
                  'Methodology: Verra VM0044 (Biochar Carbon Removal)',
                  style: const pw.TextStyle(
                      fontSize: 9, color: textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _signatureLine(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          height: 26,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: textSecondary, width: 0.6),
            ),
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(label,
            style:
                const pw.TextStyle(fontSize: 8.5, color: textSecondary)),
      ],
    );
  }

  static pw.Widget _emptyNote() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: surfaceGray,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text('No records logged in this module.',
          style: pw.TextStyle(
              fontSize: 9.5,
              color: textSecondary,
              fontStyle: pw.FontStyle.italic)),
    );
  }

  static pw.Widget _dataTable(
    List<List<String>> rows, {
    bool compact = false,
    bool highlightLast = false,
    int? statusCol,
  }) {
    final headerStyle = pw.TextStyle(
        fontSize: compact ? 8 : 9.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white);
    final cellStyle =
        pw.TextStyle(fontSize: compact ? 8 : 9.5, color: textPrimary);
    final highlightStyle = pw.TextStyle(
        fontSize: compact ? 9 : 10.5,
        fontWeight: pw.FontWeight.bold,
        color: primaryGreen);

    return pw.Table(
      border: pw.TableBorder.all(color: dividerGray, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: primaryGreen),
          children: rows.first
              .map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6, vertical: 5),
                  child: pw.Text(c, style: headerStyle)))
              .toList(),
        ),
        for (var i = 1; i < rows.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: highlightLast && i == rows.length - 1
                  ? const PdfColor.fromInt(0xFFE8F5E9)
                  : (i % 2 == 0 ? surfaceGray : PdfColors.white),
            ),
            children: [
              for (var j = 0; j < rows[i].length; j++)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  child: statusCol != null && j == statusCol
                      ? _statusChip(rows[i][j])
                      : pw.Text(
                          rows[i][j],
                          style: highlightLast && i == rows.length - 1
                              ? highlightStyle
                              : cellStyle,
                        ),
                ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _statusChip(String status) {
    PdfColor bg;
    PdfColor fg;
    switch (status.toUpperCase()) {
      case 'OK':
      case 'PASS':
      case 'ACCEPTED':
      case 'COMPLETED':
      case 'ALLOCATED':
      case 'YES':
        bg = const PdfColor.fromInt(0xFFE8F5E9);
        fg = primaryGreen;
        break;
      case 'REVIEW':
      case 'PENDING':
      case 'PARTIAL':
      case 'UNALLOCATED':
        bg = const PdfColor.fromInt(0xFFFFF3E0);
        fg = goldAccent;
        break;
      case 'RED FLAG':
      case 'FAIL':
      case 'REJECTED':
      case 'EXCLUDED':
      case 'NO':
        bg = const PdfColor.fromInt(0xFFFFEBEE);
        fg = dangerRed;
        break;
      default:
        bg = surfaceGray;
        fg = textSecondary;
    }
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(status.toUpperCase(),
          style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: fg)),
    );
  }

  /// Convenience method to return PDF bytes for sharing/printing.
  static Future<Uint8List> generateBytes({
    required CalculationEngine engine,
    required List<FeedstockLog> feedstock,
    required List<ProductionRun> production,
    required List<QualityBatch> quality,
    required List<InventoryLot> inventory,
    required List<ApplicationEvent> applications,
    required List<GlobalQA> qa,
    required List<AuditControl> audit,
    required String generatedBy,
    String? facilityName,
  }) async {
    final doc = await buildExecutiveReport(
      engine: engine,
      feedstock: feedstock,
      production: production,
      quality: quality,
      inventory: inventory,
      applications: applications,
      qa: qa,
      audit: audit,
      generatedBy: generatedBy,
      facilityName: facilityName,
    );
    return doc.save();
  }

  /// Show native print/share dialog with the generated report.
  static Future<void> printReport({
    required CalculationEngine engine,
    required List<FeedstockLog> feedstock,
    required List<ProductionRun> production,
    required List<QualityBatch> quality,
    required List<InventoryLot> inventory,
    required List<ApplicationEvent> applications,
    required List<GlobalQA> qa,
    required List<AuditControl> audit,
    required String generatedBy,
    String? facilityName,
  }) async {
    final bytes = await generateBytes(
      engine: engine,
      feedstock: feedstock,
      production: production,
      quality: quality,
      inventory: inventory,
      applications: applications,
      qa: qa,
      audit: audit,
      generatedBy: generatedBy,
      facilityName: facilityName,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'NerZero_MRV_VM0044_Submittal_${Fmt.date(DateTime.now())}.pdf',
    );
  }
}

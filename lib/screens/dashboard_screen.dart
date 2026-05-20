import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/data_service.dart';
import '../services/calculation_engine.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import 'emission_factors_screen.dart';

class DashboardScreen extends StatefulWidget {
  final bool isAdmin;
  const DashboardScreen({super.key, this.isAdmin = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _periodFilter = '';

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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerCard(context, engine),
            const SizedBox(height: 18),
            const SectionHeader(
              title: 'Core Volumes (Dry Basis)',
              subtitle: 'Mass-balance metrics derived from logged activity',
              icon: Icons.scale_outlined,
            ),
            _kpiGrid([
              KpiCard(
                label: 'Feedstock Accepted',
                value: Fmt.num2(engine.totalFeedstockAccepted),
                unit: 't dry',
                icon: Icons.local_shipping_outlined,
              ),
              KpiCard(
                label: 'Biochar Produced',
                value: Fmt.num2(engine.totalBiocharProduced),
                unit: 't dry',
                icon: Icons.factory_outlined,
                accentColor: AppTheme.emerald,
              ),
              KpiCard(
                label: 'Inventory (Ending)',
                value: Fmt.num2(engine.totalBiocharInventory),
                unit: 't dry',
                icon: Icons.inventory_2_outlined,
              ),
              KpiCard(
                label: 'Allocated',
                value: Fmt.num2(engine.totalAllocated),
                unit: 't dry',
                icon: Icons.assignment_turned_in_outlined,
              ),
              KpiCard(
                label: 'Applied / Used',
                value: Fmt.num2(engine.totalApplied),
                unit: 't dry',
                icon: Icons.agriculture_outlined,
                accentColor: AppTheme.goldAccent,
              ),
              KpiCard(
                label: 'Yield Ratio',
                value: engine.totalFeedstockAccepted > 0
                    ? Fmt.pctRatio(engine.totalBiocharProduced /
                        engine.totalFeedstockAccepted)
                    : '—',
                unit: 'biochar / feedstock',
                icon: Icons.percent_outlined,
              ),
            ]),
            const SizedBox(height: 18),
            const SectionHeader(
              title: 'Quality & Integrity Gates',
              subtitle: 'Lab-derived stability indicators',
              icon: Icons.verified_outlined,
            ),
            _qualityGatesCard(engine),
            const SizedBox(height: 18),
            const SectionHeader(
              title: 'tCO₂e Removal Estimate',
              subtitle: 'Logged mass × weighted lab carbon × stoichiometry',
              icon: Icons.cloud_outlined,
            ),
            _co2Card(engine, data),
            const SizedBox(height: 18),
            const SectionHeader(
              title: 'Net Climate Benefit',
              subtitle: 'Removals minus Scope 2 + supplemental fuel',
              icon: Icons.eco_outlined,
            ),
            _netBenefitCard(engine),
            const SizedBox(height: 18),
            const SectionHeader(
              title: 'Integrity Red-Flag Checks',
              subtitle: 'Automated cross-module reconciliation',
              icon: Icons.flag_outlined,
            ),
            _redFlagCard(engine),
            const SizedBox(height: 18),
            const SectionHeader(
              title: 'Monthly Net Climate Benefit',
              subtitle: 'Auto-rollup analytics (2025–2026)',
              icon: Icons.calendar_month_outlined,
            ),
            _monthlyChartCard(engine),
            const SizedBox(height: 12),
            _annualSummaryCard(engine),
            if (widget.isAdmin) ...[
              const SizedBox(height: 18),
              _emissionFactorsButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _headerCard(BuildContext context, CalculationEngine engine) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryGreen, AppTheme.emerald],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dashboard_outlined, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Executive Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Auto-Calculated · VM0044 Methodology',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _bigStat(
                  'NET CLIMATE BENEFIT',
                  Fmt.num2(engine.netClimateBenefit),
                  'tCO₂e',
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              Expanded(
                child: _bigStat(
                  'PERMANENCE-ADJ. REMOVALS',
                  Fmt.num2(engine.co2eNet),
                  'tCO₂e',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bigStat(String label, String value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _kpiGrid(List<Widget> children) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: children,
    );
  }

  Widget _qualityGatesCard(CalculationEngine e) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _row('Quality Samples Logged',
                e.qualitySamplesLogged.toString(), 'count'),
            const Divider(height: 18),
            _row('Quality Accepted', e.qualityAccepted.toString(), 'count'),
            const Divider(height: 18),
            _row(
              'Quality Acceptance Rate',
              e.qualitySamplesLogged > 0
                  ? Fmt.pctRatio(e.qualityAcceptanceRate)
                  : '—',
              '',
            ),
            const Divider(height: 18),
            _row(
              'Inventory Reconciliation Failures',
              e.inventoryReconciliationFailures.toString(),
              'count',
              danger: e.inventoryReconciliationFailures > 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _co2Card(CalculationEngine e, DataService d) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _row('Basis Quantity (Applied)',
                Fmt.num2(e.basisQuantity), 't dry'),
            const Divider(height: 18),
            _row('Weighted Avg Total Carbon',
                Fmt.pct(e.weightedAvgCarbon), '%'),
            const Divider(height: 18),
            _row('Carbon Stored', Fmt.num2(e.carbonStored), 't C'),
            const Divider(height: 18),
            _row('CO₂e (gross)', Fmt.num2(e.co2eGross), 'tCO₂e'),
            const Divider(height: 18),
            _row(
              'Permanence Factor',
              Fmt.pctRatio(d.emissionFactors.permanenceFactor),
              'fraction',
            ),
            const Divider(height: 18),
            _row('CO₂e (net, perm-adj)', Fmt.num2(e.co2eNet), 'tCO₂e',
                highlight: true),
          ],
        ),
      ),
    );
  }

  Widget _netBenefitCard(CalculationEngine e) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _row('Net CO₂e Removals', Fmt.num2(e.co2eNet), 'tCO₂e'),
            const Divider(height: 18),
            _row('Scope 2 Electricity',
                Fmt.num2(e.scope2Emissions), 'tCO₂e', danger: true),
            const Divider(height: 18),
            _row('Supplemental Fuel',
                Fmt.num2(e.supplementalFuelEmissions), 'tCO₂e', danger: true),
            const Divider(height: 18),
            _row('Total Deduction', Fmt.num2(e.totalDeduction), 'tCO₂e'),
            const Divider(height: 18),
            _row('NET CLIMATE BENEFIT',
                Fmt.num2(e.netClimateBenefit), 'tCO₂e',
                highlight: true),
          ],
        ),
      ),
    );
  }

  Widget _redFlagCard(CalculationEngine e) {
    final checks = [
      ('Applied > Allocated', e.appliedVsAllocatedFlag),
      ('Allocated > Produced', e.allocatedVsProducedFlag),
      ('Produced > Feedstock (Yield > 100%)', e.producedVsFeedstockFlag),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (var i = 0; i < checks.length; i++) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      checks[i].$1,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                  StatusBadge(status: checks[i].$2),
                ],
              ),
              if (i < checks.length - 1) const Divider(height: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _monthlyChartCard(CalculationEngine e) {
    final all = e.getMonthlyRollups();
    final nonZero = all.where((m) => m.netBenefit.abs() > 0.001).toList();
    final showMonths = nonZero.isEmpty ? all.take(12).toList() : nonZero;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Monthly Net Climate Benefit (tCO₂e)',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                DropdownButton<String>(
                  value: _periodFilter.isEmpty ? null : _periodFilter,
                  hint: const Text('All Months', style: TextStyle(fontSize: 12)),
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All Months')),
                    ...all.map((m) => DropdownMenuItem(
                          value: m.period,
                          child: Text(Fmt.monthLabel(m.period),
                              style: const TextStyle(fontSize: 12)),
                        )),
                  ],
                  onChanged: (v) => setState(() => _periodFilter = v ?? ''),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 220,
              child: nonZero.isEmpty
                  ? const Center(
                      child: Text(
                        'No data logged yet — chart populates as data is entered',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: [
                          for (var i = 0; i < showMonths.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: showMonths[i].netBenefit,
                                  color: showMonths[i].netBenefit >= 0
                                      ? AppTheme.primaryGreen
                                      : AppTheme.dangerRed,
                                  width: 14,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ],
                            ),
                        ],
                        gridData: const FlGridData(show: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (v, _) => Text(
                                v.toStringAsFixed(0),
                                style: const TextStyle(fontSize: 9),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (v, _) {
                                final i = v.toInt();
                                if (i < 0 || i >= showMonths.length) {
                                  return const SizedBox();
                                }
                                return RotatedBox(
                                  quarterTurns: -1,
                                  child: Text(
                                    showMonths[i].period,
                                    style: const TextStyle(fontSize: 8.5),
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _annualSummaryCard(CalculationEngine e) {
    final annual = e.getAnnualRollups();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Annual Rollup',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ...annual.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text('Year ${entry.key}',
                          style: const TextStyle(fontSize: 13)),
                      const Spacer(),
                      Text(
                        '${Fmt.num2(entry.value)} tCO₂e',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _emissionFactorsButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmissionFactorsScreen()),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppTheme.primaryGreen),
        ),
        icon: const Icon(Icons.tune, color: AppTheme.primaryGreen),
        label: const Text(
          'CONFIGURE EMISSION FACTORS (ADMIN)',
          style: TextStyle(color: AppTheme.primaryGreen),
        ),
      ),
    );
  }

  Widget _row(String label, String value, String unit,
      {bool highlight = false, bool danger = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 16 : 14,
            fontWeight: FontWeight.w700,
            color: danger
                ? AppTheme.warningAmber
                : (highlight
                    ? AppTheme.primaryGreen
                    : AppTheme.textPrimary),
          ),
        ),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(unit,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ],
    );
  }
}

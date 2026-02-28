import 'package:flutter/material.dart';
import '../models/teachers.dart';
import '../l10n/app_localizations.dart';
import '../services/db_service.dart';
import 'MesEtudiantsPage.dart';
import 'package:pie_chart/pie_chart.dart';
export 'DashboardPage.dart';

class ProfHomePage extends StatefulWidget {
  final Teacher user;
  const ProfHomePage({super.key, required this.user});

  @override
  State<ProfHomePage> createState() => _ProfHomePageState();
}

class _ProfHomePageState extends State<ProfHomePage> {
  Map<String, int> stats = {'green': 0, 'orange': 0, 'red': 0};

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() async {
    final s = await DBService.getRiskStatsByTeacher(widget.user.id!);
    setState(() {
      stats = s;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    double deviceWidth = MediaQuery.of(context).size.width;
    double contentWidth = deviceWidth > 900 ? 800 : deviceWidth * 0.95;

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: contentWidth,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${AppLocalizations.of(context)!.welcome} 👋 \${widget.user.firstName}",
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 25),

                loading
                    ? const Center(child: CircularProgressIndicator())
                    : PieChart(
                        dataMap: stats.map(
                          (key, value) => MapEntry(key, value.toDouble()),
                        ),
                        colorList: [Colors.green, Colors.orange, Colors.red],
                        chartType: ChartType.ring,
                        chartRadius: 150,
                        legendOptions: const LegendOptions(
                          showLegendsInRow: false,
                          legendPosition: LegendPosition.right,
                        ),
                        chartValuesOptions: const ChartValuesOptions(
                          showChartValuesInPercentage: true,
                        ),
                      ),

                const SizedBox(height: 25),
                actionButton(
                  icon: Icons.group,
                  label: AppLocalizations.of(context)!.myStudents,
                  color: Colors.deepOrange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MesEtudiantsPage(teacherId: widget.user.id!),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 35, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

class AdminStatisticsPage extends StatefulWidget {
  const AdminStatisticsPage({super.key});

  @override
  State<AdminStatisticsPage> createState() => _AdminStatisticsPageState();
}

class _AdminStatisticsPageState extends State<AdminStatisticsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

  // Time period filter
  String _selectedPeriod = 'daily';

  // Stats data
  int _totalOrders = 0;
  double _totalRevenue = 0;
  Map<String, double> _dailyRevenue = {};
  Map<String, double> _weeklyRevenue = {};
  Map<String, double> _monthlyRevenue = {};

  // Date range for filtering
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  // Loading state
  bool _isLoading = true;
  bool _isExporting = false;

  // Popular menu items
  Map<String, dynamic>? _popularMenus;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    _loadPopularMenus();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _fetchTotalOrders();
      await _fetchRevenue();
    } catch (e) {
      debugPrint("Error loading statistics: $e");
      _showSnackBar("Terjadi kesalahan saat memuat data statistik", true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchTotalOrders() async {
    final orderQuery = await _firestore
        .collection('orders')
        .where('status', whereIn: ['completed', 'ready'])
        .where('orderTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
        .where('orderTime', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
        .get();

    setState(() {
      _totalOrders = orderQuery.docs.length;
    });
  }

  Future<void> _fetchRevenue() async {
    final orderQuery = await _firestore
        .collection('orders')
        .where('paymentStatus', isEqualTo: 'paid')
        .where('orderTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
        .where('orderTime', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
        .get();

    double totalRevenue = 0;
    Map<String, double> dailyData = {};
    Map<String, double> weeklyData = {};
    Map<String, double> monthlyData = {};

    for (var doc in orderQuery.docs) {
      final data = doc.data();
      final amount = (data['totalAmount'] ?? 0).toDouble();
      final orderTime = (data['orderTime'] as Timestamp).toDate();

      // Calculate total revenue
      totalRevenue += amount;

      // Daily data (group by day)
      final dayKey = DateFormat('yyyy-MM-dd').format(orderTime);
      dailyData[dayKey] = (dailyData[dayKey] ?? 0) + amount;

      // Weekly data (group by week)
      final weekKey =
          '${orderTime.year}-W${(orderTime.day + orderTime.month * 30) ~/ 7}';
      weeklyData[weekKey] = (weeklyData[weekKey] ?? 0) + amount;

      // Monthly data (group by month)
      final monthKey = DateFormat('yyyy-MM').format(orderTime);
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + amount;
    }

    setState(() {
      _totalRevenue = totalRevenue;
      _dailyRevenue = dailyData;
      _weeklyRevenue = weeklyData;
      _monthlyRevenue = monthlyData;
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.orange,
            colorScheme: const ColorScheme.light(primary: Colors.orange),
            buttonTheme:
                const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });

      // Reload stats with new date range
      _loadStatistics();
    }
  }

  Future<void> _exportToPdf() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final pdf = pw.Document();

      // Add header
      pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                    level: 0,
                    child: pw.Text('Laporan Pemasukan RM Solideo Kuliner',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Paragraph(
                    text:
                        'Periode: ${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}'),
                pw.SizedBox(height: 20),

                // Summary
                pw.Header(level: 1, child: pw.Text('Ringkasan')),
                pw.Paragraph(text: 'Total Pesanan: $_totalOrders'),
                pw.Paragraph(
                    text:
                        'Total Pendapatan: ${currencyFormatter.format(_totalRevenue)}'),
                pw.SizedBox(height: 30),

                // Revenue details
                pw.Header(level: 1, child: pw.Text('Detail Pendapatan')),

                // Create revenue table based on selected period
                _createPdfRevenueTable(),
              ],
            );
          }));

      // Save PDF to file
      final output = await getTemporaryDirectory();
      final file = File(
          '${output.path}/solideo_laporan_${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Open PDF file
      await OpenFile.open(file.path);

      _showSnackBar('Laporan berhasil diekspor ke PDF', false);
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      _showSnackBar('Gagal mengekspor laporan ke PDF', true);
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  pw.Widget _createPdfRevenueTable() {
    // Choose data based on period
    Map<String, double> revenueData;
    String title;

    switch (_selectedPeriod) {
      case 'daily':
        revenueData = _dailyRevenue;
        title = 'Pendapatan Harian';
        break;
      case 'weekly':
        revenueData = _weeklyRevenue;
        title = 'Pendapatan Mingguan';
        break;
      case 'monthly':
      default:
        revenueData = _monthlyRevenue;
        title = 'Pendapatan Bulanan';
        break;
    }

    // Sort data by date
    List<MapEntry<String, double>> sortedEntries = revenueData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Paragraph(text: title),
          pw.SizedBox(height: 10),
          pw.Table(border: pw.TableBorder.all(), columnWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(2),
          }, children: [
            // Table header
            pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Periode',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Pendapatan',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ]),

            // Table rows
            ...sortedEntries.map((entry) {
              String displayDate;

              if (_selectedPeriod == 'daily') {
                // Convert YYYY-MM-DD to readable format
                final date = DateFormat('yyyy-MM-dd').parse(entry.key);
                displayDate = DateFormat('dd MMM yyyy').format(date);
              } else if (_selectedPeriod == 'weekly') {
                displayDate =
                    'Minggu ${entry.key.split('-W')[1]} ${entry.key.split('-')[0]}';
              } else {
                // Convert YYYY-MM to readable format
                final parts = entry.key.split('-');
                displayDate =
                    '${_getMonthName(int.parse(parts[1]))} ${parts[0]}';
              }

              return pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(displayDate),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(currencyFormatter.format(entry.value)),
                ),
              ]);
            }).toList(),

            // Total row
            pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Total',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                        currencyFormatter.format(sortedEntries.fold(
                            0.0, (sum, entry) => sum + entry.value)),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ])
          ])
        ]);
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return months[month];
  }

  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchPopularMenus() async {
    final menuCollection = _firestore.collection('menu_items');
    final orderQuery = await _firestore
        .collection('orders')
        .where('status', whereIn: ['completed', 'ready'])
        .where('orderTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
        .where('orderTime', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
        .get();

    // Menu item counter
    Map<String, int> menuOrders = {};

    // Process all orders to count menu items
    for (var doc in orderQuery.docs) {
      final data = doc.data();
      final items = data['items'] as List<dynamic>?;

      if (items != null) {
        for (var item in items) {
          String? menuName;
          String? menuId = item['menuId'] as String?;

          // If menuId is null, use name directly
          if (menuId == null) {
            menuName = item['name'] as String?;
          } else {
            // Otherwise get name from menu_items collection
            try {
              final menuDoc =
                  await _firestore.collection('menu_items').doc(menuId).get();
              if (menuDoc.exists) {
                menuName = menuDoc.data()?['name'] as String?;
              }
            } catch (e) {
              debugPrint('Error fetching menu item: $e');
            }
          }

          if (menuName != null) {
            menuOrders[menuName] = (menuOrders[menuName] ?? 0) + 1;
          }
        }
      }
    }
    // Convert to sorted list to find top 5 popular menu items
    List<MapEntry<String, int>> sortedMenus = menuOrders.entries.toList();
    sortedMenus.sort((a, b) =>
        b.value.compareTo(a.value)); // Sort in descending order (most to least)

    // Get list of staple items to exclude
    Set<String> stapleItems = {'Air Putih', 'Nasi Putih', 'Sambal'};

    // Filter out staple items
    var filteredMenus =
        sortedMenus.where((menu) => !stapleItems.contains(menu.key)).toList();

    // Get top 5 popular menus
    List<Map<String, dynamic>> topFiveMenus = [];

    // Take up to 5 most popular items
    for (var i = 0; i < filteredMenus.length && i < 5; i++) {
      topFiveMenus.add({
        'name': filteredMenus[i].key,
        'orders': filteredMenus[i].value,
        'rank': i + 1, // Add rank for display purposes
      });
    }

    return {
      'topFiveMenus': topFiveMenus,
    };
  }

  Future<void> _loadPopularMenus() async {
    try {
      final popularMenus = await _fetchPopularMenus();
      setState(() {
        _popularMenus = popularMenus;
      });
    } catch (e) {
      debugPrint('Error fetching popular menus: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildStatisticCards(),
        const SizedBox(height: 24),
        _buildPeriodSelector(),
        const SizedBox(height: 16),
        _buildChart(),
        const SizedBox(height: 16),
        _buildDataListView(),
        const SizedBox(height: 24),
        _buildPopularMenuSection(), // Added popular menu section
        const SizedBox(height: 24),
        _buildExportSection(),
      ],
    );
  }

  Widget _buildHeader() {
    return Card(
      color: Colors.deepOrange.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, size: 32, color: Colors.deepOrange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dashboard Statistik',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Data ${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _selectDateRange(context),
                icon: const Icon(Icons.date_range, size: 18),
                label: const Text('Filter Tanggal'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticCards() {
    return Column(
      children: [
        _buildStatCard(
          'Total Pesanan',
          _totalOrders.toString(),
          Icons.shopping_bag_outlined,
          Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Total Pendapatan',
          currencyFormatter.format(_totalRevenue),
          Icons.payments_outlined,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tampilkan Pendapatan Sebagai:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPeriodButton('daily', 'Harian'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPeriodButton('weekly', 'Mingguan'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPeriodButton('monthly', 'Bulanan'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String period, String label) {
    final isSelected = _selectedPeriod == period;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.deepOrange : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black,
        elevation: isSelected ? 3 : 1,
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      onPressed: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      child: Text(label),
    );
  }

  Widget _buildChart() {
    Map<String, double> currentData;

    // Select data based on period
    switch (_selectedPeriod) {
      case 'daily':
        currentData = _dailyRevenue;
        break;
      case 'weekly':
        currentData = _weeklyRevenue;
        break;
      case 'monthly':
      default:
        currentData = _monthlyRevenue;
        break;
    }

    if (currentData.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('Tidak ada data untuk ditampilkan'),
          ),
        ),
      );
    }

    // Sort by date
    List<MapEntry<String, double>> sortedEntries = currentData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Prepare chart data
    final List<BarChartGroupData> barGroups = [];

    final double maxValue = sortedEntries.fold(
        0.0,
        (double max, MapEntry<String, double> entry) =>
            entry.value > max ? entry.value : max);

    for (int i = 0; i < sortedEntries.length; i++) {
      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: sortedEntries[i].value,
            color: Colors.deepOrange,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ],
      ));
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grafik Pendapatan ${_selectedPeriod == 'daily' ? 'Harian' : _selectedPeriod == 'weekly' ? 'Mingguan' : 'Bulanan'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Fixed height SizedBox for the chart - most important fix
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue * 1.2,
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value >= 0 && value < sortedEntries.length) {
                            final key = sortedEntries[value.toInt()].key;
                            String text;

                            // Format display text based on period
                            if (_selectedPeriod == 'daily') {
                              final date = DateFormat('yyyy-MM-dd').parse(key);
                              text = DateFormat('dd/MM').format(date);
                            } else if (_selectedPeriod == 'weekly') {
                              text = 'W${key.split('-W')[1]}';
                            } else {
                              final parts = key.split('-');
                              text = '${parts[1]}/${parts[0].substring(2)}';
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(text,
                                  style: const TextStyle(fontSize: 10)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataListView() {
    Map<String, double> currentData;

    // Select data based on period
    switch (_selectedPeriod) {
      case 'daily':
        currentData = _dailyRevenue;
        break;
      case 'weekly':
        currentData = _weeklyRevenue;
        break;
      case 'monthly':
      default:
        currentData = _monthlyRevenue;
        break;
    }

    if (currentData.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort by date
    List<MapEntry<String, double>> sortedEntries = currentData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final total = sortedEntries.fold(
        0.0, (double sum, MapEntry<String, double> entry) => sum + entry.value);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Detail Pendapatan ${_selectedPeriod == 'daily' ? 'Harian' : _selectedPeriod == 'weekly' ? 'Mingguan' : 'Bulanan'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),

          // Header row
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Periode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Pendapatan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          // List items - Using a Column of Rows instead of ListView for better layout
          Column(
            children: [
              for (var index = 0; index < sortedEntries.length; index++) ...[
                _buildDataRow(sortedEntries[index]),
                if (index < sortedEntries.length - 1) const Divider(height: 1),
              ],
            ],
          ),

          // Total row
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    currencyFormatter.format(total),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build a single data row
  Widget _buildDataRow(MapEntry<String, double> entry) {
    String displayDate;

    if (_selectedPeriod == 'daily') {
      final date = DateFormat('yyyy-MM-dd').parse(entry.key);
      displayDate = DateFormat('dd MMM yyyy').format(date);
    } else if (_selectedPeriod == 'weekly') {
      displayDate =
          'Minggu ${entry.key.split('-W')[1]} ${entry.key.split('-')[0]}';
    } else {
      final parts = entry.key.split('-');
      displayDate = '${_getMonthName(int.parse(parts[1]))} ${parts[0]}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(displayDate),
          ),
          Expanded(
            flex: 2,
            child: Text(
              currencyFormatter.format(entry.value),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ekspor Laporan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _isExporting ? null : _exportToPdf,
                icon: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_isExporting ? 'Mengekspor...' : 'Ekspor ke PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularMenuSection() {
    if (_popularMenus == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final topFiveMenus = _popularMenus?['topFiveMenus'] as List<dynamic>?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TOP 5 Menu yang Paling Banyak Dipesan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (topFiveMenus != null && topFiveMenus.isNotEmpty)
              Column(
                children: [
                  ...topFiveMenus
                      .map((menu) => Column(
                            children: [
                              _buildMenuCard(
                                rank: menu['rank'] as int,
                                menuName: menu['name'] as String,
                                orders: menu['orders'] as int,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ))
                      .toList(),
                ],
              )
            else
              const Text(
                'Belum ada data menu yang dipesan',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required int rank,
    required String menuName,
    required int orders,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  menuName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$orders Pesanan',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.trending_up,
            color: Colors.green,
            size: 20,
          ),
        ],
      ),
    );
  }
}

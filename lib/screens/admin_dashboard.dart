import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/claim.dart';
import '../models/reports.dart';
import '../models/reviews.dart';
import '../models/category.dart';
import '../services/firestore_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const _ClaimModerationTab(),
    const _ReportManagementTab(),
    const _CategoryManagementTab(),
    const _StatisticsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _tabs[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.verified_user_outlined), selectedIcon: Icon(Icons.verified_user), label: 'Claims'),
          NavigationDestination(icon: Icon(Icons.report_outlined), selectedIcon: Icon(Icons.report), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.category_outlined), selectedIcon: Icon(Icons.category), label: 'Categories'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Stats'),
        ],
      ),
    );
  }
}

// --- TAB 1: KIỂM DUYỆT CLAIM ---
class _ClaimModerationTab extends StatefulWidget {
  const _ClaimModerationTab();
  @override
  State<_ClaimModerationTab> createState() => _ClaimModerationTabState();
}

class _ClaimModerationTabState extends State<_ClaimModerationTab> {
  final FirestoreService _fs = FirestoreService();
  bool _loading = true;
  List<ClaimModel> _claims = [];

  @override
  void initState() { super.initState(); _load(); }
  
  Future<void> _load() async {
    setState(() => _loading = true);
    _claims = await _fs.getPendingClaims();
    setState(() => _loading = false);
  }

  void _showDetails(ClaimModel claim) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Claim Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('User ID: ${claim.userId}'),
              Text('Restaurant ID: ${claim.restaurantId}'),
              const SizedBox(height: 16),
              const Text('Proof Images:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (claim.proofImages.isEmpty) const Text('No images') else
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: claim.proofImages.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(imageUrl: claim.proofImages[i], width: 150, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => _process(claim, 'rejected'), child: const Text('Reject'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: () => _process(claim, 'approved'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text('Approve'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _process(ClaimModel claim, String status) async {
    Navigator.pop(context);
    setState(() => _loading = true);
    await _fs.processClaim(claim.id, status, claim.userId, claim.restaurantId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_claims.isEmpty) return const Center(child: Text('No pending claims'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _claims.length,
      itemBuilder: (_, i) => Card(
        child: ListTile(
          title: Text('Claim: ${_claims[i].restaurantId}'),
          subtitle: Text('User: ${_claims[i].userId}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showDetails(_claims[i]),
        ),
      ),
    );
  }
}

// --- TAB 2: QUẢN LÝ BÁO CÁO REVIEW ---
class _ReportManagementTab extends StatefulWidget {
  const _ReportManagementTab();
  @override
  State<_ReportManagementTab> createState() => _ReportManagementTabState();
}

class _ReportManagementTabState extends State<_ReportManagementTab> {
  final FirestoreService _fs = FirestoreService();
  bool _loading = true;
  List<ReportModel> _reports = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _reports = await _fs.getPendingReports();
    setState(() => _loading = false);
  }

  void _showDetails(ReportModel report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FutureBuilder<ReviewModel?>(
        future: _fs.getReview(report.reviewId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
          final rv = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reason: ${report.reason}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                const Divider(),
                Text('Comment: ${rv.comment}'),
                const SizedBox(height: 10),
                if (rv.photoUrls.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: rv.photoUrls.length,
                      itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(right: 8), child: CachedNetworkImage(imageUrl: rv.photoUrls[i], width: 100, fit: BoxFit.cover)),
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(onPressed: () => _resolve(report.id, rv.id!, 'dismiss'), child: const Text('Dismiss')),
                    ElevatedButton(onPressed: () => _resolve(report.id, rv.id!, 'hide'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text('Hide')),
                    ElevatedButton(onPressed: () => _resolve(report.id, rv.id!, 'delete'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _resolve(String rid, String rvid, String action) async {
    Navigator.pop(context);
    setState(() => _loading = true);
    await _fs.resolveReport(rid, rvid, action);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_reports.isEmpty) return const Center(child: Text('No reports'));
    return ListView.builder(
      itemCount: _reports.length,
      itemBuilder: (_, i) => ListTile(
        title: Text(_reports[i].reason),
        subtitle: Text('Review ID: ${_reports[i].reviewId}'),
        onTap: () => _showDetails(_reports[i]),
      ),
    );
  }
}

// --- TAB 3: DANH MỤC MÓN ĂN ---
class _CategoryManagementTab extends StatefulWidget {
  const _CategoryManagementTab();
  @override
  State<_CategoryManagementTab> createState() => _CategoryManagementTabState();
}

class _CategoryManagementTabState extends State<_CategoryManagementTab> {
  final FirestoreService _fs = FirestoreService();
  final _labelCtrl = TextEditingController();

  void _openDialog([CategoryModel? cat]) {
    if (cat != null) _labelCtrl.text = cat.label; else _labelCtrl.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cat == null ? 'Add Category' : 'Edit Category'),
        content: TextField(controller: _labelCtrl, decoration: const InputDecoration(labelText: 'Label')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_labelCtrl.text.isEmpty) return;
              final newCat = CategoryModel(id: cat?.id ?? '', label: _labelCtrl.text);
              cat == null ? await _fs.addCategory(newCat) : await _fs.updateCategory(newCat);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<CategoryModel>>(
        stream: _fs.getCategoriesStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (_, i) {
              final c = snapshot.data![i];
              return ListTile(
                title: Text(c.label),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _openDialog(c)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _fs.deleteCategory(c.id)),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _openDialog(), child: const Icon(Icons.add)),
    );
  }
}

// --- TAB 4: THỐNG KÊ ---
class _StatisticsTab extends StatefulWidget {
  const _StatisticsTab();
  @override
  State<_StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<_StatisticsTab> {
  final FirestoreService _fs = FirestoreService();
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    _data = await _fs.getReviewGrowthData();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text('Review Growth', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          AspectRatio(
            aspectRatio: 1.5,
            child: LineChart(LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: _data.map((e) => FlSpot(e['index'], e['count'].toDouble())).toList(),
                  isCurved: true, color: Colors.orange, barWidth: 4,
                )
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                  int i = v.toInt();
                  return Text(i >= 0 && i < _data.length ? _data[i]['month'] : '', style: const TextStyle(fontSize: 10));
                })),
              ),
            )),
          ),
        ],
      ),
    );
  }
}

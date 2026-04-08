import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/claim.dart';
import '../models/category.dart';
import '../models/restaurants.dart';
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
        title: const Text('Quản trị'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _tabs[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.verified_user_outlined), selectedIcon: Icon(Icons.verified_user), label: 'Nhận quán'),
          NavigationDestination(icon: Icon(Icons.report_outlined), selectedIcon: Icon(Icons.report), label: 'Báo cáo '),
          NavigationDestination(icon: Icon(Icons.category_outlined), selectedIcon: Icon(Icons.category), label: 'Danh mục'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Thống kê'),
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

  void _showDetails(EnrichedClaimModel enriched) {
    final claim = enriched.claim;
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
              const Text('Chi tiết yêu cầu nhận quán', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Người dùng: ${enriched.userName}'),
              Text('Tên quán: ${enriched.restaurantName}'),
              if (claim.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Ghi chú: ${claim.note}'),
              ],
              const SizedBox(height: 16),
              const Text('Ảnh minh chứng:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (claim.proofImages.isEmpty) const Text('Không có ảnh') else
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
                  Expanded(child: OutlinedButton(onPressed: () => _process(claim, 'rejected'), child: const Text('Từ chối'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: () => _process(claim, 'approved'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text('Duyệt'))),
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
    await _fs.processClaim(claim.id, status, claim.userId, claim.restaurantId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EnrichedClaimModel>>(
      stream: _fs.getPendingClaimsEnrichedStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Không thể tải danh sách claim: ${snapshot.error}'),
            ),
          );
        }

        final claims = snapshot.data ?? const <EnrichedClaimModel>[];
        if (claims.isEmpty) {
          return const Center(child: Text('Không có yêu cầu nhận quán đang chờ duyệt'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: claims.length,
          itemBuilder: (_, i) {
            final enriched = claims[i];
            return Card(
              elevation: 0.8,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Icon(Icons.store_mall_directory_outlined, color: Colors.orange.shade800),
                ),
                title: Text(
                  enriched.restaurantName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('Người gửi: ${enriched.userName}'),
                trailing: Icon(Icons.chevron_right, color: Colors.orange.shade700),
                onTap: () => _showDetails(enriched),
              ),
            );
          },
        );
      },
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

  void _showDetails(EnrichedReportModel enriched) {
    final report = enriched.report;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lý do báo cáo: ${report.reason}',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Người báo cáo: ${enriched.reporterName}'),
            Text('Người đánh giá: ${enriched.reviewerName}'),
            Text('Nhà hàng: ${enriched.restaurantName}'),
            const Divider(height: 24),
            Text(
              'Nội dung đánh giá: ${enriched.review?.comment ?? 'Không có dữ liệu'}',
            ),
            const SizedBox(height: 10),
            if ((enriched.review?.photoUrls ?? const <String>[]).isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: enriched.review!.photoUrls.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CachedNetworkImage(
                      imageUrl: enriched.review!.photoUrls[i],
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => _resolve(report.id, report.reviewId, 'dismiss'),
                  child: const Text('Bỏ qua'),
                ),
                ElevatedButton(
                  onPressed: () => _resolve(report.id, report.reviewId, 'hide'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Ẩn'),
                ),
                ElevatedButton(
                  onPressed: () => _resolve(report.id, report.reviewId, 'delete'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Xóa'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _resolve(String rid, String rvid, String action) async {
    Navigator.pop(context);
    await _fs.resolveReport(rid, rvid, action);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EnrichedReportModel>>(
      stream: _fs.getPendingReportsEnrichedStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Không thể tải danh sách báo cáo: ${snapshot.error}'),
            ),
          );
        }

        final reports = snapshot.data ?? const <EnrichedReportModel>[];
        if (reports.isEmpty) return const Center(child: Text('Không có báo cáo chờ xử lý'));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: reports.length,
          itemBuilder: (_, i) {
            final enriched = reports[i];
            return Card(
              elevation: 0.8,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade50,
                  child: Icon(Icons.report_gmailerrorred, color: Colors.red.shade400),
                ),
                title: Text(
                  enriched.report.reason,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Báo cáo: ${enriched.reporterName}\nĐánh giá: ${enriched.reviewerName}\nNhà hàng: ${enriched.restaurantName}',
                ),
                isThreeLine: true,
                trailing: Icon(Icons.chevron_right, color: Colors.orange.shade700),
                onTap: () => _showDetails(enriched),
              ),
            );
          },
        );
      },
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
        title: Text(cat == null ? 'Thêm' : 'Sửa'),
        content: TextField(controller: _labelCtrl, decoration: const InputDecoration(labelText: 'Nhãn')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (_labelCtrl.text.isEmpty) return;
              final newCat = CategoryModel(id: cat?.id ?? '', label: _labelCtrl.text);
              cat == null ? await _fs.addCategory(newCat) : await _fs.updateCategory(newCat);
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
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
        builder: (context, categorySnapshot) {
          if (!categorySnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final adminCategories = categorySnapshot.data!;
          final adminCategoryByKey = <String, CategoryModel>{
            for (final c in adminCategories)
              if (c.label.trim().isNotEmpty) c.label.trim().toLowerCase(): c,
          };

          return StreamBuilder<List<RestaurantModel>>(
            stream: _fs.getRestaurantsStream(),
            builder: (context, restaurantSnapshot) {
              if (!restaurantSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final restaurantTypes = restaurantSnapshot.data!
                  .map((r) => r.restaurantType.trim())
                  .where((type) => type.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

              final restaurantTypeKeys = restaurantTypes
                  .map((type) => type.toLowerCase())
                  .toSet();

              final mergedKeys = <String>{
                ...adminCategoryByKey.keys,
                ...restaurantTypeKeys,
              }.toList()
                ..sort((a, b) => a.compareTo(b));

              if (mergedKeys.isEmpty) {
                return const Center(
                  child: Text('Chưa có danh mục nào từ Admin hoặc RestaurantType'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                itemCount: mergedKeys.length,
                itemBuilder: (context, index) {
                  final key = mergedKeys[index];
                  final adminCategory = adminCategoryByKey[key];
                  final hasRestaurantType = restaurantTypeKeys.contains(key);
                  final displayLabel = adminCategory?.label ??
                      restaurantTypes.firstWhere((t) => t.toLowerCase() == key);

                  final source = adminCategory != null && hasRestaurantType
                      ? 'Nguồn: Admin + RestaurantType'
                      : adminCategory != null
                          ? 'Nguồn: Admin'
                          : 'Nguồn: RestaurantType';

                  return Card(
                    elevation: 0.5,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: adminCategory != null
                            ? Colors.orange.shade100
                            : Colors.blue.shade100,
                        child: Icon(
                          adminCategory != null
                              ? Icons.category_outlined
                              : Icons.restaurant_menu,
                          color: adminCategory != null
                              ? Colors.orange.shade700
                              : Colors.blue.shade700,
                        ),
                      ),
                      title: Text(displayLabel),
                      subtitle: Text(source),
                      trailing: adminCategory != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _openDialog(adminCategory),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _fs.deleteCategory(adminCategory.id),
                                ),
                              ],
                            )
                          : const Icon(Icons.data_object, color: Colors.blueGrey),
                    ),
                  );
                },
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

    final int totalReviews = _data.fold<int>(0, (sum, item) => sum + (item['count'] as int? ?? 0));
    final int thisMonthReviews = _data.isNotEmpty ? (_data.last['count'] as int? ?? 0) : 0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text('Tăng trưởng đánh giá', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$totalReviews', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Tổng review 6 tháng'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$thisMonthReviews', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Review tháng này'),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

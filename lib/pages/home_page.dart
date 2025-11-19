import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:food_seller_app/models/user_provider.dart';
import 'package:food_seller_app/services/api_service.dart';
import 'package:food_seller_app/services/socket_service.dart';
import 'package:food_seller_app/pages/create_store_page.dart';
import 'package:food_seller_app/pages/login_page.dart';
import 'package:food_seller_app/pages/order_list_page.dart';
import 'package:food_seller_app/pages/manage_menu_list_page.dart'; // [!!] Import
import 'package:food_seller_app/pages/edit_store_page.dart';

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _myStore;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyStore();
    _connectToSocket();
  }

  Future<void> _fetchMyStore() async {
    setState(() => _isLoading = true);
    try {
      _myStore = await _apiService.getMyStore();
    } catch (e) {
      print("Fetch store error: $e");
    }
    setState(() => _isLoading = false);
  }

  void _connectToSocket() {
    final userId = Provider.of<UserProvider>(context, listen: false).user?.userId;
    if (userId != null) {
      final socketService = Provider.of<SocketService>(context, listen: false);
      socketService.connect(userId);
    }
  }

  @override
  void dispose() {
    Provider.of<SocketService>(context, listen: false).disconnect();
    super.dispose();
  }

  void _goToCreateStore() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => CreateStorePage()),
    );
    if (result == true) {
      _fetchMyStore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Seller Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _apiService.logout();
              if (context.mounted) {
                Provider.of<SocketService>(context, listen: false).disconnect();
                Provider.of<UserProvider>(context, listen: false).clearUser();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (ctx) => LoginPage()),
                  (route) => false,
                );
              }
            },
          )
        ],
      ),
      // [!] ไม่ต้องมี FAB
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // --- 1. ถ้ายังไม่มีร้านค้า (เหมือนเดิม) ---
    if (_myStore == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_mall_directory_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('คุณยังไม่มีร้านค้า', style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.add_business_outlined),
              label: Text('สร้างร้านค้า'),
              onPressed: _goToCreateStore,
            ),
          ],
        ),
      );
    }

    // --- 2. ถ้ามีร้านค้าแล้ว (UI แบบที่คุณต้องการ) ---
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 2.1 ส่วน Header ของร้าน ---
          _buildStoreHeader(),

          // --- 2.2 Dashboard Grid (แบบย่อส่วน) ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.count(
              crossAxisCount: 2, // 2 คอลัมน์เหมือนเดิม
              shrinkWrap: true, // [!] ทำให้ GridView ไม่ขยายเต็มจอ
              physics: NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2, 

              children: [
                _buildDashboardCard(
                  context,
                  icon: Icons.restaurant_menu, // 🍴
                  title: 'จัดการเมนูอาหาร',
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) => ManageMenuListPage(storeId: _myStore!['store_id']),
                    ));
                  },
                ),
                _buildDashboardCard(
                  context,
                  icon: Icons.receipt_long, // 🧾
                  title: 'ดูออเดอร์',
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (ctx) => OrderListPage(storeId: _myStore!['store_id']),
                    ));
                  },
                ),
                // [!!] ---- จุดแก้ไขที่ 2: เพิ่มปุ่มที่ขาดไป ----
                _buildDashboardCard(
                  context,
                  icon: Icons.edit_note,
                  title: 'แก้ไขร้าน',
                  onTap: () {
                    // [!!] ---- นี่คือโค้ดใหม่ ----
                    if (_myStore == null) return; // (ป้องกัน error)
                    
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        // [!] ส่งข้อมูลร้านเดิมไปหน้า Edit
                        builder: (ctx) => EditStorePage(storeData: _myStore!),
                      ),
                    ).then((isUpdated) {
                      // [!] เมื่อหน้า Edit ปิดกลับมา
                      if (isUpdated == true) {
                        _fetchMyStore(); // ให้โหลดข้อมูลร้านใหม่
                      }
                    });
                  },
                ),
                _buildDashboardCard(
                  context,
                  icon: Icons.settings,
                  title: 'ตั้งค่า',
                  onTap: () {
                    // TODO: สร้างหน้าตั้งค่า
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ฟีเจอร์ตั้งค่า (เร็วๆ นี้)')));
                  },
                ),
              ],
            ),
          ),
          
          // (พื้นที่ว่างด้านล่าง)
        ],
      ),
    );
  }

  // [!] Widget Header (เหมือนเดิม)
  Widget _buildStoreHeader() {
    return Container(
      width: double.infinity,
      child: Stack(
        children: [
          if (_myStore!['store_image_url'] != null)
            Container(
              height: 200,
              width: double.infinity,
              child: Image.network(
                _myStore!['store_image_url'],
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(height: 200, color: Colors.grey[200]),
                loadingBuilder: (ctx, child, progress) => progress == null ? child : Container(height: 200, child: Center(child: CircularProgressIndicator())),
              ),
            ),
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _myStore!['store_name'],
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // [!] Widget การ์ดปุ่ม (เหมือนเดิม)
  Widget _buildDashboardCard(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    
    // [!!] ---- 1. กำหนดสีเดิมที่คุณต้องการ ----
    // (สีพื้นหลัง Card: สีส้มอ่อน/สีพีช)
    final Color cardColor = Colors.orange[50] ?? Color(0xFFFFF3E0); 
    // (สีไอคอน/ข้อความ: สีน้ำตาลเข้ม)
    final Color contentColor = Colors.brown[800] ?? Colors.brown;

    return Card(
      elevation: 2,
      color: cardColor, // [!!] 2. ใช้สีพื้นหลัง Card
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: contentColor), // [!!] 3. ใช้สีไอคอน
            SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: contentColor // [!!] 4. ใช้สีข้อความ
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

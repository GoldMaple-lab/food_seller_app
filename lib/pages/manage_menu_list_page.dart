import 'package:flutter/material.dart';
import 'package:food_seller_app/services/api_service.dart';
import 'add_edit_menu_page.dart'; // [!] import หน้าฟอร์ม

class ManageMenuListPage extends StatefulWidget {
  final int storeId; // [!] รับ storeId มาจากหน้า Home
  
  const ManageMenuListPage({super.key, required this.storeId});

  @override
  State<ManageMenuListPage> createState() => _ManageMenuListPageState();
}

class _ManageMenuListPageState extends State<ManageMenuListPage> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _menusFuture;

  @override
  void initState() {
    super.initState();
    _loadMenus(); // โหลดเมนู
  }

  // ฟังก์ชันสำหรับโหลด/รีเฟรชข้อมูล
  void _loadMenus() {
    setState(() {
      _menusFuture = _apiService.getMenus(widget.storeId);
    });
  }

  // ฟังก์ชันสำหรับนำทางไปหน้า "เพิ่ม/แก้ไข"
  void _navigateToAddEditPage({Map<String, dynamic>? menuItem}) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AddEditMenuPage(
          storeId: widget.storeId,
          menuItem: menuItem, // ถ้าเป็น null = สร้างใหม่, ถ้ามีค่า = แก้ไข
        ),
      ),
    );

    // [!] ถ้าหน้า Add/Edit ปิดกลับมา และส่ง true (แปลว่าเซฟสำเร็จ)
    if (result == true) {
      _loadMenus(); // ให้โหลดข้อมูลใหม่
    }
  }

  // ฟังก์ชันสำหรับ "ลบ"
  Future<void> _deleteMenu(int menuId) async {
    // [!] แสดง dialog ยืนยัน
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ยืนยันการลบ'),
        content: Text('คุณแน่ใจหรือไม่ว่าต้องการลบเมนูนี้?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('ลบ')),
        ],
      ),
    );

    if (confirm != true) return; // ถ้าไม่ยืนยัน

    try {
      bool success = await _apiService.deleteMenu(menuId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ลบเมนูสำเร็จ'), backgroundColor: Colors.green),
        );
        _loadMenus(); // โหลดใหม่
      } else {
        throw Exception('Failed to delete menu');
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ลบเมนูล้มเหลว: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('จัดการเมนูอาหาร'),
      ),
      // [!] ปุ่มลอยสำหรับ "เพิ่ม" เมนู
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditPage(), // ไม่ส่ง menuItem = สร้างใหม่
        child: Icon(Icons.add),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _menusFuture,
        builder: (context, snapshot) {
          // --- 1. Loading ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          // --- 2. Error ---
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          // --- 3. No Data ---
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('ยังไม่มีเมนู กด + เพื่อเพิ่ม'));
          }

          // --- 4. Has Data ---
          final menus = snapshot.data!;
          return ListView.builder(
            itemCount: menus.length,
            itemBuilder: (context, index) {
              final menu = menus[index] as Map<String, dynamic>;

return Card(
  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  clipBehavior: Clip.antiAlias, // [!] ทำให้รูปมีขอบมนตาม Card
  elevation: 3,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // --- 1. รูปภาพ (ถ้ามี) ---
      if (menu['image_url'] != null)
        Image.network(
          menu['image_url'],
          height: 150, // [!] กำหนดความสูงรูป
          width: double.infinity,
          fit: BoxFit.cover,
          // [!] เพิ่ม Loading/Error Builder ให้ดูโปร
          loadingBuilder: (context, child, progress) {
            return progress == null ? child : Container(height: 150, child: Center(child: CircularProgressIndicator()));
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(height: 150, child: Center(child: Icon(Icons.image_not_supported, color: Colors.grey)));
          },
        ),

      // --- 2. รายละเอียด ---
      Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // --- ชื่อและราคา ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    menu['title'], 
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                  ),
                  Text(
                    '${menu['price']} บาท',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            
            // --- ปุ่ม (ย้ายมาไว้ข้างๆ) ---
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blueAccent),
                  onPressed: () => _navigateToAddEditPage(menuItem: menu),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deleteMenu(menu['menu_id']),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  ),
);            },
          );
        },
      ),
    );
  }
}
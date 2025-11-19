import 'dart:async';
import 'package:flutter/material.dart';
import 'package:food_seller_app/services/api_service.dart';
import 'package:food_seller_app/services/socket_service.dart';
import 'package:provider/provider.dart';

class OrderListPage extends StatefulWidget {
  final int storeId;
  const OrderListPage({super.key, required this.storeId});

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _ordersFuture;
  StreamSubscription? _orderSubscription; // [!] ตัวแปรสำหรับ "ฟัง" Socket

  @override
  void initState() {
    super.initState();
    _loadOrders(); // โหลดออเดอร์ครั้งแรก
    _listenToSocket(); // เริ่มฟังออเดอร์ใหม่
  }

  // 1. โหลดออเดอร์จาก API
  void _loadOrders() {
    setState(() {
      _ordersFuture = _apiService.getMyStoreOrders();
    });
  }

  // 2. ฟัง Event จาก SocketService
  void _listenToSocket() {
    final socketService = Provider.of<SocketService>(context, listen: false);
    
    // [!] สมัครรับ Event จาก Stream
    _orderSubscription = socketService.orderEvents.listen((data) {
      // [!] เมื่อมีออเดอร์ใหม่เข้ามา
      print("Order Page refreshing due to socket event!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔔 คุณมีออเดอร์ใหม่! (ID: ${data['orderId']})'),
          backgroundColor: Colors.green,
        ),
      );
      _loadOrders(); // [!] สั่งโหลดข้อมูลใหม่
    });
  }

  @override
  void dispose() {
    _orderSubscription?.cancel(); // [!] หยุดฟัง Socket เมื่อปิดหน้า
    super.dispose();
  }

  // 3. ฟังก์ชันสำหรับ "อัปเดตสถานะ" (กดยืนยัน / เสร็จสิ้น)
  Future<void> _updateStatus(int orderId, String newStatus) async {
    try {
      bool success = await _apiService.updateOrderStatus(orderId, newStatus);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('อัปเดตสถานะสำเร็จ')));
        _loadOrders(); // โหลดใหม่
      } else {
        throw Exception('Failed to update status');
      }
    } catch (e) {
      if(mounted) _showError(e.toString());
    }
  }

  void _showError(String message) {
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('รายการออเดอร์'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadOrders, // [!] ปุ่มรีเฟรช
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('ยังไม่มีออเดอร์'));
          }

          final orders = snapshot.data!;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildOrderCard(order); // [!] แยก Card ออกมา
            },
          );
        },
      ),
    );
  }

  // [!] Widget สำหรับแสดง Card ของแต่ละออเดอร์
  // (ใน lib/pages/order_list_page.dart)

Widget _buildOrderCard(Map<String, dynamic> order) {
  final status = order['status'];
  Color statusColor = Colors.grey;
  String statusText = status.toString().toUpperCase();

  // [!!] ---- จุดแก้ไขที่ 1: เพิ่มสถานะใหม่ ----
  if (status == 'pending') {
    statusColor = Colors.orange;
    statusText = 'รอการยืนยัน';
  } else if (status == 'accepted') {
    statusColor = Colors.blue;
    statusText = 'กำลังเตรียมอาหาร';
  } else if (status == 'ready_for_pickup') { // [!] เพิ่มสถานะนี้
    statusColor = Colors.purple;
    statusText = 'พร้อมให้ลูกค้ารับ';
  } else if (status == 'completed') {
    statusColor = Colors.green;
    statusText = 'เสร็จสิ้น';
  } else if (status == 'cancelled') {
    statusColor = Colors.red;
    statusText = 'ยกเลิกแล้ว';
  }

  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    elevation: 3,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ... (แถวบน: ID และ สถานะ - เหมือนเดิม) ...
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order ID: #${order['order_id']}', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText, 
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
          Divider(height: 20),
          
          // ... (รายละเอียด - เหมือนเดิม) ...
          Text('ราคารวม: ${order['total_price']} บาท'),
          Text('การชำระเงิน: ${order['payment_method']}'),
          Text('สั่งเมื่อ: ${order['created_at']}'), // (ควร format date ภายหลัง)
          
          SizedBox(height: 16),

          // [!!] ---- จุดแก้ไขที่ 2: เปลี่ยนตรรกะปุ่ม ----
          
          // 1. ถ้า "รอการยืนยัน"
          if (status == 'pending')
            ElevatedButton.icon(
              icon: Icon(Icons.check),
              label: Text('ยืนยันออเดอร์'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              // [!] กดแล้วส่ง 'accepted' (กำลังเตรียม)
              onPressed: () => _updateStatus(order['order_id'], 'accepted'),
            ),
            
          // 2. ถ้า "กำลังเตรียม"
          if (status == 'accepted')
            ElevatedButton.icon(
              icon: Icon(Icons.local_shipping), // เปลี่ยนไอคอน
              label: Text('อาหารพร้อมส่ง/รับ'), // เปลี่ยนข้อความ
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              // [!] กดแล้วส่ง 'ready_for_pickup' (พร้อมรับ)
              onPressed: () => _updateStatus(order['order_id'], 'ready_for_pickup'),
            ),

          // 3. ถ้า "พร้อมรับ"
          if (status == 'ready_for_pickup')
            ElevatedButton.icon(
              icon: Icon(Icons.price_check), // เปลี่ยนไอคอน
              label: Text('เสร็จสิ้น (ลูกค้ารับแล้ว)'), // เปลี่ยนข้อความ
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              // [!] กดแล้วส่ง 'completed' (เสร็จสิ้น)
              onPressed: () => _updateStatus(order['order_id'], 'completed'),
            ),
            
          // (ปุ่มยกเลิก - ถ้าจำเป็น)
          if (status == 'pending' || status == 'accepted')
            TextButton(
              child: Text('ยกเลิกออเดอร์', style: TextStyle(color: Colors.red)),
              onPressed: () => _updateStatus(order['order_id'], 'cancelled'),
            ),
        ],
      ),
    ),
  );
}
}
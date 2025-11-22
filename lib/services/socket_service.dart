import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import 'package:food_seller_app/widgets/notification_banner.dart';
import 'package:food_seller_app/services/audio_service.dart';

// [!] เราจะใช้ ChangeNotifier เพื่อให้ Widget (เช่น OrderListPage) 
// [!] สามารถ "ฟัง" การเปลี่ยนแปลง (ออเดอร์ใหม่) ได้
class SocketService extends ChangeNotifier {
  static const String _serverUrl = 'http://192.168.1.100:3000'; // [!] แก้ IP ของคุณ
  IO.Socket? _socket;

  // เราใช้ Stream เพื่อส่ง "สัญญาณ" บอกว่ามีออเดอร์ใหม่
  final _orderStreamController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get orderEvents => _orderStreamController.stream;

  void connect(int userId) {
    if (_socket != null && _socket!.connected) {
      print("Socket already connected.");
      return;
    }

    _socket = IO.io(_serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      print('Socket Connected (Seller)');
      // [!] เข้าร่วมห้องส่วนตัว (ID ของผู้ขาย)
      _socket!.emit('join_room', userId.toString()); 
    });

    // [!!!!] นี่คือจุดที่ต่าง!!!!
    // [!] ฟัง Event 'new_order' ที่ Server ยิงมา
    _socket!.on('new_order', (data) {
      print('NEW ORDER RECEIVED: $data');
      AudioService.playNotificationSound('audio/new_order_alert.mp3');
      showFacebookStyleNotification(
        title: 'มีออเดอร์ใหม่! 💰',
        message: 'Order ID: #${data['orderId']} เข้ามาแล้ว รีบรับเลย!',
        icon: Icons.restaurant,
        color: Colors.orange,
      );
      _orderStreamController.add(data);
      notifyListeners();
    });

    _socket!.onDisconnect((_) => print('Socket Disconnected (Seller)'));
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  @override
  void dispose() {
    _orderStreamController.close();
    disconnect();
    super.dispose();
  }
}
import 'package:flutter/material.dart';
import 'package:food_seller_app/pages/login_page.dart'; // [!] import หน้า login
import 'package:food_seller_app/services/socket_service.dart';
import 'package:provider/provider.dart';
import 'models/user_provider.dart'; // [!] import UserProvider

void main() {
  runApp(
    // [!!] ใช้ MultiProvider
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => SocketService()), // [!] เพิ่ม SocketService
      ],
      child: const SellerApp(),
    ),
  );
}

class SellerApp extends StatelessWidget {
  const SellerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Seller App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      // [!] เริ่มต้นที่หน้า Login
      home: LoginPage(), 
    );
  }
}
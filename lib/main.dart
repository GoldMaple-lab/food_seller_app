import 'package:flutter/material.dart';
import 'package:food_seller_app/pages/login_page.dart'; // [!] import หน้า login
import 'package:food_seller_app/services/socket_service.dart';
import 'package:provider/provider.dart';
import 'models/user_provider.dart'; // [!] import UserProvider
import 'package:overlay_support/overlay_support.dart';
import 'services/api_service.dart';
import 'pages/home_page.dart'; // [!!] import หน้า HomePage

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
    return OverlaySupport.global(
      child:MaterialApp(
      title: 'Food Seller App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      // [!] เริ่มต้นที่หน้า Login
      home: AuthWrapper(), 
    ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final apiService = ApiService();
    // ดึงข้อมูลที่เซฟไว้
    final userData = await apiService.getUserProfile();

    if (userData != null && mounted) {
      // [!] ถ้ามีข้อมูล -> ยัดใส่ Provider เพื่อให้แอปใช้งานต่อได้เลย
      Provider.of<UserProvider>(context, listen: false).setUser(userData);
      setState(() {
        _isLoggedIn = true;
      });
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. กำลังเช็ค... ให้หมุนติ้วๆ ไปก่อน
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2. เช็คเสร็จแล้ว
    if (_isLoggedIn) {
      // [!!] ถ้าเป็น Seller App ให้ไป HomePage()
      // [!!] ถ้าเป็น Buyer App ให้ไป MainNavigationPage()
      // (เลือกบรรทัดที่ตรงกับแอปที่คุณกำลังแก้อยู่)
      return HomePage(); // สำหรับ Seller App
      // return const MainNavigationPage(); // สำหรับ Buyer App
    } else {
      // 3. ถ้ายังไม่ล็อคอิน ไปหน้า Login
      return const LoginPage();
    }
  }
}
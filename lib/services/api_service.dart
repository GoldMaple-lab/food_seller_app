import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart'; // [!] อย่าลืม import

class ApiService {
  // [!!!!] แก้ IP นี้ให้ตรงกับ .env ใน API ของคุณ
  // [!!!!] ห้ามใช้ localhost หรือ 127.0.0.1
  static const String _baseUrl = 'http://192.168.1.5:3000/api';
  
  // --- Token Management ---
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token', // ส่ง Token ที่นี่
    };
  }

  // (ใน class ApiService ของ Seller App)

  // 1. Auth Functions
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveToken(data['token']); // บันทึก Token
        return data; // [!!] คืนค่าข้อมูล User ทั้งหมด
      }
      print('Login failed: ${response.body}');
      return null; // [!!] คืนค่า null
    } catch (e) {
      print("Login Error: $e");
      return null; // [!!] คืนค่า null
    }
  }

  Future<bool> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': 'seller' // บังคับสมัครเป็น Seller
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      print("Register Error: $e");
      return false;
    }
  }

  // --- 2. Store Functions ---
  Future<Map<String, dynamic>?> getMyStore() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/my-store'),
        headers: await _getAuthHeaders(), // [!!] ต้องใช้ Token
      );

      if (response.statusCode == 200) {
        // API อาจจะคืน "null" (string) หรือ object
        if (response.body == 'null') {
          return null; // คืนค่า null ของ Dart
        }
        final data = jsonDecode(response.body);
        return data as Map<String, dynamic>?;
      }
      print('Get My Store Failed: ${response.body}');
      return null;
    } catch (e) {
      print("Get My Store Error: $e");
      return null;
    }
  }
  Future<bool> createStore(String storeName, String description, String? imageUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/stores'),
        headers: await _getAuthHeaders(), // [!!] ใช้ Header ที่มี Token
        body: jsonEncode({
          'storeName': storeName,
          'description': description,
          'storeImageUrl': imageUrl 
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      print("Create Store Error: $e");
      return false;
    }
  }

  // [!!] ---- ฟังก์ชันใหม่ ----
  Future<bool> updateStore(String storeName, String description, String? imageUrl) async {
    try {
      final response = await http.put( // [!] ใช้ PUT
        Uri.parse('$_baseUrl/my-store'), // [!] API ใหม่
        headers: await _getAuthHeaders(), // [!] ต้องใช้ Token
        body: jsonEncode({
          'storeName': storeName,
          'description': description,
          'storeImageUrl': imageUrl 
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Update Store Error: $e");
      return false;
    }
  }

  // --- 3. Image & Menu Functions ---
  Future<String?> uploadImage(XFile imageFile) async {
    try {
      final token = await _getToken();
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('$_baseUrl/upload-image')
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath(
          'image', // นี่คือ key 'image' ที่ API (multer) รอรับ
          imageFile.path
        )
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        print('Upload Success: ${data['imageUrl']}');
        return data['imageUrl']; // คืนค่า URL ของรูป
      }
      print('Upload failed: ${response.statusCode}');
      return null;
    } catch (e) {
      print("Upload Image Error: $e");
      return null;
    }
  }

  Future<bool> addMenu(int storeId, Map<String, dynamic> data) async {
   try {
    final response = await http.post(
      Uri.parse('$_baseUrl/stores/$storeId/menus'),
      headers: await _getAuthHeaders(),
      body: jsonEncode(data), // [!] ส่ง data ทั้งก้อน
    );
    return response.statusCode == 201;
  } catch (e) {
    print("Add Menu Error: $e");
    return false;
  }
}

  // 6. Get Menus for a Store
  // (API นี้เราสร้างไว้แล้วใน Phase 1, ตอนนี้เราเอามันมาใช้)
  Future<List<dynamic>> getMenus(int storeId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stores/$storeId/menus'),
        // [!] ไม่ต้องใช้ Token เพราะ API นี้เปิดสาธารณะ
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print("Get Menus Error: $e");
      return [];
    }
  }

  // 7. Update Menu
  Future<bool> updateMenu(int menuId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/menus/$menuId'),
        headers: await _getAuthHeaders(), // [!] ต้องใช้ Token
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Update Menu Error: $e");
      return false;
    }
  }

  // 8. Delete Menu
  Future<bool> deleteMenu(int menuId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/menus/$menuId'),
        headers: await _getAuthHeaders(), // [!] ต้องใช้ Token
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Delete Menu Error: $e");
      return false;
    }
  }
// (ใน class ApiService ของ Seller App)

// ... (ต่อจาก deleteMenu)

// --- 5. Get Dropdown Data ---
Future<List<dynamic>> getTags() async {
  try {
    final response = await http.get(
      Uri.parse('$_baseUrl/tags'),
      headers: await _getAuthHeaders(), // (อาจจะไม่ต้องใช้ Auth ก็ได้)
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  } catch (e) {
    print("Get Tags Error: $e");
    return [];
  }
}

Future<List<dynamic>> getMoods() async {
  try {
    final response = await http.get(
      Uri.parse('$_baseUrl/moods'),
      headers: await _getAuthHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  } catch (e) {
    print("Get Moods Error: $e");
    return [];
  }
}

// --- 4. Order Functions (Seller) ---
Future<List<dynamic>> getMyStoreOrders() async {
  try {
    final response = await http.get(
      Uri.parse('$_baseUrl/my-store/orders'),
      headers: await _getAuthHeaders(), // [!] ต้องใช้ Token
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  } catch (e) {
    print("Get Store Orders Error: $e");
    return [];
  }
}

Future<bool> updateOrderStatus(int orderId, String status) async {
  try {
    final response = await http.patch(
      Uri.parse('$_baseUrl/orders/$orderId/status'),
      headers: await _getAuthHeaders(),
      body: jsonEncode({'status': status}),
    );
    return response.statusCode == 200;
  } catch (e) {
    print("Update Status Error: $e");
    return false;
  }
}
}
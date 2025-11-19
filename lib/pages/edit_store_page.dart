import 'package:flutter/material.dart';
import 'package:food_seller_app/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart'; // [!] Import

class EditStorePage extends StatefulWidget {
  // [!] รับข้อมูลร้านเดิมมา
  final Map<String, dynamic> storeData;

  const EditStorePage({super.key, required this.storeData});

  @override
  State<EditStorePage> createState() => _EditStorePageState();
}

class _EditStorePageState extends State<EditStorePage> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _imagePicker = ImagePicker();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _descController;

  // State
  XFile? _selectedImage; // รูปใหม่ที่เลือก
  String? _existingImageUrl; // URL รูปเดิม
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // [!!] เติมข้อมูลเดิมลงในฟอร์ม
    _nameController = TextEditingController(text: widget.storeData['store_name']);
    _descController = TextEditingController(text: widget.storeData['description']);
    _existingImageUrl = widget.storeData['store_image_url'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _existingImageUrl = null; // [!] ถ้าเลือกรูปใหม่, ให้ลบรูปเดิม (ชั่วคราว)
        });
      }
    } catch (e) {
      print("Image pick error: $e");
    }
  }

  // [!!] ---- ฟังก์ชัน "อัปเดต" ----
  Future<void> _handleUpdateStore() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    String? finalImageUrl = _existingImageUrl; // 1. เริ่มด้วย URL รูปเดิม

    try {
      // Step 1: อัปโหลดรูป (ถ้ามีการเลือกรูปใหม่)
      if (_selectedImage != null) {
        finalImageUrl = await _apiService.uploadImage(_selectedImage!);
        if (finalImageUrl == null) {
          throw Exception('Image upload failed');
        }
      }

      // Step 2: [!!] เรียก "updateStore" (ไม่ใช่ create)
      bool success = await _apiService.updateStore(
        _nameController.text,
        _descController.text,
        finalImageUrl, // ส่ง URL (ใหม่ หรือ เก่า)
      );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปเดตร้านสำเร็จ!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true); // [!] ส่ง true กลับไปบอกว่าสำเร็จ
      } else {
        throw Exception('Failed to update store');
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('แก้ไขข้อมูลร้าน'),
      ),
      // [!!] ห่อด้วย Center และ Card (เหมือนหน้า Login)
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600), // จำกัดความกว้าง
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // [!]
                    children: [
                      // --- ช่องชื่อร้าน ---
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'ชื่อร้านค้า',
                          // [!!] อัปเกรด UI
                          prefixIcon: Icon(Icons.storefront_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) => (value == null || value.isEmpty) ? 'กรุณาใส่ชื่อร้าน' : null,
                      ),
                      SizedBox(height: 16),
                      
                      // --- ช่องรายละเอียด ---
                      TextFormField(
                        controller: _descController,
                        decoration: InputDecoration(
                          labelText: 'รายละเอียดร้านค้า',
                          // [!!] อัปเกรด UI
                          prefixIcon: Icon(Icons.description_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 16),

                      // --- ส่วนเลือกรูป ---
                      Text('รูปภาพร้าน (Optional)', style: Theme.of(context).textTheme.titleMedium),
                      SizedBox(height: 8),
                      
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[100] // [!]
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _selectedImage != null
                              ? Image.file(File(_selectedImage!.path), fit: BoxFit.cover) 
                              : (_existingImageUrl != null
                                  ? CachedNetworkImage( 
                                      imageUrl: _existingImageUrl!, 
                                      fit: BoxFit.cover,
                                      placeholder: (ctx, url) => Center(child: CircularProgressIndicator()),
                                      errorWidget: (ctx, url, err) => Center(child: Icon(Icons.image_not_supported)),
                                    ) 
                                  : Center(child: Icon(Icons.image_search, color: Colors.grey[400], size: 50)) // [!]
                                ),
                        ),
                      ),
                      TextButton.icon(
                        icon: Icon(Icons.image),
                        label: Text('เปลี่ยนรูปภาพ'),
                        onPressed: _pickImage,
                      ),
                      SizedBox(height: 20),

                      // --- ปุ่มบันทึก ---
                      if (_isLoading)
                        CircularProgressIndicator()
                      else
                        ElevatedButton(
                          onPressed: _handleUpdateStore,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                          ),
                          child: Text('บันทึกการเปลี่ยนแปลง'),
                        )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
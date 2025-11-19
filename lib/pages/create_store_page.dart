import 'package:flutter/material.dart';
import 'package:food_seller_app/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // [!] Import เพื่อใช้ File

class CreateStorePage extends StatefulWidget {
  const CreateStorePage({super.key});

  @override
  State<CreateStorePage> createState() => _CreateStorePageState();
}

class _CreateStorePageState extends State<CreateStorePage> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _imagePicker = ImagePicker();

  // Controllers
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  // State
  XFile? _selectedImage; // ไฟล์รูปที่เลือกจากเครื่อง
  bool _isLoading = false;

  // ฟังก์ชันเลือกรูป
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      print("Image pick error: $e");
    }
  }

  // ฟังก์ชันสร้างร้าน
  Future<void> _handleCreateStore() async {
    if (!_formKey.currentState!.validate()) return; // ตรวจสอบฟอร์ม

    setState(() => _isLoading = true);

    String? uploadedImageUrl;

    try {
      // Step 1: อัปโหลดรูป (ถ้ามี)
      if (_selectedImage != null) {
        uploadedImageUrl = await _apiService.uploadImage(_selectedImage!);
        if (uploadedImageUrl == null) {
          throw Exception('Image upload failed');
        }
      }

      // Step 2: สร้างร้าน (ส่ง URL รูปไปด้วย)
      bool success = await _apiService.createStore(
        _nameController.text,
        _descController.text,
        uploadedImageUrl, // ส่ง URL (หรือ null)
      );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('สร้างร้านสำเร็จ!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true); // [!] ส่ง true กลับไปบอกว่าสำเร็จ
      } else {
        throw Exception('Failed to create store');
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('สร้างร้านค้าของคุณ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- ช่องชื่อร้าน ---
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อร้านค้า',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'กรุณาใส่ชื่อร้าน' : null,
              ),
              SizedBox(height: 16),
              
              // --- ช่องรายละเอียด ---
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: 'รายละเอียดร้านค้า',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                // (Optional - ไม่บังคับ)
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
                ),
                child: _selectedImage == null
                    ? Center(child: Text('ยังไม่ได้เลือกรูปภาพ'))
                    : Image.file(
                        File(_selectedImage!.path), // [!] แสดงรูปที่เลือก
                        fit: BoxFit.cover,
                      ),
              ),
              TextButton.icon(
                icon: Icon(Icons.image),
                label: Text('เลือกรูปภาพร้าน'),
                onPressed: _pickImage,
              ),

              SizedBox(height: 20),

              // --- ปุ่มบันทึก ---
              if (_isLoading)
                CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: _handleCreateStore,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text('บันทึกและสร้างร้านค้า'),
                )
            ],
          ),
        ),
      ),
    );
  }
}
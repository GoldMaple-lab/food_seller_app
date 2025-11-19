import 'package:flutter/material.dart';
import 'package:food_seller_app/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart'; // [!] Import

class AddEditMenuPage extends StatefulWidget {
  final int storeId;
  final Map<String, dynamic>? menuItem; 

  const AddEditMenuPage({
    super.key, 
    required this.storeId, 
    this.menuItem
  });

  bool get isEditMode => menuItem != null;

  @override
  State<AddEditMenuPage> createState() => _AddEditMenuPageState();
}

class _AddEditMenuPageState extends State<AddEditMenuPage> {
  // [!!] ---- 1. เพิ่ม State สำหรับ Stepper ----
  int _currentStep = 0; 
  // [!!] -------------------------------------

  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _imagePicker = ImagePicker();

  // Controllers
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _caloriesController;
  late TextEditingController _ingredientsController;
  late TextEditingController _stepsController;

  // State
  XFile? _selectedImage; 
  String? _existingImageUrl;
  bool _isLoading = false;
  
  late Future<List<dynamic>> _tagsFuture;
  late Future<List<dynamic>> _moodsFuture;
  Set<int> _selectedTagIds = {};
  Set<int> _selectedMoodIds = {};

  @override
  void initState() {
    super.initState();
    
    // (โค้ด initState เดิม... ไม่ต้องเปลี่ยนแปลง)
    _titleController = TextEditingController(text: widget.menuItem?['title']);
    _descController = TextEditingController(text: widget.menuItem?['description']);
    _priceController = TextEditingController(text: widget.menuItem?['price']?.toString());
    _caloriesController = TextEditingController(text: widget.menuItem?['calories']?.toString());
    _existingImageUrl = widget.menuItem?['image_url'];
    
    String ingredientsText = "";
    String stepsText = "";
    
    if (widget.isEditMode && widget.menuItem?['recipe'] != null) {
      try {
        var recipeData = widget.menuItem!['recipe'];
        if (recipeData is String) {
          recipeData = jsonDecode(recipeData);
        }
        if (recipeData is Map) {
          ingredientsText = (recipeData['ingredients'] as List<dynamic>?)?.join('\n') ?? "";
          stepsText = (recipeData['steps'] as List<dynamic>?)?.join('\n') ?? "";
        }
      } catch (e) { print("Error decoding recipe: $e"); }
    }
    _ingredientsController = TextEditingController(text: ingredientsText);
    _stepsController = TextEditingController(text: stepsText);

    _tagsFuture = _apiService.getTags();
    _moodsFuture = _apiService.getMoods();
    // (TODO: โหลด selectedTagIds และ selectedMoodIds ถ้าเป็นโหมด Edit)
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _caloriesController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _existingImageUrl = null;
      });
    }
  }

  Future<void> _handleSave() async {
    // [!] 1. ตรวจสอบ Form
    if (!_formKey.currentState!.validate()) {
      // ถ้า Form ไม่ผ่าน, ให้ไปที่ Step 0 (หน้าแรก) ที่มีปัญหา
      setState(() {
        _currentStep = 0;
      });
      return;
    }
    
    setState(() => _isLoading = true);
    
    String? finalImageUrl = _existingImageUrl; 

    try {
      // 2. อัปโหลดรูป (ถ้ามี)
      if (_selectedImage != null) {
        finalImageUrl = await _apiService.uploadImage(_selectedImage!);
        if (finalImageUrl == null) throw Exception('Image upload failed');
      }

      // 3. แปลง Recipe
      String ingredientsText = _ingredientsController.text;
      String stepsText = _stepsController.text;
      Map<String, List<String>> recipeJson = {
        'ingredients': ingredientsText.split('\n').where((s) => s.trim().isNotEmpty).toList(),
        'steps': stepsText.split('\n').where((s) => s.trim().isNotEmpty).toList(),
      };

      // 4. รวบรวมข้อมูล
      final data = {
        'title': _titleController.text,
        'description': _descController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'calories': int.tryParse(_caloriesController.text) ?? 0,
        'imageUrl': finalImageUrl,
        'recipe': (recipeJson['ingredients']!.isEmpty && recipeJson['steps']!.isEmpty) ? null : recipeJson,
        'tag_ids': _selectedTagIds.toList(),
        'mood_ids': _selectedMoodIds.toList(),
      };

      bool success;
      if (widget.isEditMode) {
        success = await _apiService.updateMenu(widget.menuItem!['menu_id'], data);
      } else {
        success = await _apiService.addMenu(widget.storeId, data);
      }

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกเมนูสำเร็จ'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      } else {
        throw Exception('Failed to save menu');
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

  // [!!] ---- 2. "ผ่าตัด" build() method ----
  @override
  Widget build(BuildContext context) {
    // [!] ห่อ Stepper ด้วย Form
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'แก้ไขเมนู' : 'เพิ่มเมนูใหม่'),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          // [!] ---- 3. ควบคุม Stepper ----
          currentStep: _currentStep,
          onStepTapped: (step) => setState(() => _currentStep = step),
          onStepContinue: () {
            // ถ้ายังไม่ถึงขั้นสุดท้าย (2)
            if (_currentStep < 2) {
              // [!] ถ้าอยู่ Step 0, ให้เช็ค Form ก่อน
              if (_currentStep == 0) {
                 if (!_formKey.currentState!.validate()) return;
              }
              setState(() => _currentStep += 1);
            } else {
              // ถ้าอยู่ขั้นสุดท้าย (2) -> กด "Continue" จะกลายเป็น "Save"
              if (!_isLoading) {
                 _handleSave();
              }
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            }
          },
          // [!] เปลี่ยนปุ่ม "Continue" เป็น "Save" ในขั้นสุดท้าย
          controlsBuilder: (context, details) {
             final isLastStep = _currentStep == 2;
             return Padding(
               padding: const EdgeInsets.only(top: 16.0),
               child: _isLoading 
                ? Center(child: CircularProgressIndicator()) 
                : Row(
                 children: [
                   ElevatedButton(
                     onPressed: details.onStepContinue,
                     child: Text(isLastStep ? 'บันทึก' : 'ถัดไป'),
                   ),
                   SizedBox(width: 8),
                   if (_currentStep > 0) // ซ่อนปุ่ม "Cancel" ที่หน้าแรก
                     TextButton(
                       onPressed: details.onStepCancel,
                       child: Text('ย้อนกลับ'),
                     ),
                 ],
               ),
             );
          },

          // [!!] ---- 4. เนื้อหา 3 ขั้นตอน ----
          steps: [
            // --- Step 1: ข้อมูลพื้นฐาน ---
            Step(
              title: Text('ข้อมูลพื้นฐาน'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: _buildStep1Content(),
            ),
            // --- Step 2: หมวดหมู่ ---
            Step(
              title: Text('หมวดหมู่ & อารมณ์'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: _buildStep2Content(),
            ),
            // --- Step 3: สูตรอาหาร ---
            Step(
              title: Text('สูตรอาหาร (Optional)'),
              isActive: _currentStep >= 2,
              content: _buildStep3Content(),
            ),
          ],
        ),
      ),
    );
  }

  // [!!] ---- 5. แยกเนื้อหาแต่ละ Step ออกมา ----

  Widget _buildStep1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- แสดงรูปภาพ ---
        Text('รูปภาพเมนู', style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: 8),
        _buildImagePreview(),
        Center(
          child: TextButton.icon(
            icon: Icon(Icons.image),
            label: Text('เปลี่ยนรูปภาพ'),
            onPressed: _pickImage,
          ),
        ),
        SizedBox(height: 16),
        // --- ฟอร์มข้อมูล (ที่ต้อง Validate) ---
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(labelText: 'ชื่อเมนู', border: OutlineInputBorder(), prefixIcon: Icon(Icons.abc)),
          validator: (v) => (v == null || v.isEmpty) ? 'กรุณาใส่ชื่อ' : null,
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _priceController,
          decoration: InputDecoration(labelText: 'ราคา (บาท)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
          keyboardType: TextInputType.number,
            validator: (v) => (v == null || v.isEmpty) ? 'กรุณาใส่ราคา' : null,
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _descController,
          decoration: InputDecoration(labelText: 'รายละเอียด (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description_outlined)),
          maxLines: 3,
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _caloriesController,
          decoration: InputDecoration(labelText: 'แคลอรี่ (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.local_fire_department_outlined)),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildStep2Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('เลือกหมวดหมู่ (Tags)', style: Theme.of(context).textTheme.titleMedium),
        _buildTagsSection(),
        SizedBox(height: 16),
        Text('เลือกอารมณ์ (Moods)', style: Theme.of(context).textTheme.titleMedium),
        _buildMoodsSection(),
      ],
    );
  }

  Widget _buildStep3Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ใส่ 1 อย่าง ต่อ 1 บรรทัด', style: Theme.of(context).textTheme.bodySmall),
        SizedBox(height: 16),
        TextFormField(
          controller: _ingredientsController,
          decoration: InputDecoration(labelText: 'ส่วนผสม (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.kitchen_outlined)),
          maxLines: 5,
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _stepsController,
          decoration: InputDecoration(labelText: 'วิธีทำ (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.soup_kitchen_outlined)),
          maxLines: 5,
        ),
      ],
    );
  }

  // (Widget Helpers: _buildImagePreview, _buildTagsSection, _buildMoodsSection)
  // (โค้ดเดิม ไม่ต้องแก้ไข)
  Widget _buildImagePreview() {
     return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100]
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
                : Center(child: Icon(Icons.image_search, color: Colors.grey[400], size: 50))
              ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return FutureBuilder<List<dynamic>>(
      future: _tagsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return Text('ไม่มีข้อมูล Tags');
        final tags = snapshot.data!;
        
        return Wrap(
          spacing: 8.0,
          children: tags.map((tag) {
            final tagId = tag['tag_id'] as int;
            final tagName = tag['tag_name'] as String;
            final isSelected = _selectedTagIds.contains(tagId);
            
            return FilterChip(
              label: Text(tagName),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) _selectedTagIds.add(tagId);
                  else _selectedTagIds.remove(tagId);
                });
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMoodsSection() {
     return FutureBuilder<List<dynamic>>(
      future: _moodsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return Text('ไม่มีข้อมูล Moods');
        final moods = snapshot.data!;
        
        return Wrap(
          spacing: 8.0,
          children: moods.map((mood) {
            final moodId = mood['mood_id'] as int;
            final moodName = mood['mood_name'] as String;
            final isSelected = _selectedMoodIds.contains(moodId);
            
            return FilterChip(
              label: Text(moodName),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) _selectedMoodIds.add(moodId);
                  else _selectedMoodIds.remove(moodId);
                });
              },
            );
          }).toList(),
        );
      },
    );
  }
}
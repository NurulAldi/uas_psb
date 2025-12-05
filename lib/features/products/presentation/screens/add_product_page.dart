import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rentlens/core/config/supabase_config.dart';
import 'package:rentlens/features/products/domain/models/product.dart';
import 'package:rentlens/features/products/providers/my_products_provider.dart';
import 'package:rentlens/features/products/data/services/image_upload_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AddProductPage extends ConsumerStatefulWidget {
  final Product? product; // If provided, Edit mode

  const AddProductPage({super.key, this.product});

  @override
  ConsumerState<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends ConsumerState<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUploadService = ImageUploadService();
  final _imagePicker = ImagePicker();

  ProductCategory _selectedCategory = ProductCategory.dslr;
  File? _selectedImageFile;
  bool _isUploading = false;

  bool get _isEditMode => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _prefillForm();
    }
  }

  void _prefillForm() {
    final product = widget.product!;
    _nameController.text = product.name;
    _descriptionController.text = product.description ?? '';
    _priceController.text = product.pricePerDay.toString();
    _selectedCategory = ProductCategory.values.firstWhere(
      (c) => c.value == product.category,
      orElse: () => ProductCategory.dslr,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 50, // Kompres otomatis 50% untuk hemat storage
      );

      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    // Set loading state - ini otomatis disable tombol Save dan tampilkan loading spinner
    setState(() => _isUploading = true);

    try {
      String? imageUrl;

      // Handle image upload
      if (_selectedImageFile != null) {
        final userId = SupabaseConfig.currentUserId;
        if (userId == null) throw Exception('User not authenticated');

        if (_isEditMode && widget.product!.imageUrl != null) {
          // Replace existing image
          imageUrl = await _imageUploadService.replaceProductImage(
            newImageFile: _selectedImageFile!,
            userId: userId,
            oldImageUrl: widget.product!.imageUrl!,
          );
        } else {
          // Upload new image
          imageUrl = await _imageUploadService.uploadProductImage(
            imageFile: _selectedImageFile!,
            userId: userId,
          );
        }
      } else if (_isEditMode) {
        // Keep existing image URL
        imageUrl = widget.product!.imageUrl;
      }

      final controller = ref.read(productManagementControllerProvider.notifier);

      Product? result;
      if (_isEditMode) {
        // Update existing product
        result = await controller.updateProduct(
          productId: widget.product!.id,
          name: _nameController.text.trim(),
          category: _selectedCategory.value,
          pricePerDay: double.parse(_priceController.text),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          imageUrl: imageUrl,
        );
      } else {
        // Create new product
        result = await controller.createProduct(
          name: _nameController.text.trim(),
          category: _selectedCategory.value,
          pricePerDay: double.parse(_priceController.text),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          imageUrl: imageUrl,
        );
      }

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Product updated!' : 'Product added!'),
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Image',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isUploading ? null : _pickImage,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: _selectedImageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImageFile!,
                      fit: BoxFit.cover,
                    ),
                  )
                : _isEditMode && widget.product!.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: widget.product!.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to select image',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
          ),
        ),
        if (_selectedImageFile != null ||
            (_isEditMode && widget.product!.imageUrl != null))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: _isUploading
                  ? null
                  : () => setState(() => _selectedImageFile = null),
              icon: const Icon(Icons.close),
              label: Text(_isEditMode ? 'Change Image' : 'Remove Image'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productManagementControllerProvider);
    final isLoading = state.isLoading || _isUploading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Product' : 'Add Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImagePicker(),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  prefixIcon: Icon(Icons.camera_alt),
                  border: OutlineInputBorder(),
                ),
                enabled: !isLoading,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ProductCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: ProductCategory.values
                    .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.value)))
                    .toList(),
                onChanged: isLoading
                    ? null
                    : (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price per Day (Rp)',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                enabled: !isLoading,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                enabled: !isLoading,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditMode ? 'Update Product' : 'Add Product'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

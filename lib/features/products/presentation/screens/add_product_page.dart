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
  List<File> _selectedImageFiles = [];
  List<String> _existingImageUrls = []; // Track existing images in edit mode
  bool _isUploading = false;

  bool get _isEditMode => widget.product != null;

  // Total images count (existing + new)
  int get _totalImagesCount =>
      _existingImageUrls.length + _selectedImageFiles.length;

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
    // Initialize existing images
    _existingImageUrls = List.from(product.imageUrls);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85, // Higher quality for better display
      );

      if (images.isNotEmpty) {
        // Limit to 5 images (including existing)
        final availableSlots = 5 - _totalImagesCount;
        final imagesToAdd = images.take(availableSlots).toList();

        setState(() {
          _selectedImageFiles.addAll(
            imagesToAdd.map((xfile) => File(xfile.path)),
          );
        });

        if (images.length > availableSlots) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Maksimal 5 gambar. Beberapa gambar dilewati.'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih gambar: $e')),
        );
      }
    }
  }

  void _removeImage(int index, {bool isExisting = false}) {
    setState(() {
      if (isExisting) {
        _existingImageUrls.removeAt(index);
      } else {
        _selectedImageFiles.removeAt(index);
      }
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    // Set loading state - ini otomatis disable tombol Save dan tampilkan loading spinner
    setState(() => _isUploading = true);

    try {
      List<String> imageUrls = [];

      // Handle image upload
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) throw Exception('Pengguna tidak terautentikasi');

      // Start with existing images (if in edit mode)
      if (_isEditMode) {
        imageUrls = List.from(_existingImageUrls);

        // Delete removed images
        final removedImages = widget.product!.imageUrls
            .where((url) => !_existingImageUrls.contains(url))
            .toList();
        if (removedImages.isNotEmpty) {
          await _imageUploadService.deleteMultipleProductImages(removedImages);
        }
      }

      // Upload new images
      if (_selectedImageFiles.isNotEmpty) {
        final newImageUrls =
            await _imageUploadService.uploadMultipleProductImages(
          imageFiles: _selectedImageFiles,
          userId: userId,
        );
        imageUrls.addAll(newImageUrls);
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
          imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
          imageUrls: imageUrls,
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
          imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
          imageUrls: imageUrls,
        );
      }

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Produk berhasil diperbarui!'
                : 'Produk berhasil ditambahkan!'),
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kesalahan: $e')),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gambar Produk',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              '$_totalImagesCount/5',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Image Grid - Show existing + new images
        if (_totalImagesCount > 0)
          Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _totalImagesCount,
              itemBuilder: (context, index) {
                // Show existing images first, then new images
                final isExisting = index < _existingImageUrls.length;
                final actualIndex =
                    isExisting ? index : index - _existingImageUrls.length;

                return Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: isExisting
                            ? CachedNetworkImage(
                                imageUrl: _existingImageUrls[actualIndex],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                              )
                            : Image.file(
                                _selectedImageFiles[actualIndex],
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    if (!_isUploading)
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () =>
                              _removeImage(actualIndex, isExisting: isExisting),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

        // Add Images Button
        if (_totalImagesCount < 5)
          GestureDetector(
            onTap: _isUploading ? null : _pickImages,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[400]!,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate,
                    size: 48,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _totalImagesCount == 0
                        ? 'Ketuk untuk memilih gambar'
                        : 'Tambah gambar lagi',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(${5 - _totalImagesCount} slot tersisa)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
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
        title: Text(_isEditMode ? 'Edit Produk' : 'Tambah Produk'),
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
                  labelText: 'Nama Produk',
                  prefixIcon: Icon(Icons.camera_alt),
                  border: OutlineInputBorder(),
                ),
                enabled: !isLoading,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ProductCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
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
                  labelText: 'Harga per Hari (Rp)',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                enabled: !isLoading,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                  if (double.tryParse(v) == null) return 'Angka tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi (Opsional)',
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
                      : Text(_isEditMode ? 'Perbarui Produk' : 'Tambah Produk'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

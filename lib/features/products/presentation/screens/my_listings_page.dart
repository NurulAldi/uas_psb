import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/features/products/providers/my_products_provider.dart';

class MyListingsPage extends ConsumerWidget {
  const MyListingsPage({super.key});

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String productId,
    String productName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "$productName"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final controller = ref.read(productManagementControllerProvider.notifier);
      final success = await controller.deleteProduct(productId);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully')),
        );
        ref.invalidate(myProductsProvider);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete product'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myProductsAsync = ref.watch(myProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myProductsProvider),
          ),
          // Add product from app bar as alternative
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await context.push('/products/add');
              if (result == true && context.mounted) {
                ref.invalidate(myProductsProvider);
              }
            },
            tooltip: 'Add Product',
          ),
        ],
      ),
      body: myProductsAsync.when(
        data: (products) => products.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined,
                        size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('No listings yet',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('Tap + button to add your first product'),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            width: 60,
                            height: 60,
                            color: AppColors.backgroundGrey,
                            child: const Icon(Icons.camera_alt),
                          ),
                          title: Text(product.name),
                          subtitle: Text(
                              '${product.formattedPrice}/day • ${product.category.value}'),
                          trailing: Switch(
                            value: product.isAvailable,
                            onChanged: (value) async {
                              await ref
                                  .read(productManagementControllerProvider
                                      .notifier)
                                  .updateProduct(
                                    productId: product.id,
                                    isAvailable: value,
                                  );
                              ref.invalidate(myProductsProvider);
                            },
                          ),
                          onTap: () => context.push('/products/${product.id}'),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () async {
                                    final result = await context.push(
                                        '/products/${product.id}/edit',
                                        extra: product);
                                    if (result == true && context.mounted) {
                                      ref.invalidate(myProductsProvider);
                                    }
                                  },
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Edit'),
                                ),
                              ),
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () => _showDeleteConfirmation(
                                    context,
                                    ref,
                                    product.id,
                                    product.name,
                                  ),
                                  icon: const Icon(Icons.delete, size: 18),
                                  label: const Text('Delete'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 80, color: Colors.orange),
                const SizedBox(height: 24),
                Text(
                  'Migration Required',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    error.toString().contains('migration') ||
                            error.toString().contains('owner_id')
                        ? 'Please run the database migration script to enable P2P marketplace features.\n\nOpen supabase_migration_p2p_marketplace.sql and execute it in your Supabase SQL Editor.'
                        : error.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(myProductsProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push('/products/add');
          if (result == true && context.mounted) {
            ref.invalidate(myProductsProvider);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }
}

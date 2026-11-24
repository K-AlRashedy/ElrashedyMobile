import 'package:flutter/material.dart';

import '../core/constants/colors.dart';
import '../models/product_model.dart';

class ProductAvatar extends StatelessWidget {
  final ProductModel product;
  final double size;

  const ProductAvatar({super.key, required this.product, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final image = product.image?.trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null || image.isEmpty
          ? Icon(Icons.inventory_2_outlined, size: size * 0.52, color: AppColors.textSecondary)
          : Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.inventory_2_outlined,
                size: size * 0.52,
                color: AppColors.textSecondary,
              ),
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
            ),
    );
  }
}

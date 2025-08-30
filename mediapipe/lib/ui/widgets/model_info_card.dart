// ui/widgets/model_info_card.dart - نسخه تصحیح شده
import 'package:flutter/material.dart';
import 'package:flutter_gemma/pigeon.g.dart'; // برای PreferredBackend
import '../../models/model.dart';

/// Widget برای نمایش اطلاعات مدل
class ModelInfoCard extends StatelessWidget {
  final Model model;
  final bool isLoading;
  final VoidCallback? onTap;

  const ModelInfoCard({
    super.key,
    required this.model,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      color: Colors.grey[850],
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and loading indicator
              Row(
                children: [
                  Expanded(
                    child: Text(
                      model.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    )
                  else
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[400],
                      size: 16,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Model details
              Row(
                children: [
                  Text(
                    'حجم: ${model.size}',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: model.preferredBackend == PreferredBackend.gpu 
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: model.preferredBackend == PreferredBackend.gpu 
                            ? Colors.green
                            : Colors.blue,
                      ),
                    ),
                    child: Text(
                      model.preferredBackend.name.toUpperCase(),
                      style: TextStyle(
                        color: model.preferredBackend == PreferredBackend.gpu 
                            ? Colors.green
                            : Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Features
              if (model.supportsFunctionCalls || model.supportImage || model.isThinking) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4.0,
                  children: [
                    if (model.supportsFunctionCalls)
                      _buildFeatureChip('فراخوانی تابع', Colors.purple[600]!),
                    if (model.supportImage)
                      _buildFeatureChip('چندرسانه‌ای', Colors.orange[700]!),
                    if (model.isThinking)
                      _buildFeatureChip('تفکر', Colors.indigo[600]!),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, Color color) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
// frontend/screens/model_list_screen.dart - لیست مدل‌ها
import 'package:flutter/material.dart';
import '../../shared/models.dart';
import '../../config.dart';
import 'download_screen.dart';

class ModelListScreen extends StatefulWidget {
  const ModelListScreen({super.key});

  @override
  State<ModelListScreen> createState() => _ModelListScreenState();
}

class _ModelListScreenState extends State<ModelListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.bgDark,
      appBar: AppBar(
        title: const Text('انتخاب مدل AI'),
        backgroundColor: Colors.grey[900],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: AIModel.values.length,
        itemBuilder: (context, index) {
          final model = AIModel.values[index];
          return _ModelCard(
            model: model,
            onTap: () => _navigateToDownload(model),
          );
        },
      ),
    );
  }

  void _navigateToDownload(AIModel model) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DownloadScreen(model: model),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  final AIModel model;
  final VoidCallback onTap;

  const _ModelCard({required this.model, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppConfig.cardDark,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      model.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'حجم: ${model.sizeDisplay}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Text(
                      model.backend.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (model.hasImage || model.hasFunctionCalls || model.isThinking) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: [
                    if (model.hasFunctionCalls) _buildChip('تابع', Colors.purple),
                    if (model.hasImage) _buildChip('تصویر', Colors.orange),
                    if (model.isThinking) _buildChip('تفکر', Colors.indigo),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
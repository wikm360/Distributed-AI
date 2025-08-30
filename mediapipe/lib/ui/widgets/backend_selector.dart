// ui/widgets/backend_selector.dart
import 'package:flutter/material.dart';
import '../../core/services/backend_factory.dart';

/// Widget برای انتخاب backend
class BackendSelector extends StatefulWidget {
  final String? selectedBackend;
  final Function(String) onBackendChanged;
  final bool enabled;

  const BackendSelector({
    super.key,
    this.selectedBackend,
    required this.onBackendChanged,
    this.enabled = true,
  });

  @override
  State<BackendSelector> createState() => _BackendSelectorState();
}

class _BackendSelectorState extends State<BackendSelector> {
  late List<String> availableBackends;

  @override
  void initState() {
    super.initState();
    availableBackends = BackendFactory.supportedBackends;
  }

  @override
  Widget build(BuildContext context) {
    if (availableBackends.isEmpty) {
      return const Text(
        'هیچ backend پشتیبانی‌شده‌ای یافت نشد',
        style: TextStyle(color: Colors.red),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[600]!),
      ),
      child: DropdownButton<String>(
        value: widget.selectedBackend,
        hint: const Text('انتخاب Backend', style: TextStyle(color: Colors.white70)),
        isExpanded: true,
        dropdownColor: Colors.grey[800],
        style: const TextStyle(color: Colors.white),
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        items: availableBackends.map((backend) {
          return DropdownMenuItem<String>(
            value: backend,
            child: Row(
              children: [
                Icon(
                  _getBackendIcon(backend),
                  size: 20,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(_getBackendDisplayName(backend)),
              ],
            ),
          );
        }).toList(),
        onChanged: widget.enabled ? (String? newValue) {
          if (newValue != null) {
            widget.onBackendChanged(newValue);
          }
        } : null,
      ),
    );
  }

  IconData _getBackendIcon(String backend) {
    switch (backend.toLowerCase()) {
      case 'gemma':
      case 'flutter_gemma':
        return Icons.phone_android;
      case 'llamacpp':
      case 'llama_cpp':
        return Icons.computer;
      default:
        return Icons.memory;
    }
  }

  String _getBackendDisplayName(String backend) {
    switch (backend.toLowerCase()) {
      case 'gemma':
      case 'flutter_gemma':
        return 'Flutter Gemma (موبایل)';
      case 'llamacpp':
      case 'llama_cpp':
        return 'LlamaCpp (دسکتاپ)';
      default:
        return backend.toUpperCase();
    }
  }
}
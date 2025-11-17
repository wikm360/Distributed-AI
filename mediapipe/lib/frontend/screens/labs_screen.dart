import 'package:flutter/material.dart';

import '../../network/labs_api.dart';
import '../../shared/models.dart';
import '../widgets/starfield_background.dart';

class LabsScreen extends StatefulWidget {
  const LabsScreen({super.key});

  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

enum _VisibilityFilter { public, private }

class _LabsScreenState extends State<LabsScreen> {
  static const _cardPalette = <Color>[
    Color(0xFFFFA8A8),
    Color(0xFFFFD588),
    Color(0xFFB5FF8C),
    Color(0xFF99E6FF),
    Color(0xFFE0C3FC),
    Color(0xFFFFB3D0),
  ];

  final _searchController = TextEditingController();
  final LabsApi _labsApi = LabsApi();
  late Future<List<LabCardEntry>> _labsFuture;
  List<LabCardEntry> _cachedEntries = [];
  String? _selectedTag;
  _VisibilityFilter _visibility = _VisibilityFilter.public;

  @override
  void initState() {
    super.initState();
    _labsFuture = _loadLabs();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<List<LabCardEntry>> _loadLabs() async {
    final items = await _labsApi.fetchCards();
    _cachedEntries = items;
    return items;
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _handleRefresh() async {
    final freshItems = await _labsApi.fetchCards();
    if (!mounted) return;
    setState(() {
      _cachedEntries = freshItems;
      _labsFuture = Future.value(freshItems);
    });
  }

  void _openFilterSheet() {
    final tags = _cachedEntries.expand((entry) => entry.tags).toSet().toList()
      ..sort();

    if (tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هیچ تگی برای فیلتر موجود نیست'),
        ),
      );
      return;
    }

    String? tempSelection = _selectedTag;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'انتخاب تگ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    children: [
                      ChoiceChip(
                        label: const Text('همه'),
                        selected: tempSelection == null,
                        onSelected: (_) {
                          modalSetState(() => tempSelection = null);
                        },
                      ),
                      ...tags.map(
                        (tag) => ChoiceChip(
                          label: Text(tag),
                          selected: tempSelection == tag,
                          onSelected: (_) {
                            modalSetState(() {
                              tempSelection = tempSelection == tag ? null : tag;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _selectedTag = tempSelection;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('اعمال فیلتر'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<LabCardEntry> _visibleEntries(List<LabCardEntry> entries) {
    final query = _searchController.text.trim().toLowerCase();
    final base = _cachedEntries.isNotEmpty ? _cachedEntries : entries;

    return base.where((entry) {
      final matchesQuery = query.isEmpty ||
          entry.title.toLowerCase().contains(query) ||
          entry.description.toLowerCase().contains(query) ||
          entry.author.toLowerCase().contains(query);

      final matchesTag = _selectedTag == null ||
          entry.tags.any(
            (tag) => tag.toLowerCase() == _selectedTag!.toLowerCase(),
          );

      final isPrivate = _isPrivateEntry(entry);
      final matchesPrivacy =
          _visibility == _VisibilityFilter.private ? isPrivate : !isPrivate;

      return matchesQuery && matchesTag && matchesPrivacy;
    }).toList();
  }

  bool _isPrivateEntry(LabCardEntry entry) {
    return entry.tags.any(
      (tag) {
        final lower = tag.toLowerCase();
        return lower.contains('private') || lower == 'خصوصی';
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StarfieldBackground(
      starCount: 150,
      backgroundColor: const Color(0xFF0F0F0F),
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildSearchRow(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: FutureBuilder<List<LabCardEntry>>(
                      future: _labsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildLoadingState();
                        }
                        if (snapshot.hasError) {
                          return _buildErrorState(snapshot.error.toString());
                        }
                        final entries = snapshot.data ?? [];
                        final visibleEntries = _visibleEntries(entries);
                        if (visibleEntries.isEmpty) {
                          return _buildEmptyState();
                        }
                        return RefreshIndicator(
                          onRefresh: _handleRefresh,
                          color: Colors.white,
                          backgroundColor: Colors.black,
                          child: GridView.builder(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.only(bottom: 40),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 20,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.9,
                            ),
                            itemCount: visibleEntries.length,
                            itemBuilder: (context, index) {
                              final entry = visibleEntries[index];
                              final color =
                                  _cardPalette[index % _cardPalette.length];
                              return _buildLabCard(entry, color);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            _buildCreateLabButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateLabButton() {
    return Positioned(
      bottom: 120, // Above navbar (70px height + 20px margin + buffer)
      left: 24,
      child: GestureDetector(
        onTap: _showCreateLabDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline,
                color: Colors.black,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Create Lab',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateLabDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create New Lab',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Lab Title',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // TODO: Implement lab creation
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lab creation coming soon!'),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Create Lab',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Labs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'List of all Labs',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
        _buildVisibilityToggle(),
      ],
    );
  }

  Widget _buildVisibilityToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTogglePill('Public', _VisibilityFilter.public),
          _buildTogglePill('Private', _VisibilityFilter.private),
        ],
      ),
    );
  }

  Widget _buildTogglePill(String label, _VisibilityFilter value) {
    final isSelected = _visibility == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _visibility = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchRow() {
    return Row(
      children: [
        Expanded(child: _buildSearchField()),
        const SizedBox(width: 12),
        _buildFilterButton(),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white60),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Search in Labs...',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return GestureDetector(
      onTap: _openFilterSheet,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _selectedTag == null ? Colors.white10 : Colors.white54,
          ),
        ),
        child: Icon(
          Icons.tune_rounded,
          color: _selectedTag == null ? Colors.white : Colors.white70,
        ),
      ),
    );
  }

  Widget _buildLabCard(LabCardEntry entry, Color color) {
    const textColor = Color(0xFF111111);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              entry.description,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor.withOpacity(0.75),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      entry.dateLabel,
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (entry.tags.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        entry.tags.first,
                        style: const TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        return Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: Colors.white54, size: 48),
          const SizedBox(height: 12),
          Text(
            'خطا در دریافت اطلاعات',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _labsFuture = _loadLabs();
              });
            },
            child: const Text('تلاش مجدد'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.topic_outlined, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text(
            _selectedTag == null && _searchController.text.isEmpty
                ? 'هیچ کارتی از سرور دریافت نشد'
                : 'چیزی با فیلتر فعلی پیدا نشد',
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

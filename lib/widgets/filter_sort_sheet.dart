import 'package:flutter/material.dart';
import '../models/ipo.dart';



class FilterSortSheet extends StatefulWidget {
  final IpoCategory? initialCategory;
  final IpoSortOption initialSort;
  final void Function(IpoCategory? category, IpoSortOption sort) onApply;

  const FilterSortSheet({
    super.key,
    required this.initialCategory,
    required this.initialSort,
    required this.onApply,
  });

  static void show(
    BuildContext context, {
    required IpoCategory? currentCategory,
    required IpoSortOption currentSort,
    required void Function(IpoCategory? category, IpoSortOption sort) onApply,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FilterSortSheet(
        initialCategory: currentCategory,
        initialSort: currentSort,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FilterSortSheet> createState() => _FilterSortSheetState();
}

class _FilterSortSheetState extends State<FilterSortSheet> {
  late IpoCategory? _selectedCategory;
  late IpoSortOption _selectedSort;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _selectedSort = widget.initialSort;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter & Sort',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCategory = null;
                    _selectedSort = IpoSortOption.defaultOrder;
                  });
                },
                child: const Text('Reset'),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            'CATEGORY / SEGMENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),

          // Category Chips
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _selectedCategory == null,
                onSelected: (_) => setState(() => _selectedCategory = null),
              ),
              ChoiceChip(
                label: const Text('Mainboard'),
                selected: _selectedCategory == IpoCategory.mainboard,
                onSelected: (_) => setState(() => _selectedCategory = IpoCategory.mainboard),
              ),
              ChoiceChip(
                label: const Text('SME'),
                selected: _selectedCategory == IpoCategory.sme,
                onSelected: (_) => setState(() => _selectedCategory = IpoCategory.sme),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Text(
            'SORT BY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),

          // Sort Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: IpoSortOption.values.map((sortOption) {
              final isSelected = _selectedSort == sortOption;
              return ChoiceChip(
                label: Text(sortOption.displayName),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedSort = sortOption),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onApply(_selectedCategory, _selectedSort);
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Apply Filter & Sort'),
            ),
          ),
        ],
      ),
    );
  }
}

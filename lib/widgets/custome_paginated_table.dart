import 'package:flutter/material.dart';

class CustomPaginatedTable extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final List<String> columnHeaders;
  final List<String> columnKeys;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final List<int> availableItemsPerPage;
  final String paginationInfo;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final bool isLoading;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousPage;
  final Function(int) onGoToPage;
  final Function(int?) onItemsPerPageChanged;

  const CustomPaginatedTable({
    super.key,
    required this.data,
    required this.columnHeaders,
    required this.columnKeys,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.availableItemsPerPage,
    required this.paginationInfo,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.isLoading,
    required this.onNextPage,
    required this.onPreviousPage,
    required this.onGoToPage,
    required this.onItemsPerPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: columnHeaders
                    .map((header) => DataColumn(label: Text(header)))
                    .toList(),
                rows: data
                    .map((item) => DataRow(
                  cells: columnKeys
                      .map((key) => DataCell(
                    Text(item[key]?.toString() ?? ''),
                  ))
                      .toList(),
                ))
                    .toList(),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text(paginationInfo)),
                  Flexible(
                    child: DropdownButton<int>(
                      value: itemsPerPage,
                      onChanged: onItemsPerPageChanged,
                      items: availableItemsPerPage
                          .map((value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value items'),
                      ))
                          .toList(),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: hasPreviousPage ? onPreviousPage : null,
                  ),
                  Text('$currentPage of $totalPages'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: hasNextPage ? onNextPage : null,
                  ),
                ],
              ),
            ],
          ),
        )
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';


class CacheStatusIndicator extends StatelessWidget {
  final String status;  // Add this
  final bool showTimestamp;
  final double? width;
  final EdgeInsetsGeometry? margin;

  const CacheStatusIndicator({
    super.key,
    required this.status,  // Add this
    this.showTimestamp = true,
    this.width,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Parse the status string to determine if it's cached
    final isCached = status.toLowerCase().contains('cached');
    final hasTime = status.toLowerCase().contains('ago') ||
        status.toLowerCase().contains('just now');

    final Color indicatorColor = isCached
        ? theme.colorScheme.secondary
        : theme.colorScheme.primary;
    final IconData indicatorIcon = isCached
        ? Icons.cached
        : Icons.cloud_download;

    return Container(
      width: width,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: indicatorColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            indicatorIcon,
            size: 14,
            color: indicatorColor,
          ),
          const SizedBox(width: 4),
          Text(
            isCached ? 'Cached Data' : 'Fresh Data',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: indicatorColor,
            ),
          ),
          if (showTimestamp && hasTime) ...[
            const SizedBox(width: 4),
            Text(
              '•',
              style: TextStyle(
                fontSize: 11,
                color: indicatorColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              status.replaceAll('Updated', '').trim(),
              style: TextStyle(
                fontSize: 10,
                color: indicatorColor.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
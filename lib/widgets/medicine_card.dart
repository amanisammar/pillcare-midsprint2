import 'package:flutter/material.dart';

class MedicineCard extends StatelessWidget {
  final String name;
  final String dose;
  final String? time;
  final String? status;
  final bool isTaken;
  final VoidCallback? onMarkTaken;
  final Color? leadingColor; // background color for avatar
  final Color? iconColor; // icon color
  final Widget? trailing;
  final bool showDivider;

  const MedicineCard({
    super.key,
    required this.name,
    required this.dose,
    this.time,
    this.status,
    this.isTaken = false,
    this.onMarkTaken,
    this.leadingColor,
    this.iconColor,
    this.trailing,
    this.showDivider = true,
  });

  Color _statusColor(String? status) {
    switch (status) {
      case 'taken':
        return Colors.green;
      case 'due':
        return Colors.orange;
      case 'late':
        return Colors.red;
      case 'upcoming':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  String _statusText(BuildContext context, String? status) {
    if (status == null) return '';
    switch (status) {
      case 'taken':
        return 'Taken';
      case 'due':
        return 'Due';
      case 'late':
        return 'Late';
      case 'upcoming':
        return 'Upcoming';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: (leadingColor ?? statusColor).withOpacity(0.15),
              child: Icon(Icons.medication, color: iconColor ?? statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(dose, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (time != null) Text(time!),
                const SizedBox(height: 4),
                if (status != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _statusText(context, status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (!isTaken && status == 'due' && onMarkTaken != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: onMarkTaken,
                          iconSize: 20,
                        ),
                      ],
                    ],
                  )
                else if (time == null)
                  const SizedBox.shrink(),
              ],
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
        if (showDivider) const Divider(height: 24),
      ],
    );
  }
}

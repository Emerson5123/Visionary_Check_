import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onHistoryPressed;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.onSettingsPressed,
    this.onHistoryPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.deepPurple,
      elevation: 4,
      actions: [
        if (onHistoryPressed != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.history, size: 28),
                onPressed: onHistoryPressed,
                tooltip: 'Historial',
              ),
            ),
          ),
        if (onSettingsPressed != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.settings, size: 28),
                onPressed: onSettingsPressed,
                tooltip: 'Configuración',
              ),
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
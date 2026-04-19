import 'package:flutter/material.dart';
import '../widgets/accessible_widget.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onHistoryPressed;
  final VoidCallback? onDeletePressed;
  final VoidCallback? onBackPressed;
  final bool showBackButton;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.onSettingsPressed,
    this.onHistoryPressed,
    this.onDeletePressed,
    this.onBackPressed,
    this.showBackButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title,
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: Colors.deepPurple,
      elevation: 4,
      leading: showBackButton
          ? AccessibleWidget(
        description: 'Botón volver atrás',
        onActivate: onBackPressed ?? () => Navigator.pop(context),
        child: const Icon(Icons.arrow_back, color: Colors.white),
      )
          : null,
      automaticallyImplyLeading: false,
      actions: [
        if (onDeletePressed != null)
          Padding(
            padding: const EdgeInsets.all(6),
            child: AccessibleWidget(
              description: 'Botón limpiar historial',
              onActivate: onDeletePressed,
              child: const Icon(Icons.delete_sweep, color: Colors.white, size: 28),
            ),
          ),
        if (onHistoryPressed != null)
          Padding(
            padding: const EdgeInsets.all(6),
            child: AccessibleWidget(
              description: 'Botón historial de verificaciones',
              onActivate: onHistoryPressed,
              child: const Icon(Icons.history, color: Colors.white, size: 28),
            ),
          ),
        if (onSettingsPressed != null)
          Padding(
            padding: const EdgeInsets.all(6),
            child: AccessibleWidget(
              description: 'Botón configuración',
              onActivate: onSettingsPressed,
              child: const Icon(Icons.settings, color: Colors.white, size: 28),
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
import 'package:flutter/material.dart';

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

      // Mostrar botón de retroceso si es necesario
      leading: showBackButton
          ? IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBackPressed ?? () => Navigator.pop(context),
      )
          : null,
      automaticallyImplyLeading: false,

      actions: [
        // Botón Eliminar/Limpiar
        if (onDeletePressed != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.delete_sweep, size: 28),
                onPressed: onDeletePressed,
                tooltip: 'Limpiar historial',
              ),
            ),
          ),

        // Botón Historial
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

        // Botón Configuración
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
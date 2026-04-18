import 'package:flutter/material.dart';
import '../services/bill_repository.dart';
import '../models/bill_record.dart';
import '../widgets/custom_app_bar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final BillRepository _billRepository = BillRepository();
  late Future<List<BillRecord>> _billsFuture;

  @override
  void initState() {
    super.initState();
    _billsFuture = _billRepository.getAllBills();
  }

  /// Recargar lista de billetes
  void _reloadBills() {
    setState(() {
      _billsFuture = _billRepository.getAllBills();
    });
  }

  /// Mostrar confirmación de borrado
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.deepPurple.shade800,
        title: const Text(
          'Limpiar Historial',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Está seguro de que desea eliminar TODO el historial de verificaciones? '
              'Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.amber),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Mostrar loading
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    content: Row(
                      children: const [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Eliminando...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Ejecutar eliminación
              final success = await _billRepository.clearAllBills();

              if (mounted) {
                Navigator.pop(context); // Cerrar loading

                if (success) {
                  // Mostrar confirmación
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Historial eliminado correctamente'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  _reloadBills();
                } else {
                  // Error
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al eliminar el historial'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Historial de Verificaciones',
        onDeletePressed: _showDeleteConfirmation,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade900,
              Colors.deepPurple.shade500,
            ],
          ),
        ),
        child: FutureBuilder<List<BillRecord>>(
          future: _billsFuture,
          builder: (context, snapshot) {
            // Cargando
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                      strokeWidth: 4,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Cargando historial...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            }

            // Error
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar historial',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _reloadBills,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                      ),
                      child: const Text(
                        'Reintentar',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              );
            }

            final bills = snapshot.data ?? [];

            // Sin datos
            if (bills.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      color: Colors.white.withOpacity(0.3),
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay verificaciones aún',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Las verificaciones aparecerán aquí',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Lista de billetes
            return ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: bills.length,
              itemBuilder: (context, index) {
                final bill = bills[index];

                return Dismissible(
                  key: Key(bill.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.deepPurple.shade800,
                        title: const Text(
                          'Eliminar',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          '¿Deseas eliminar este registro?',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Sí',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) async {
                    await _billRepository.deleteBill(bill.id);
                    _reloadBills();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Registro eliminado'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.white.withOpacity(0.1),
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bill.isAuthentic
                              ? Colors.green.shade400
                              : Colors.red.shade400,
                          boxShadow: [
                            BoxShadow(
                              color: bill.isAuthentic
                                  ? Colors.green.withOpacity(0.5)
                                  : Colors.red.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          bill.isAuthentic ? Icons.check : Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      title: Text(
                        'Billete ${bill.denomination}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            bill.formattedDate,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: bill.isAuthentic
                                      ? Colors.green.withOpacity(0.3)
                                      : Colors.red.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  bill.isAuthentic ? 'Auténtico' : 'Falso',
                                  style: TextStyle(
                                    color: bill.isAuthentic
                                        ? Colors.green.shade200
                                        : Colors.red.shade200,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                bill.confidence,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withOpacity(0.5),
                        size: 16,
                      ),
                      onTap: () {
                        // Opcional: Ver detalles del billete
                        _showBillDetails(bill);
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Mostrar detalles del billete
  void _showBillDetails(BillRecord bill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.deepPurple.shade800,
        title: const Text(
          'Detalles del Billete',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Denominación', bill.denomination),
            const SizedBox(height: 12),
            _buildDetailRow('Estado', bill.isAuthentic ? 'Auténtico' : 'Falso'),
            const SizedBox(height: 12),
            _buildDetailRow('Confianza', bill.confidence),
            const SizedBox(height: 12),
            _buildDetailRow('Fecha', bill.formattedDate),
            const SizedBox(height: 12),
            _buildDetailRow('ID', bill.id),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget para mostrar detalles
  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
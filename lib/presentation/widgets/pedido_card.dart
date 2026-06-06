import 'package:flutter/material.dart';
import '../../../data/datasources/api_datasource.dart';
import '../../../data/models/pedido_model.dart';
import '../../core/theme.dart';

class PedidoCard extends StatefulWidget {
  final PedidoModel pedido;

  const PedidoCard({super.key, required this.pedido});

  @override
  State<PedidoCard> createState() => _PedidoCardState();
}

class _PedidoCardState extends State<PedidoCard> {
  final ApiDatasource _apiDatasource = ApiDatasource();
  late String _estadoActual;

  @override
  void initState() {
    super.initState();
    _estadoActual = widget.pedido.estado; // Inicializamos el estado local
  }

  // 💡 Muestra un menú de opciones al chofer para cambiar el estado
  // 💡 Muestra un menú de opciones al chofer para cambiar el estado
  void _mostrarOpcionesEstado(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ACTUALIZAR ESTADO DEL PAQUETE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.directions_run, color: Colors.blue),
                  title: const Text('Poner En Ruta'),
                  onTap: () => _procesarCambioEstado(context, 'En Ruta'), // 💡 CORREGIDO: Cambiado a onTap
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Marcar como Entregado'),
                  onTap: () => _procesarCambioEstado(context, 'Entregado'), // 💡 CORREGIDO: Cambiado a onTap
                ),
                ListTile(
                  leading: const Icon(Icons.cancel, color: SagaTheme.alertRed),
                  title: const Text('Marcar como No Entregado (Contingencia)'),
                  onTap: () => _procesarCambioEstado(context, 'No Entregado'), // 💡 CORREGIDO: Cambiado a onTap
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 💡 Procesa y valida las reglas de negocio antes de mandar los datos a Python
  void _procesarCambioEstado(BuildContext context, String nuevoEstado) async {
    Navigator.pop(context); // Cierra el menú inferior

    String? motivo;

    // 🔒 REGLA DE NEGOCIO: Si es "No Entregado", abrimos un prompt para exigir el motivo obligatoriamente
    if (nuevoEstado == 'No Entregado') {
      motivo = await _solicitarMotivoContingencia(context);
      if (motivo == null || motivo.trim().isEmpty) {
        _mostrarSnackBar('Operación cancelada. El motivo de contingencia es obligatorio.', esError: true);
        return;
      }
    }

    // Encendemos un indicador de carga circular en pantalla
    _mostrarCargando();

    try {
      final exito = await _apiDatasource.actualizarEstadoPedido(
        pedidoId: widget.pedido.id, // Asegúrate de que tu modelo use .id o .pedidoId
        nuevoEstado: nuevoEstado,
        motivoContingencia: motivo,
      );

      Navigator.pop(context); // Cierra el diálogo de carga

      if (exito) {
        setState(() {
          _estadoActual = nuevoEstado; // Actualiza el color de la tarjeta en tiempo real
        });
        _mostrarSnackBar('Estado actualizado a "$nuevoEstado" con éxito.');
      }
    } catch (e) {
      Navigator.pop(context); // Cierra el diálogo de carga si falla
      _mostrarSnackBar(e.toString().replaceAll('Exception: ', ''), esError: true);
    }
  }

  // Ventana emergente secundaria para redactar la contingencia
  Future<String?> _solicitarMotivoContingencia(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Reportar Contingencia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Escriba el motivo por el cual no se pudo entregar el pedido:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ej: Cliente ausente / Dirección incorrecta',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('CANCELAR')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SagaTheme.alertRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('REPORTAR'),
          ),
        ],
      ),
    );
  }

  void _mostrarCargando() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _mostrarSnackBar(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? SagaTheme.alertRed : Colors.green,
      ),
    );
  }

  Color _obtenerColorEstado(String estado) {
    switch (estado) {
      case 'Entregado': return Colors.green;
      case 'En Ruta': return Colors.blue;
      case 'No Entregado': return SagaTheme.alertRed;
      default: return SagaTheme.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esAlta = widget.pedido.prioridad == 'Alta';
    final Color colorEstado = _obtenerColorEstado(_estadoActual);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _mostrarOpcionesEstado(context), // 💡 Acción táctil añadida
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: esAlta ? SagaTheme.alertRed : Colors.grey,
                width: 6,
              ),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              widget.pedido.descripcionProducto,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Código: ${widget.pedido.codigoBarra}', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorEstado.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _estadoActual.toUpperCase(),
                    style: TextStyle(color: colorEstado, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            trailing: esAlta
                ? const Icon(Icons.flash_on, color: SagaTheme.alertRed)
                : const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ),
      ),
    );
  }
}
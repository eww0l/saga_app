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
                  onTap: () => _procesarCambioEstado(context, 'En Ruta'),
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Marcar como Entregado'),
                  onTap: () => _procesarCambioEstado(context, 'Entregado'),
                ),
                ListTile(
                  leading: const Icon(Icons.cancel, color: SagaTheme.alertRed),
                  title: const Text('Marcar como No Entregado (Contingencia)'),
                  onTap: () => _procesarCambioEstado(context, 'No Entregado'),
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

    if (nuevoEstado == 'No Entregado') {
      motivo = await _solicitarMotivoContingencia(context);
      if (motivo == null || motivo.trim().isEmpty) {
        _mostrarSnackBar('Operación cancelada. El motivo de contingencia es obligatorio.', esError: true);
        return;
      }
    }

    _mostrarCargando();

    try {
      final exito = await _apiDatasource.actualizarEstadoPedido(
        pedidoId: widget.pedido.id,
        nuevoEstado: nuevoEstado,
        motivoContingencia: motivo,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cierra el diálogo de carga

      if (exito) {
        setState(() {
          _estadoActual = nuevoEstado; // Actualiza el color de la tarjeta en tiempo real
        });
        _mostrarSnackBar('Estado actualizado a "$nuevoEstado" con éxito.');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Cierra el diálogo de carga si falla
      _mostrarSnackBar(e.toString().replaceAll('Exception: ', ''), esError: true);
    }
  }

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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => _mostrarOpcionesEstado(context),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: esAlta ? SagaTheme.alertRed : Colors.grey,
                width: 6,
              ),
            ),
          ),
          // 💡 SOLUCIÓN: El ListTile ahora es el ÚNICO hijo (child) del Container
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              widget.pedido.descripcionProducto,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text('Código: ${widget.pedido.codigoBarra}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                
                const SizedBox(height: 8),
                // 📍 Dirección del Cliente
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.pedido.direccionCliente.trim().isNotEmpty 
                            ? widget.pedido.direccionCliente 
                            : 'Dirección no registrada',
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                // 🛰️ Coordenadas GPS
                Row(
                  children: [
                    const Icon(Icons.pin_drop_outlined, size: 16, color: Colors.blueGrey),
                    const SizedBox(width: 6),
                    Text(
                      'Lat: ${widget.pedido.latitud}  |  Lng: ${widget.pedido.longitud}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600], fontFamily: 'monospace'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),
                // 🏷️ Estado del pedido
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorEstado.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _estadoActual.toUpperCase(),
                    style: TextStyle(color: colorEstado, fontSize: 11, fontWeight: FontWeight.bold),
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
  }}
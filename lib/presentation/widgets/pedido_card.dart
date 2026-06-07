import 'package:flutter/material.dart';
import '../../../data/datasources/pedidos_datasource.dart';
import '../../../data/models/pedido_model.dart';
import '../../core/theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class PedidoCard extends StatefulWidget {
  final PedidoModel pedido;
  final String courierId;
  final VoidCallback onEstadoActualizado;

  const PedidoCard({
    super.key, 
    required this.pedido, 
    required this.courierId,
    required this.onEstadoActualizado, // ⚡ AMARRE EN EL CONSTRUCTOR
  });

  @override
  State<PedidoCard> createState() => _PedidoCardState();
}

class _PedidoCardState extends State<PedidoCard> {
  final PedidosDatasource _apiDatasource = PedidosDatasource();
  late String _estadoActual;

  @override
  void initState() {
    super.initState();
    _estadoActual = widget.pedido.estado;
  }

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
                  title: const Text('Poner En Ruta (Revertir estado)'),
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

  void _procesarCambioEstado(BuildContext context, String nuevoEstado) async {
    Navigator.pop(context); 

    String? motivo;
    String? imagenBase64;

    // 1️⃣ Validación de Contingencia (No Entregado)
    if (nuevoEstado == 'No Entregado') {
      motivo = await _solicitarMotivoContingencia(context);
      if (motivo == null || motivo.trim().isEmpty) {
        _mostrarSnackBar('Operación cancelada. El motivo es obligatorio.', esError: true);
        return;
      }
    }

    // 2️⃣ 📸 Captura de Evidencia Fotográfica Opcional (Igual que en gestión pedido)
    if (nuevoEstado == 'Entregado' || nuevoEstado == 'No Entregado') {
      bool? quiereTomarFoto = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Evidencia Fotográfica', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text('¿Desea capturar una fotografía para respaldar el estado "$nuevoEstado"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('NO, OMITIR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: SagaTheme.primaryGreen),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('SÍ, CÁMARA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );

      if (quiereTomarFoto == true) {
        try {
          final picker = ImagePicker();
          final XFile? foto = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 50, // Comprimimos un poco más para que SharedPreferences no sufra en offline
            maxWidth: 1000,
          );

          if (foto != null) {
            final List<int> bytes = await File(foto.path).readAsBytes();
            imagenBase64 = base64Encode(bytes);
          }
        } catch (e) {
          _mostrarSnackBar('Error al acceder a la cámara: $e', esError: true);
          return;
        }
      }
    }

    _mostrarCargando();

    // 📡 Verificamos la red ANTES de disparar para forzar tu bloque offline si no hay señal real
    final bool tieneInternet = await _apiDatasource.verificarInternet();

    if (!tieneInternet) {
      // ❌ EJECUCIÓN OFFLINE DIRECTA (Forzamos la ejecución de tu bloque SharedPreferences sin pasar por la red)
      _ejecutarSincronizacionLocal(nuevoEstado, motivo, imagenBase64);
      return;
    }

    // 🌐 INTENTO ONLINE (Si el método dice que sí hay red)
    try {
      final exito = await _apiDatasource.actualizarEstadoPedido(
        pedidoId: widget.pedido.id,
        nuevoEstado: nuevoEstado,
        courierId: widget.courierId,
        motivoContingencia: motivo,
        fotoBase64: imagenBase64,
      );

      if (!mounted) return;
      Navigator.pop(context); // Quita el loader

      if (exito) {
        setState(() {
          _estadoActual = nuevoEstado;
        });
        _mostrarSnackBar('✅ Pedido actualizado en el servidor.');
      }
    } catch (e) {
      // 🚨 CONTROL DE CAÍDAS DE RED: Si la red falló a mitad de camino o dio timeout
      if (!mounted) return;
      Navigator.pop(context); // Quita el loader

      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('timeout') || errorMsg.contains('socket') || errorMsg.contains('connection')) {
        // Si el servidor falló por conectividad, lo metemos a la fuerza en tu SharedPreferences
        _ejecutarSincronizacionLocal(nuevoEstado, motivo, imagenBase64);
      } else {
        // Si es un error real del backend (Ej: 400 Bad Request, 500 Interno), mostramos la alerta
        _mostrarSnackBar(e.toString().replaceAll('Exception: ', ''), esError: true);
      }
    }
  }

  // 📦 Método interno para ejecutar la lógica de SharedPreferences de tu datasource
  void _ejecutarSincronizacionLocal(String nuevoEstado, String? motivo, String? fotoBase64) async {
    try {
      if (mounted) Navigator.of(context, rootNavigator: true).pop(); 

      await _apiDatasource.actualizarEstadoPedido(
        pedidoId: widget.pedido.id,
        nuevoEstado: nuevoEstado,
        courierId: widget.courierId,
        motivoContingencia: motivo,
        fotoBase64: fotoBase64,
      );

      // 👁️ INSPECTOR DE SEGURIDAD (Agrega estas líneas):
      final prefs = await SharedPreferences.getInstance();
      final cola = prefs.getStringList('cola_actualizaciones') ?? [];
      print('🔥 TOTAL DE PEDIDOS EN COLA OFFLINE: ${cola.length}');
      if (cola.isNotEmpty) {
        print('📦 ÚLTIMO REGISTRO EN DISCO: ${cola.last}');
      }

      setState(() { _estadoActual = nuevoEstado; });
      _mostrarSnackBar('📦 Guardado en la cola local (Offline).');
      widget.onEstadoActualizado();
    } catch (localError) {
      // Si algo falla aquí, también nos aseguramos de que no se quede colgado el loader
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _mostrarSnackBar('Error al guardar localmente: $localError', esError: true);
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
        backgroundColor: esError ? SagaTheme.alertRed : (mensaje.contains('📦') ? Colors.orange[800] : Colors.green),
        duration: const Duration(seconds: 3),
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
                // 🚀 AGREGADO: Inyección limpia de Coordenadas requeridas para el Courier
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.map_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Lat: ${widget.pedido.latitud.toStringAsFixed(6)} / Lng: ${widget.pedido.longitud.toStringAsFixed(6)}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
  }
}
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../../data/datasources/api_datasource.dart';

class GestionPedidoScreen extends StatefulWidget {
  final Map<String, dynamic> pedido;

  const GestionPedidoScreen({super.key, required this.pedido});

  @override
  State<GestionPedidoScreen> createState() => _GestionPedidoScreenState();
}

class _GestionPedidoScreenState extends State<GestionPedidoScreen> {
  final ApiDatasource _apiDatasource = ApiDatasource();
  String? _estadoSeleccionado;
  String? _motivoContingencia;
  bool _isSaving = false;

  // Lista de motivos oficiales según el estándar de Saga Falabella
  final List<String> _motivos = [
    'Cliente ausente',
    'Dirección incorrecta o no existe',
    'Zona peligrosa / Rechazado por seguridad',
    'Paquete dañado / Rechazado por cliente',
    'No hubo tiempo para la entrega',
  ];

  void _guardarGestion() async {
    if (_estadoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, seleccione un resultado de entrega.')),
      );
      return;
    }

    if (_estadoSeleccionado == 'No Entregado' && _motivoContingencia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe seleccionar obligatoriamente un motivo de contingencia.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Llamamos a la API con los parámetros nombrados exactos
      final exito = await _apiDatasource.actualizarEstadoPedido(
        pedidoId: widget.pedido['id'],
        nuevoEstado: _estadoSeleccionado!,
        motivoContingencia: _estadoSeleccionado == 'No Entregado' ? _motivoContingencia : null,
      );

      if (exito && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Pedido actualizado a $_estadoSeleccionado'),
            backgroundColor: SagaTheme.primaryGreen,
          ),
        );
        // Regresamos al escáner de la cámara limpiando la pantalla
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cliente = widget.pedido['clientes'] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Entrega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isSaving 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Resumen rápido del paquete
                Text(widget.pedido['codigo_barra'] ?? '', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                Text(widget.pedido['descripcion_producto'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Divider(height: 30),
                Text('Cliente: ${cliente['nombre']}', style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 6),
                Text('Dirección: ${cliente['direccion']}, ${cliente['distrito']}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const Divider(height: 40),

                const Text('RESULTADO DE LA VISITA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 12),

                // Tarjeta Opción: Entregado
                Card(
                  elevation: 0,
                  color: _estadoSeleccionado == 'Entregado' ? SagaTheme.primaryGreen.withOpacity(0.1) : Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: _estadoSeleccionado == 'Entregado' ? SagaTheme.primaryGreen : Colors.transparent),
                  ),
                  child: RadioListTile<String>(
                    title: const Text('Pedido Entregado con Éxito', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('El paquete fue recibido conforme en el domicilio.'),
                    value: 'Entregado',
                    groupValue: _estadoSeleccionado,
                    activeColor: SagaTheme.primaryGreen,
                    onChanged: (val) => setState(() {
                      _estadoSeleccionado = val;
                      _motivoContingencia = null;
                    }),
                  ),
                ),
                const SizedBox(height: 10),

                // Tarjeta Opción: No Entregado
                Card(
                  elevation: 0,
                  color: _estadoSeleccionado == 'No Entregado' ? Colors.red.withOpacity(0.1) : Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: _estadoSeleccionado == 'No Entregado' ? Colors.red : Colors.transparent),
                  ),
                  child: RadioListTile<String>(
                    title: const Text('Pedido NO Entregado', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    subtitle: const Text('Ocurrió un problema o contingencia en el punto.'),
                    value: 'No Entregado',
                    groupValue: _estadoSeleccionado,
                    activeColor: Colors.red,
                    onChanged: (val) => setState(() => _estadoSeleccionado = val),
                  ),
                ),

                // Desplegable de Motivos (Solo aparece si se marca como NO ENTREGADO)
                if (_estadoSeleccionado == 'No Entregado') ...[
                  const SizedBox(height: 20),
                  const Text('MOTIVO DE CONTINGENCIA *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Seleccione un motivo corporativo'),
                        value: _motivoContingencia,
                        items: _motivos.map((String motivo) {
                          return DropdownMenuItem<String>(value: motivo, child: Text(motivo));
                        }).toList(),
                        onChanged: (val) => setState(() => _motivoContingencia = val),
                      ),
                    ),
                  ),
                ],

                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SagaTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _guardarGestion,
                    child: const Text('CONFIRMAR Y FINALIZAR GESTIÓN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
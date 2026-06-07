import 'package:flutter/material.dart';
import '../../../data/models/pedido_model.dart';
import '../controllers/gestion_pedido_controller.dart';
import '../../core/theme.dart';

class GestionPedidoScreen extends StatefulWidget {
  final PedidoModel pedido;
  final String courierId; // 🔒 Recibe el ID de sesión del transportista

  const GestionPedidoScreen({
    super.key, 
    required this.pedido,
    required this.courierId,
  });

  @override
  State<GestionPedidoScreen> createState() => _GestionPedidoScreenState();
}

// 🛠️ CORRECCIÓN: Eliminada la clase fantasma de mapas. Declaración limpia del State:
class _GestionPedidoScreenState extends State<GestionPedidoScreen> {
  late final GestionPedidoController _controller;
  
  String? _estadoSeleccionado;
  String? _motivoContingencia;

  final List<String> _motivos = const [
    'Cliente ausente',
    'Dirección incorrecta o no existe',
    'Zona peligrosa / Rechazado por seguridad',
    'Paquete dañado / Rechazado por cliente',
    'No hubo tiempo para la entrega',
  ];

  @override
  void initState() {
    super.initState();
    _controller = GestionPedidoController();
  }

  @override
  void dispose() {
    _controller.dispose(); 
    super.dispose();
  }

  // ... El resto de tu método @override Widget build(BuildContext context) se queda exactamente igual abajo

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Entrega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isSavingState) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.pedido.codigoBarra, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                Text(widget.pedido.descripcionProducto, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Divider(height: 30),
                Text('Cliente: ${widget.pedido.nombreCliente}', style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 6),
                Text('Dirección: ${widget.pedido.direccionCliente}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
                    onPressed: () async {
                      if (_estadoSeleccionado == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, seleccione un resultado.')));
                        return;
                      }

                      final localContext = context;

                      // 🔒 SOLUCCIÓN INTERNA: Pasamos el courierId inyectado desde la vista anterior
                      final exito = await _controller.actualizarEstado(
                        pedido: widget.pedido,
                        nuevoEstado: _estadoSeleccionado!,
                        courierId: widget.courierId, 
                        motivo: _motivoContingencia,
                      );

                      if (!mounted) return;

                      if (exito) {
                        ScaffoldMessenger.of(localContext).showSnackBar(
                          const SnackBar(content: Text('✅ Pedido actualizado'), backgroundColor: SagaTheme.primaryGreen),
                        );
                        Navigator.pop(localContext, true);
                      } else if (_controller.errorMessage != null) {
                        ScaffoldMessenger.of(localContext).showSnackBar(
                          SnackBar(content: Text(_controller.errorMessage!), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: const Text('CONFIRMAR Y FINALIZAR GESTIÓN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
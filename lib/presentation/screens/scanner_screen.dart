import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme.dart';
import '../../../data/datasources/api_datasource.dart';
import 'gestion_pedido_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ApiDatasource _apiDatasource = ApiDatasource();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  
  bool _isProcessing = false;
  final List<Map<String, dynamic>> _listaCargaTemporal = [];

  void _onCodeDetected(String codigo) async {
    if (_isProcessing) return; 

    setState(() => _isProcessing = true);
    _mostrarCargando();

    try {
      final pedidoData = await _apiDatasource.buscarPedidoPorCodigo(codigo);
      
      if (!mounted) return;
      Navigator.pop(context); // Cierra loading

      final String estadoActual = pedidoData['estado'] ?? 'Asignado';

      // ======================================================================
      // 1️⃣ MODO CARGA (Almacén)
      // ======================================================================
      if (estadoActual == 'Asignado') {
        bool yaExiste = _listaCargaTemporal.any((p) => p['codigo'] == codigo);
        
        if (yaExiste) {
          _mostrarErrorScan('El paquete $codigo ya está agregado a la lista de carga.');
          return;
        }

        setState(() {
          _listaCargaTemporal.add({
            'id': pedidoData['id'],
            'codigo': pedidoData['codigo_barra'],
            'producto': pedidoData['descripcion_producto'] ?? 'Producto Sin Nombre',
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📦 Paquete $codigo agregado a la carga'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 1),
          ),
        );

        _activarTiempoEnfriamiento();
      } 
      // ======================================================================
      // 2️⃣ MODO ENTREGA (Calle)
      // ======================================================================
      else if (estadoActual == 'En Ruta') {
        _mostrarFichaPedidoEmergente(pedidoData);
      } 
      else {
        _mostrarErrorScan('El paquete ya figura como: $estadoActual');
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _mostrarErrorScan(e.toString());
      }
    }
  }

  // 💡 Muestra la lista desplegable hacia arriba para eliminar uno por uno
  void _mostrarMenuDesplegablePaquetes() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // StatefulBuilder nos permite actualizar la lista dentro de la persiana en tiempo real
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'DETALLE DE CARGA (${_listaCargaTemporal.length} PAQUETES)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  _listaCargaTemporal.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: Center(child: Text('No hay paquetes en el manifiesto actual.', style: TextStyle(color: Colors.grey))),
                        )
                      : Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _listaCargaTemporal.length,
                            itemBuilder: (context, index) {
                              final item = _listaCargaTemporal[index];
                              return Card(
                                elevation: 0,
                                color: Colors.grey[100],
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                                  title: Text(item['producto'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(item['codigo'], style: const TextStyle(color: Colors.blue)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    onPressed: () {
                                      // ❌ Eliminación uno por uno
                                      setState(() {
                                        _listaCargaTemporal.removeAt(index);
                                      });
                                      setModalState(() {}); // Refresca ventana emergente
                                      if (_listaCargaTemporal.isEmpty) {
                                        Navigator.pop(context); // Cierra si ya no quedan
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarFichaPedidoEmergente(Map<String, dynamic> pedido) {
    final cliente = pedido['clientes'] ?? {};
    final String nombreCliente = cliente['nombre'] ?? 'No especificado';
    final String direccionCliente = '${cliente['direccion'] ?? ''}, ${cliente['distrito'] ?? ''}';

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('MODO ENTREGA (EN CLIENTE)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 11)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(pedido['codigo_barra'] ?? '', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(pedido['descripcion_producto'] ?? 'Producto Falabella', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Cliente: $nombreCliente', style: const TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Dirección: $direccionCliente', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () => _cerrarFichaYReactivarCamara(),
                      child: const Text('CERRAR', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: SagaTheme.primaryGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () async {
                        Navigator.pop(context); 
                        final resultado = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GestionPedidoScreen(pedido: pedido),
                          ),
                        );

                        if (resultado == true) {
                          _activarTiempoEnfriamiento();
                        } else {
                          setState(() => _isProcessing = false);
                        }
                      },
                      child: const Text('GESTIONAR', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrirIngresoManual() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Código Ilegible', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(labelText: 'Digitar Código de Barras', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SagaTheme.primaryGreen, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.trim().isNotEmpty) {
                _onCodeDetected(controller.text.trim());
              }
            },
            child: const Text('BUSCAR'),
          ),
        ],
      ),
    );
  }

  void _procesarDespachoEnRuta() async {
    _mostrarCargando(); 

    try {
      for (var item in _listaCargaTemporal) {
        final int idPedido = item['id'];
        await _apiDatasource.actualizarEstadoPedido(
          pedidoId: idPedido, 
          nuevoEstado: 'En Ruta',
        );
      }

      if (!mounted) return;
      Navigator.pop(context); 

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚀 ¡Despacho confirmado! Los paquetes ya están En Ruta.'),
          backgroundColor: SagaTheme.primaryGreen,
        ),
      );

      setState(() {
        _listaCargaTemporal.clear();
      });

    } catch (e) {
      if (mounted) Navigator.pop(context); 
      _mostrarErrorScan('Error al subir la carga: ${e.toString()}');
    }
  }

  void _mostrarCargando() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _cerrarFichaYReactivarCamara() {
    Navigator.pop(context);
    _activarTiempoEnfriamiento();
  }

  void _activarTiempoEnfriamiento() {
    _isProcessing = true; 
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    });
  }

  void _mostrarErrorScan(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: Colors.red),
    );
    _activarTiempoEnfriamiento();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 🎥 PARTE SUPERIOR: Cámara dinámica
          Expanded(
            flex: 7,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                      _onCodeDetected(barcodes.first.rawValue!);
                    }
                  },
                ),
                Positioned.fill(
                  child: Container(
                    decoration: ShapeDecoration(
                      shape: QrScannerOverlayShape(
                        borderColor: SagaTheme.primaryGreen,
                        borderRadius: 12,
                        borderLength: 30,
                        borderWidth: 6,
                        cutOutSize: 220,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    foregroundColor: Colors.black87,
                    onPressed: _abrirIngresoManual,
                    child: const Icon(Icons.keyboard_outlined),
                  ),
                ),
              ],
            ),
          ),

          // 📦 PARTE INFERIOR: Panel de control adaptable simplificado con menú interactivo
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: _listaCargaTemporal.isEmpty
                  ? Center(
                      child: Text(
                        'Modo Inteligente Falabella\n\n• Si el paquete está en Almacén, se agregará a la carga.\n• Si ya está En Ruta, abrirá la ficha del cliente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Botón de acceso al menú desplegable hacia arriba (Persiana)
                        InkWell(
                          onTap: _mostrarMenuDesplegablePaquetes,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.playlist_add_check, color: SagaTheme.primaryGreen),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Manifiesto: ${_listaCargaTemporal.length} paquetes escaneados',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.keyboard_arrow_up, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Botón de acción principal
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SagaTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _procesarDespachoEnRuta,
                            child: const Text('CONFIRMAR CARGA E INICIAR VIAJE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
// ==========================================================================
// 🎨 PINTOR DE MÁSCARA PERSONALIZADO (EvenOdd nativo para MobileScanner)
// ==========================================================================
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double borderLength;
  final double borderRadius;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 4.0,
    this.borderLength = 20.0,
    this.borderRadius = 0.0,
    this.cutOutSize = 250.0,
  });

  @override EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();
  @override Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.5)..style = PaintingStyle.fill;
    final cutOutRect = Rect.fromLTWH((width - cutOutSize) / 2, (height - cutOutSize) / 2, cutOutSize, cutOutSize);

    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)));

    canvas.drawPath(path, backgroundPaint);
    final borderPaint = Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = borderWidth;
    final rrect = RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius));
    
    canvas.drawPath(Path()..moveTo(rrect.left, rrect.top + borderLength)..lineTo(rrect.left, rrect.top)..lineTo(rrect.left + borderLength, rrect.top), borderPaint);
    canvas.drawPath(Path()..moveTo(rrect.right - borderLength, rrect.top)..lineTo(rrect.right, rrect.top)..lineTo(rrect.right, rrect.top + borderLength), borderPaint);
    canvas.drawPath(Path()..moveTo(rrect.right, rrect.bottom - borderLength)..lineTo(rrect.right, rrect.bottom)..lineTo(rrect.right - borderLength, rrect.bottom), borderPaint);
    canvas.drawPath(Path()..moveTo(rrect.left + borderLength, rrect.bottom)..lineTo(rrect.left, rrect.bottom)..lineTo(rrect.left, rrect.bottom - borderLength), borderPaint);
  }

  @override ShapeBorder scale(double t) => this;
}
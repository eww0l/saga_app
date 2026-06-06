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

  // 📦 Lista temporal para acumular los paquetes en el almacén (Fase de Carga)
  // Almacena mapas con la estructura: {'id': 1, 'codigo': 'FAL-123', 'producto': 'Televisor...'}
  final List<Map<String, dynamic>> _listaCargaTemporal = [];

  void _onCodeDetected(String codigo) async {
    // 🔒 CAPA DE CONTROL: Bloquea lecturas si ya se está consultando o está en enfriamiento
    if (_isProcessing) return; 

    setState(() => _isProcessing = true);
    _mostrarCargando();

    try {
      // Consulta real a tu backend de Python
      final pedidoData = await _apiDatasource.buscarPedidoPorCodigo(codigo);
      
      if (!mounted) return;
      Navigator.pop(context); // Cierra el loading

      final String estadoActual = pedidoData['estado'] ?? 'Asignado';

      // ======================================================================
      // 🚛 LÓGICA A: MODO CARGA (El paquete aún está en el Almacén)
      // ======================================================================
      if (estadoActual == 'Asignado') {
        // Validar si el paquete ya fue escaneado en esta sesión para evitar duplicados
        bool yaExiste = _listaCargaTemporal.any((p) => p['codigo'] == codigo);
        
        if (yaExiste) {
          _mostrarErrorScan('El paquete $codigo ya está agregado a la lista de carga.');
          return;
        }

        // Si es nuevo, lo agregamos a la lista temporal en pantalla
        setState(() {
          _listaCargaTemporal.add({
            'id': pedidoData['id'],
            'codigo': pedidoData['codigo_barra'],
            'producto': pedidoData['descripcion_producto'] ?? 'Producto Sin Nombre',
          });
        });

        // Feedback visual rápido de éxito sin romper el flujo de la cámara
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📦 Paquete $codigo agregado a la carga'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 1),
          ),
        );

        // Activamos los 2 segundos de gracia para mover la caja antes de leer otra
        _activarTiempoEnfriamiento();
      } 
      // ======================================================================
      // 🏠 LÓGICA B: MODO ENTREGA (El paquete ya está en la calle "En Ruta")
      // ======================================================================
      else if (estadoActual == 'En Ruta') {
        _mostrarFichaPedidoEmergente(pedidoData);
      } 
      // Si el paquete ya fue entregado o tiene otro estado no gestionable
      else {
        _mostrarErrorScan('El paquete ya figura como: $estadoActual');
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cierra el loading si falla la API
        _mostrarErrorScan(e.toString());
      }
    }
  }

  // 💡 Muestra la ficha del cliente cuando el paquete ya está en camino (Fase Calle)
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
                        // 1. Cerramos esta persiana emergente primero
                        Navigator.pop(context); 

                        // 2. Viajamos a la pantalla completa de gestión pasándole el mapa del pedido
                        final resultado = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GestionPedidoScreen(pedido: pedido),
                          ),
                        );

                        // 3. Evaluamos cómo regresó el chofer de esa pantalla
                        if (resultado == true) {
                          // Si guardó con éxito, disparamos los 2 segundos de enfriamiento para no leer en bucle
                          _activarTiempoEnfriamiento();
                        } else {
                          // Si regresó con la flecha de atrás sin hacer nada, abrimos la escucha al instante
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
        
        // 💡 CORRECCIÓN AQUÍ: Se pasan los parámetros nombrados requeridos
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
          // 🎥 PARTE SUPERIOR: Cámara dinámica (Ocupa el 60% de la pantalla)
          Expanded(
            flex: 8,
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

          // 📦 PARTE INFERIOR: Panel de control adaptable (Ocupa el 40% restante)
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: _listaCargaTemporal.isEmpty
                  ? Center(
                      child: Text(
                        'Modo Inteligente Falabella\n\n• Si el paquete está en Almacén, se agregará a la carga.\n• Si ya está En Ruta, abrirá la ficha del cliente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'MANIFIESTO DE CARGA (${_listaCargaTemporal.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _listaCargaTemporal.clear()),
                              child: const Text('Limpiar todo', style: TextStyle(color: Colors.red, fontSize: 12)),
                            )
                          ],
                        ),
                        Expanded(
                          child: ListView.builder(
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
                                    icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _listaCargaTemporal.removeAt(index);
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SagaTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _procesarDespachoEnRuta,
                            child: const Text('CONFIRMAR CARGA E INICIAR VIAJE', style: TextStyle(fontWeight: FontWeight.bold)),
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

// Pintor de máscara personalizado (EvenOdd nativo)
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
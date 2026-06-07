import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme.dart';
import '../controllers/scanner_controller.dart';
import '../widgets/scanner/qr_scanner_overlay_shape.dart';
import '../widgets/scanner/scanner_manifest_sheet.dart';
import 'gestion_pedido_screen.dart';
import '../../data/models/pedido_model.dart';

class ScannerScreen extends StatefulWidget {
  final String courierId; // 🔒 NUEVO: Recibe el ID de sesión del transportista
  final String empresa;   // 🔒 NUEVO: Recibe la empresa activa en el Login

  const ScannerScreen({
    super.key,
    required this.courierId,
    required this.empresa,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ScannerController _logicaController = ScannerController();
  
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void initState() {
    super.initState();
    _logicaController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _logicaController.dispose();
    super.dispose();
  }

  void _onCodeDetected(String codigo) async {
    if (_logicaController.isProcessing) return;

    _mostrarCargando();

    // 🚀 SOLUCIÓN 1: Pasamos los parámetros obligatorios de sesión al controlador
    final PedidoModel? pedido = await _logicaController.escanearCodigo(
      codigo,
      courierId: widget.courierId,
      empresa: widget.empresa,
    );

    if (!mounted) return;
    Navigator.pop(context); // Cierra el spinner de carga de forma segura

    if (_logicaController.errorMessage != null) {
      _mostrarErrorScan(_logicaController.errorMessage!);
      return;
    }

    if (pedido != null) {
      if (pedido.estado == 'Asignado') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📦 Paquete ${pedido.codigoBarra} agregado a la carga'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 1),
          ),
        );
      } else if (pedido.estado == 'En Ruta') {
        _mostrarFichaPedidoEmergente(pedido);
      }
    }
  }

  void _mostrarMenuDesplegablePaquetes() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ScannerManifestSheet(controller: _logicaController);
      },
    );
  }

  void _mostrarFichaPedidoEmergente(PedidoModel pedido) {
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
                    child: Text(pedido.codigoBarra, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(pedido.descripcionProducto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Cliente: ${pedido.nombreCliente}', style: const TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Dirección: ${pedido.direccionCliente}', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () {
                        Navigator.pop(context);
                        _logicaController.forzarDesbloqueoProcesamiento();
                      },
                      child: const Text('CERRAR', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SagaTheme.primaryGreen, 
                        foregroundColor: Colors.white, 
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final navContext = Navigator.of(context);
                        navContext.pop(); 
                        
                        // 🚀 SOLUCIÓN 2: Inyectamos el courierId requerido al constructor de GestionPedidoScreen
                        final resultado = await navContext.push(
                          MaterialPageRoute(
                            builder: (context) => GestionPedidoScreen(
                              pedido: pedido,
                              courierId: widget.courierId,
                            ),
                          ),
                        );

                        if (resultado != true) {
                          _logicaController.forzarDesbloqueoProcesamiento();
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
    
    final localContext = context;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // 🚀 SOLUCIÓN 3: Enviamos el courierId requerido para procesar el lote masivo
    final exito = await _logicaController.confirmarDespacho(courierId: widget.courierId);

    if (!mounted) return;
    Navigator.pop(localContext); 

    if (exito) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('🚀 ¡Despacho confirmado! Los paquetes ya están En Ruta.'),
          backgroundColor: SagaTheme.primaryGreen,
        ),
      );
    } else if (_logicaController.errorMessage != null) {
      _mostrarErrorScan(_logicaController.errorMessage!);
    }
  }

  void _mostrarCargando() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _mostrarErrorScan(String error) {
  // 🔒 CONTROL DE SEGURIDAD VISTA: Si la pantalla ya no está montada, no pintes nada
  if (!mounted) return;

  // 🧹 Limpia de inmediato cualquier SnackBar viejo que esté colgado en pantalla
  ScaffoldMessenger.of(context).clearSnackBars(); 

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        error,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ), 
      backgroundColor: Colors.red.shade800,
      duration: const Duration(seconds: 2), // ⏱️ Lo alineamos exactamente al tiempo de enfriamiento
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
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
                    decoration: const ShapeDecoration(
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
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: _logicaController.listaCargaTemporal.isEmpty
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
                                      'Manifiesto: ${_logicaController.listaCargaTemporal.length} paquetes escaneados',
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
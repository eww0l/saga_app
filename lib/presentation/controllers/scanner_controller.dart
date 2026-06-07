import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/datasources/pedidos_datasource.dart';
import '../../../data/models/pedido_model.dart';

class ScannerController extends ChangeNotifier {
  final PedidosDatasource _datasource = PedidosDatasource();

  bool _isProcessing = false;
  final List<PedidoModel> _listaCargaTemporal = [];
  String? _errorMessage;
  
  // 🔒 Bandera de seguridad para evitar fugas de memoria y llamadas post-dispose
  bool _isDisposed = false;

  bool get isProcessing => _isProcessing;
  List<PedidoModel> get listaCargaTemporal => _listaCargaTemporal;
  String? get errorMessage => _errorMessage;
  

  // 📡 Modificado para enviar parámetros B2B al datasource con desempaque seguro
  Future<PedidoModel?> escanearCodigo(String codigo, {required String courierId, required String empresa}) async {
    if (_isProcessing || _isDisposed) return null;

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 🔒 Inyectamos seguridad B2B en la consulta
      final dynamic jsonPedido = await _datasource.buscarPedidoPorCodigo(
        codigo,
        courierId: courierId,
        empresa: empresa,
      );
      
      if (_isDisposed) return null; 
      
      Map<String, dynamic> mapaCorrecto;

      // 🧠 NORMALIZACIÓN EXTREMA DE MAPAS (Evita crasheos por anidación)
      if (jsonPedido is Map<String, dynamic>) {
        if (jsonPedido.containsKey('pedido') && jsonPedido['pedido'] is Map) {
          mapaCorrecto = Map<String, dynamic>.from(jsonPedido['pedido'] as Map);
        } else {
          mapaCorrecto = jsonPedido;
        }
      } else {
        throw Exception("Estructura de respuesta inválida del sistema.");
      }

      if (mapaCorrecto.isEmpty || !mapaCorrecto.containsKey('id')) {
        throw Exception("El paquete no cuenta con información válida en el sistema.");
      }

      final pedido = PedidoModel.fromJson(mapaCorrecto);

      if (pedido.estado == 'Asignado') {
        bool yaExiste = _listaCargaTemporal.any((p) => p.codigoBarra == codigo);
        if (yaExiste) {
          _errorMessage = 'El paquete $codigo ya está agregado a la lista de carga.';
          _activarTiempoEnfriamiento();
          return null;
        }

        _listaCargaTemporal.add(pedido);
        _activarTiempoEnfriamiento();
        return pedido;
      } 
      
      if (pedido.estado == 'En Ruta') {
        _activarTiempoEnfriamiento();
        return pedido;
      }

      _errorMessage = 'El paquete ya figura como: ${pedido.estado}';
      _activarTiempoEnfriamiento();
      return null;

    } catch (e) {
      if (_isDisposed) return null;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _activarTiempoEnfriamiento();
      return null;
    }
  }

  // 🚀 Modificado para incluir el courier_id transaccional en el lote masivo
  Future<bool> confirmarDespacho({required String courierId}) async {
    if (_listaCargaTemporal.isEmpty || _isDisposed) return false;

    _isProcessing = true;
    notifyListeners();

    try {
      for (var pedido in _listaCargaTemporal) {
        if (_isDisposed) return false;
        await _datasource.actualizarEstadoPedido(
          pedidoId: pedido.id,
          nuevoEstado: 'En Ruta',
          courierId: courierId, // 🚀 Pasamos el parámetro requerido al lote
        );
      }
      
      if (_isDisposed) return false;
      
      _listaCargaTemporal.clear();
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (_isDisposed) return false;
      _errorMessage = 'Error al subir la carga: ${e.toString()}';
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  void removerItemDeCarga(int index) {
    if (index >= 0 && index < _listaCargaTemporal.length) {
      _listaCargaTemporal.removeAt(index);
      notifyListeners();
    }
  }

  void forzarDesbloqueoProcesamiento() {
    if (_isDisposed) return;
    _isProcessing = false;
    notifyListeners();
  }

  void _activarTiempoEnfriamiento() {
    _isProcessing = true;
    notifyListeners();
    Future.delayed(const Duration(seconds: 2), () {
      // 🔒 INTERCEPCIÓN CRÍTICA: Si cambiaste de pestaña rápido y el controlador murió,
      // frenamos en seco antes de mutar estado o llamar a notifyListeners()
      if (_isDisposed) return;
      
      _isProcessing = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _isDisposed = true; // Cambiamos la bandera inmediatamente para bloquear hilos paralelos huerfanos
    super.dispose();
  }
}
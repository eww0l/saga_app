import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/datasources/pedidos_datasource.dart';
import '../../../data/models/pedido_model.dart';

class ScannerController extends ChangeNotifier {
  final PedidosDatasource _datasource = PedidosDatasource();

  bool _isProcessing = false;
  final List<PedidoModel> _listaCargaTemporal = [];
  String? _errorMessage;

  bool get isProcessing => _isProcessing;
  List<PedidoModel> get listaCargaTemporal => _listaCargaTemporal;
  String? get errorMessage => _errorMessage;

  // 📡 Busca un pedido y determina el modo logístico (Carga o Entrega)
  Future<PedidoModel?> escanearCodigo(String codigo) async {
    if (_isProcessing) return null;

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final jsonPedido = await _datasource.buscarPedidoPorCodigo(codigo);
      final pedido = PedidoModel.fromJson(jsonPedido);

      // 1️⃣ MODO CARGA (Almacén)
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
      
      // 2️⃣ MODO ENTREGA (Ruta activa)
      if (pedido.estado == 'En Ruta') {
        return pedido;
      }

      _errorMessage = 'El paquete ya figura como: ${pedido.estado}';
      _activarTiempoEnfriamiento();
      return null;

    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _activarTiempoEnfriamiento();
      return null;
    }
  }

  // 🚀 Confirma masivamente el manifiesto local y cambia el estado a 'En Ruta'
  Future<bool> confirmarDespacho() async {
    if (_listaCargaTemporal.isEmpty) return false;

    _isProcessing = true;
    notifyListeners();

    try {
      for (var pedido in _listaCargaTemporal) {
        await _datasource.actualizarEstadoPedido(
          pedidoId: pedido.id,
          nuevoEstado: 'En Ruta',
        );
      }
      _listaCargaTemporal.clear();
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
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
    _isProcessing = false;
    notifyListeners();
  }

  void _activarTiempoEnfriamiento() {
    _isProcessing = true;
    notifyListeners();
    Future.delayed(const Duration(seconds: 2), () {
      _isProcessing = false;
      notifyListeners();
    });
  }
}
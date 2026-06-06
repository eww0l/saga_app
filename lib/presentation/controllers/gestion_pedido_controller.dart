import 'package:flutter/material.dart';
import '../../../data/datasources/pedidos_datasource.dart';
import '../../../data/models/pedido_model.dart';

class GestionPedidoController extends ChangeNotifier {
  final PedidosDatasource _datasource = PedidosDatasource();

  bool _isSaving = false;
  String? _errorMessage;

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  // 🚀 Procesa el cambio de estado de un paquete aceptando PedidoModel
  Future<bool> actualizarEstado({
    required PedidoModel pedido,
    required String nuevoEstado,
    String? motivo,
  }) async {
    if (nuevoEstado == 'No Entregado' && (motivo == null || motivo.trim().isEmpty)) {
      _errorMessage = 'El motivo de contingencia es obligatorio para estados fallidos.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final exito = await _datasource.actualizarEstadoPedido(
        pedidoId: pedido.id,
        nuevoEstado: nuevoEstado,
        motivoContingencia: nuevoEstado == 'No Entregado' ? motivo : null,
      );

      _isSaving = false;
      notifyListeners();
      return exito;
    } catch (e) {
      _isSaving = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
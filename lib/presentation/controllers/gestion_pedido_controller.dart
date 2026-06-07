import 'package:flutter/material.dart';
import '../../../data/datasources/pedidos_datasource.dart';
import '../../../data/models/pedido_model.dart';

class GestionPedidoController extends ChangeNotifier {
  final PedidosDatasource _datasource = PedidosDatasource();

  bool _isSaving = false;
  String? _errorMessage;

  bool get isSaving => _isSaving;
  bool get isSavingState => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<bool> actualizarEstado({
    required PedidoModel pedido,
    required String nuevoEstado,
    required String courierId, 
    String? motivo,
    String? fotoBase64, 
  }) async {
    // 🔒 El motivo sigue siendo obligatorio solo si es un fallo
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
        courierId: courierId, 
        motivoContingencia: nuevoEstado == 'No Entregado' ? motivo : null,
        fotoBase64: fotoBase64, // 🚀 Viaja limpio al datasource (sea el estado que sea)
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
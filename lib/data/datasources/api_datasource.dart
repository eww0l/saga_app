import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pedido_model.dart';

class ApiDatasource {
  final String baseUrl = "http://10.0.2.2:8000/api"; 

  // 💡 ÚNICO MÉTODO PARA ACTUALIZAR ESTADO (Soporta carga y entregas/contingencias)
  Future<bool> actualizarEstadoPedido({
    required int pedidoId,
    required String nuevoEstado,
    String? motivoContingencia,
  }) async {
    try {
      String urlString = '$baseUrl/pedidos/$pedidoId/estado?nuevo_estado=$nuevoEstado';
      
      if (motivoContingencia != null && motivoContingencia.trim().isNotEmpty) {
        urlString += '&motivo_contingencia=${Uri.encodeComponent(motivoContingencia)}';
      }

      final url = Uri.parse(urlString);
      final response = await http.put(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'success') {
          return true;
        }
        return false;
      } else {
        final Map<String, dynamic> errorBody = json.decode(response.body);
        throw Exception(errorBody['detail'] ?? 'Error al actualizar estado');
      }
    } catch (e) {
      throw Exception('Error en el servidor: $e');
    }
  }

  // 💡 BUSCADOR POR CÓDIGO DE BARRAS
  Future<Map<String, dynamic>> buscarPedidoPorCodigo(String codigoBarra) async {
    try {
      final url = Uri.parse('$baseUrl/pedidos/escanear/$codigoBarra');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['pedido'] ?? {};
      } else if (response.statusCode == 404) {
        final Map<String, dynamic> errorBody = json.decode(response.body);
        throw Exception(errorBody['detail'] ?? 'El paquete no existe en el sistema.');
      } else {
        throw Exception('Error del servidor: Código ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // 💡 OBTENER PEDIDOS POR COURIER (Modificado para soportar el enrutamiento del mapa)
Future<Map<String, dynamic>> fetchPedidosPorCourier(
  String courierId,
  String empresa, {
  double? latGps,
  double? lngGps,
}) async {
  final url = Uri.parse(
    '$baseUrl/pedidos-courier?courier_id=$courierId&empresa=${Uri.encodeComponent(empresa)}'
    '${latGps != null && lngGps != null ? '&lat_gps=$latGps&lng_gps=$lngGps' : ''}',
  );

  final response = await http.get(url);

  if (response.statusCode != 200) {
    throw Exception("Error servidor ${response.statusCode}");
  }

  final data = json.decode(response.body);

  if (data['error_detectado'] != null) {
    throw Exception(data['error_detectado']);
  }

  final List pedidosJson = data['pedidos'] ?? [];

  return {
    "pedidos": pedidosJson.map((e) => PedidoModel.fromJson(e)).toList(),
    "ruta_osrm": data['ruta_osrm'] ?? [],
  };
}
Future<Map<String, dynamic>> fetchRutaCourier(
  String courierId,
  String empresa,
  double latGps,
  double lngGps,
) async {
  try {
    final url = Uri.parse(
      '$baseUrl/pedidos-courier?courier_id=$courierId&empresa=${Uri.encodeComponent(empresa)}'
      '&lat_gps=$latGps&lng_gps=$lngGps',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception("Error servidor");
    }

    final data = json.decode(response.body);

    return {
      "pedidos": data['pedidos'] ?? [],
      "ruta_osrm": data['ruta_osrm'] ?? [],
    };
  } catch (e) {
    throw Exception("Error conexión: $e");
  }
}
}
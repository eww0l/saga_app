import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'base_datasource.dart';
import '../models/pedido_model.dart';

class PedidosDatasource extends BaseDatasource {

  // ==========================================================================
  // 1️⃣ OBTENER PEDIDOS POR COURIER (Híbrido - Flujo de Manifiesto Diario)
  // ==========================================================================
  Future<Map<String, dynamic>> fetchPedidosPorCourier(
    String courierId,
    String empresa, {
    double? latGps,
    double? lngGps,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bool tieneInternet = await verificarInternet();
    final String cacheKey = 'cache_pedidos_$courierId';

    // ❌ CASO OFFLINE: Carga los datos respaldados en SharedPreferences
    if (!tieneInternet) {
      final String? jsonLocal = prefs.getString(cacheKey);
      if (jsonLocal != null) {
        final Map<String, dynamic> dataDeDisco = json.decode(jsonLocal);
        final List pedidosJson = dataDeDisco['pedidos'] ?? [];

        return {
          "pedidos": pedidosJson.map((e) => PedidoModel.fromJson(e)).toList(),
          "ruta_osrm": dataDeDisco['ruta_osrm'] ?? [],
          "offline_mode": true
        };
      } else {
        throw Exception("Sin conexión y sin datos respaldados en este equipo.");
      }
    }

    // 🌐 CASO ONLINE: Consulta directa a FastAPI
    final url = Uri.parse(
      '$baseUrl/pedidos-courier?courier_id=$courierId&empresa=${Uri.encodeComponent(empresa)}'
      '${latGps != null && lngGps != null ? '&lat_gps=$latGps&lng_gps=$lngGps' : ''}',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data is Map && data.containsKey('error_detectado')) {
        throw Exception(data['error_detectado']);
      }

      await prefs.setString(cacheKey, response.body);

      final List pedidosJson = data['pedidos'] ?? [];

      return {
        "pedidos": pedidosJson.map((e) => PedidoModel.fromJson(e)).toList(),
        "ruta_osrm": data['ruta_osrm'] ?? [],
        "offline_mode": false
      };
    } else {
      throw Exception("Error servidor: ${response.statusCode}");
    }
  }

  // ==========================================================================
  // 2️⃣ ACTUALIZAR ESTADO DEL PEDIDO (🔒 CORREGIDO: Con firma de Courier)
  // ==========================================================================
  Future<bool> actualizarEstadoPedido({
    required int pedidoId,
    required String nuevoEstado,
    required String courierId, // 🔒 Parámetro obligatorio integrado
    String? motivoContingencia,
  }) async {
    final bool tieneInternet = await verificarInternet();

    // ❌ CASO OFFLINE: Encolado local y actualización en caliente de la caché
    if (!tieneInternet) {
      final prefs = await SharedPreferences.getInstance();
      List<String> colaPendientes = prefs.getStringList('cola_actualizaciones') ?? [];
      
      Map<String, dynamic> transaccionOffline = {
        'pedido_id': pedidoId,
        'nuevo_estado': nuevoEstado,
        'courier_id': courierId, // Guardamos el dueño del cambio en la cola
        'motivo_contingencia': motivoContingencia ?? '',
        'timestamp': DateTime.now().toIso8601String(),
      };

      colaPendientes.add(json.encode(transaccionOffline));
      await prefs.setStringList('cola_actualizaciones', colaPendientes);

      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith('cache_pedidos_')) {
          final String? jsonLocal = prefs.getString(key);
          if (jsonLocal != null) {
            Map<String, dynamic> data = json.decode(jsonLocal);
            List<dynamic> pedidos = data['pedidos'] ?? [];
            for (var p in pedidos) {
              if (p['id'] == pedidoId) {
                p['estado'] = nuevoEstado; 
              }
            }
            await prefs.setString(key, json.encode(data));
          }
        }
      }
      return true; 
    }

    // 🌐 CASO ONLINE: Mutación síncrona añadiendo validación courier_id
    try {
      String urlString = '$baseUrl/pedidos/$pedidoId/estado?nuevo_estado=$nuevoEstado&courier_id=$courierId';
      if (motivoContingencia != null && motivoContingencia.trim().isNotEmpty) {
        urlString += '&motivo_contingencia=${Uri.encodeComponent(motivoContingencia)}';
      }

      final url = Uri.parse(urlString);
      final response = await http.put(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['status'] == 'success';
      } else {
        final Map<String, dynamic> errorBody = json.decode(response.body);
        throw Exception(errorBody['detail'] ?? 'Error al actualizar estado');
      }
    } catch (e) {
      throw Exception('Error en el servidor: $e');
    }
  }

  // ==========================================================================
  // 3️⃣ BUSCADOR POR CÓDIGO DE BARRAS (🔒 CORREGIDO: Filtro B2B integrado)
  // ==========================================================================
  Future<Map<String, dynamic>> buscarPedidoPorCodigo(
    String codigoBarra, {
    required String courierId, // 🔒 Parámetro obligatorio integrado
    required String empresa,   // 🔒 Parámetro obligatorio integrado
  }) async {
    final bool tieneInternet = await verificarInternet();

    // ❌ CASO OFFLINE: Indexa sobre la caché guardada en disco
    if (!tieneInternet) {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (String key in keys) {
        if (key.startsWith('cache_pedidos_')) {
          final String? jsonLocal = prefs.getString(key);
          if (jsonLocal != null) {
            final Map<String, dynamic> data = json.decode(jsonLocal);
            final List<dynamic> pedidos = data['pedidos'] ?? [];

            for (var p in pedidos) {
              if (p['codigo_barra'] == codigoBarra) {
                return p; 
              }
            }
          }
        }
      }
      throw Exception("Modo Offline: El paquete $codigoBarra no figura en la carga local.");
    }

    // 🌐 CASO ONLINE: Consulta directa inyectando credenciales de sesión en Query
    try {
      final url = Uri.parse(
        '$baseUrl/pedidos/escanear/$codigoBarra?courier_id=$courierId&empresa=${Uri.encodeComponent(empresa)}'
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['pedido'] ?? {};
      } else if (response.statusCode == 403 || response.statusCode == 404) {
        final Map<String, dynamic> errorBody = json.decode(response.body);
        throw Exception(errorBody['detail'] ?? 'Error de validación del paquete.');
      } else {
        throw Exception('Error del servidor: Código ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ==========================================================================
  // 4️⃣ OBTENER RUTA COURIER (Consumo de Enrutamiento Geográfico OSRM)
  // ==========================================================================
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

  // ==========================================================================
  // 🔄 5️⃣ SINCRONIZADOR DE COLA OFFLINE (🔒 CORREGIDO: Lee courier_id de la cola)
  // ==========================================================================
  Future<void> sincronizarColaPendiente() async {
    final bool tieneInternet = await verificarInternet();
    if (!tieneInternet) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> colaPendientes = prefs.getStringList('cola_actualizaciones') ?? [];
    if (colaPendientes.isEmpty) return;

    List<String> transaccionesFallidas = [];

    for (String txString in colaPendientes) {
      try {
        final Map<String, dynamic> tx = json.decode(txString);
        // Extraemos el dueño de la transacción offline mapeado en la cola
        String urlString = '$baseUrl/pedidos/${tx['pedido_id']}/estado?nuevo_estado=${tx['nuevo_estado']}&courier_id=${tx['courier_id'] ?? ''}';
        
        if (tx['motivo_contingencia'] != null && tx['motivo_contingencia'].toString().trim().isNotEmpty) {
          urlString += '&motivo_contingencia=${Uri.encodeComponent(tx['motivo_contingencia'])}';
        }

        final url = Uri.parse(urlString);
        final response = await http.put(url);

        if (response.statusCode != 200) {
          transaccionesFallidas.add(txString); 
        }
      } catch (e) {
        transaccionesFallidas.add(txString);
      }
    }

    await prefs.setStringList('cola_actualizaciones', transaccionesFallidas);
  }
}
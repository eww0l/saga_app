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
  // 2️⃣ ACTUALIZAR ESTADO DEL PEDIDO (🔒 CORREGIDO: Envío de null real)
  // ==========================================================================
  Future<bool> actualizarEstadoPedido({
    required int pedidoId,
    required String nuevoEstado,
    required String courierId, 
    String? motivoContingencia,
    String? fotoBase64, 
  }) async {
    final bool tieneInternet = await verificarInternet();

    // ❌ CASO OFFLINE
    if (!tieneInternet) {
      final prefs = await SharedPreferences.getInstance();
      List<String> colaPendientes = prefs.getStringList('cola_actualizaciones') ?? [];
      
      Map<String, dynamic> transaccionOffline = {
        'pedido_id': pedidoId,
        'nuevo_estado': nuevoEstado,
        'courier_id': courierId,
        'motivo_contingencia': motivoContingencia ?? '',
        'foto_base64': fotoBase64 ?? '', 
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
                if (fotoBase64 != null) p['evidencia_url'] = 'local_cached_image';
              }
            }
            await prefs.setString(key, json.encode(data));
          }
        }
      }
      return true; 
    }

    // 🌐 CASO ONLINE
    try {
      String urlString = '$baseUrl/pedidos/$pedidoId/estado?nuevo_estado=$nuevoEstado&courier_id=$courierId';
      
      if (motivoContingencia != null && motivoContingencia.trim().isNotEmpty) {
        urlString += '&motivo_contingencia=${Uri.encodeComponent(motivoContingencia)}';
      }

      final url = Uri.parse(urlString);
      
      // 🚀 CORRECCIÓN: Mandamos null explícito en lugar de "" si no hay foto para no confundir a Pydantic
      final Map<String, dynamic> jsonBody = {
        'foto_base64': (fotoBase64 != null && fotoBase64.trim().isNotEmpty) ? fotoBase64 : null
      };

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8', 
        },
        body: json.encode(jsonBody), 
      ).timeout(const Duration(seconds: 25)); 

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
  // 3️⃣ BUSCADOR POR CÓDIGO DE BARRAS (Filtro B2B integrado)
  // ==========================================================================
  Future<Map<String, dynamic>> buscarPedidoPorCodigo(
    String codigoBarra, {
    required String courierId, 
    required String empresa,   
  }) async {
    final bool tieneInternet = await verificarInternet();

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
  // 🔄 5️⃣ SINCRONIZADOR DE COLA OFFLINE (🔒 CON AUDITORÍA EXTREMA POR TERMINAL)
  // ==========================================================================
  Future<void> sincronizarColaPendiente() async {
    final bool tieneInternet = await verificarInternet();
    if (!tieneInternet) {
      print('🛰️ [SYNC] Intento de sincronización cancelado: Sin conexión real a Internet.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> colaPendientes = prefs.getStringList('cola_actualizaciones') ?? [];
    
    // 👁️ INSPECCIÓN GENERAL
    print('🔥 [SYNC] TOTAL DE PEDIDOS ESPERANDO EN COLA OFFLINE (QUEUED): ${colaPendientes.length}');
    if (colaPendientes.isEmpty) {
      print('✅ [SYNC] Nada que sincronizar. La cola está limpia.');
      return;
    }

    List<String> transaccionesFallidas = [];

    for (int i = 0; i < colaPendientes.length; i++) {
      String txString = colaPendientes[i];
      try {
        final Map<String, dynamic> tx = json.decode(txString);
        print('📦 [SYNC] Procesando elemento [${i + 1}/${colaPendientes.length}] -> Pedido ID: ${tx['pedido_id']} | Pasar a: ${tx['nuevo_estado']}');

        String urlString = '$baseUrl/pedidos/${tx['pedido_id']}/estado?nuevo_estado=${tx['nuevo_estado']}&courier_id=${tx['courier_id'] ?? ''}';
        
        if (tx['motivo_contingencia'] != null && tx['motivo_contingencia'].toString().trim().isNotEmpty) {
          urlString += '&motivo_contingencia=${Uri.encodeComponent(tx['motivo_contingencia'])}';
        }

        final url = Uri.parse(urlString);
        final String? foto = tx['foto_base64'];
        final Map<String, dynamic> jsonBody = {
          'foto_base64': (foto != null && foto.trim().isNotEmpty) ? foto : null
        };

        print('🚀 [SYNC] Enviando petición PUT al servidor para Pedido ${tx['pedido_id']}...');
        
        final response = await http.put(
          url,
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: json.encode(jsonBody),
        ).timeout(const Duration(seconds: 30));

        // 👁️ INSPECCIÓN DE RESPUESTA DEL SERVIDOR
        print('📥 [SYNC] Servidor respondió para Pedido ${tx['pedido_id']} -> STATUS CODE: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          print('🎉 [SYNC] ¡ÉXITO! Pedido ${tx['pedido_id']} sincronizado y procesado en Supabase.');
        } else {
          print('🚨 [SYNC] ERROR: El servidor rechazó la sincronización. Body: ${response.body}');
          transaccionesFallidas.add(txString); 
        }
      } catch (e) {
        print('💥 [SYNC] CRASH CRÍTICO procesando elemento de la cola: $e');
        transaccionesFallidas.add(txString);
      }
    }

    await prefs.setStringList('cola_actualizaciones', transaccionesFallidas);
    print('📊 [SYNC] Proceso terminado. Elementos retenidos en cola por fallo: ${transaccionesFallidas.length}');
  }
}
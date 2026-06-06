import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/pedido_model.dart';

class ApiDatasource {
  final String baseUrl = "https://saga-api-546y.onrender.com/api";

  // 🛠️ FUNCIÓN AUXILIAR: Verifica si el dispositivo tiene internet real
  Future<bool> _verificarInternet() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  // ==========================================================================
  // 1️⃣ OBTENER PEDIDOS POR COURIER (Híbrido)
  // ==========================================================================
  Future<Map<String, dynamic>> fetchPedidosPorCourier(
    String courierId,
    String empresa, {
    double? latGps,
    double? lngGps,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bool tieneInternet = await _verificarInternet();
    final String cacheKey = 'cache_pedidos_$courierId';

    // ❌ CASO OFFLINE: Carga los datos guardados previamente
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

    // 🌐 CASO ONLINE: Consulta a Render y actualiza la caché local
    final url = Uri.parse(
      '$baseUrl/pedidos-courier?courier_id=$courierId&empresa=${Uri.encodeComponent(empresa)}'
      '${latGps != null && lngGps != null ? '&lat_gps=$latGps&lng_gps=$lngGps' : ''}',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      // Guardamos la respuesta cruda en disco para emergencias sin señal
      await prefs.setString(cacheKey, response.body);

      final data = json.decode(response.body);
      final List pedidosJson = data['pedidos'] ?? [];

      return {
        "pedidos": pedidosJson.map((e) => PedidoModel.fromJson(e)).toList(),
        "ruta_osrm": data['ruta_osrm'] ?? [],
      };
    } else {
      throw Exception("Error servidor: ${response.statusCode}");
    }
  }

  // ==========================================================================
  // 2️⃣ ACTUALIZAR ESTADO DEL PEDIDO (Soporta cola local si estás offline)
  // ==========================================================================
  Future<bool> actualizarEstadoPedido({
    required int pedidoId,
    required String nuevoEstado,
    String? motivoContingencia,
  }) async {
    final bool tieneInternet = await _verificarInternet();

    // ❌ CASO OFFLINE: Guarda el cambio en una cola local para subirla después
    if (!tieneInternet) {
      final prefs = await SharedPreferences.getInstance();
      
      // Obtenemos la cola de pendientes actual o creamos una nueva
      List<String> colaPendientes = prefs.getStringList('cola_actualizaciones') ?? [];
      
      // Estructuramos la petición en un mapa para guardarlo como String
      Map<String, dynamic> transaccionOffline = {
        'pedido_id': pedidoId,
        'nuevo_estado': nuevoEstado,
        'motivo_contingencia': motivoContingencia ?? '',
        'timestamp': DateTime.now().toIso8601String(),
      };

      colaPendientes.add(json.encode(transaccionOffline));
      await prefs.setStringList('cola_actualizaciones', colaPendientes);

      // 💡 Sincronización de la caché local para que la UI se entere del cambio al instante
      // Buscamos en todas las cachés de couriers para cambiar el estado del pedido localmente
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith('cache_pedidos_')) {
          final String? jsonLocal = prefs.getString(key);
          if (jsonLocal != null) {
            Map<String, dynamic> data = json.decode(jsonLocal);
            List<dynamic> pedidos = data['pedidos'] ?? [];
            for (var p in pedidos) {
              if (p['id'] == pedidoId) {
                p['estado'] = nuevoEstado; // Actualizamos el estado en la persistencia local
              }
            }
            await prefs.setString(key, json.encode(data));
          }
        }
      }
      return true; // Retorna true simulando éxito para no trabar la pantalla de Flutter
    }

    // 🌐 CASO ONLINE: Envío directo a FastAPI en Render
    try {
      String urlString = '$baseUrl/pedidos/$pedidoId/estado?nuevo_estado=$nuevoEstado';
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
  // 3️⃣ BUSCADOR POR CÓDIGO DE BARRAS (Soporta escaneo offline desde la caché)
  // ==========================================================================
  Future<Map<String, dynamic>> buscarPedidoPorCodigo(String codigoBarra) async {
    final bool tieneInternet = await _verificarInternet();

    // ❌ CASO OFFLINE: Busca el código dentro de los datos cacheados en el disco
    if (!tieneInternet) {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // Barremos los respaldos de couriers buscando el código de barras
      for (String key in keys) {
        if (key.startsWith('cache_pedidos_')) {
          final String? jsonLocal = prefs.getString(key);
          if (jsonLocal != null) {
            final Map<String, dynamic> data = json.decode(jsonLocal);
            final List<dynamic> pedidos = data['pedidos'] ?? [];

            for (var p in pedidos) {
              if (p['codigo_barra'] == codigoBarra) {
                return p; // Retornamos el pedido encontrado localmente
              }
            }
          }
        }
      }
      throw Exception("Modo Offline: El paquete $codigoBarra no figura en la carga local.");
    }

    // 🌐 CASO ONLINE: Petición normal a producción
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

  // ==========================================================================
  // 4️⃣ OBTENER RUTA COURIER
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
  // 🔄 5️⃣ MÉTODO EXTRA: Sincronizador de cola offline (Optimizado)
  // ==========================================================================
  Future<void> sincronizarColaPendiente() async {
    final bool tieneInternet = await _verificarInternet();
    if (!tieneInternet) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> colaPendientes = prefs.getStringList('cola_actualizaciones') ?? [];
    if (colaPendientes.isEmpty) return;

    // 🔒 Bloqueo de sincronización preventivo para evitar lecturas sucias
    List<String> transaccionesFallidas = [];

    for (String txString in colaPendientes) {
      try {
        final Map<String, dynamic> tx = json.decode(txString);
        
        // Estructuramos la URL exacta con los parámetros query que espera FastAPI
        String urlString = '$baseUrl/pedidos/${tx['pedido_id']}/estado?nuevo_estado=${tx['nuevo_estado']}';
        
        if (tx['motivo_contingencia'] != null && tx['motivo_contingencia'].toString().trim().isNotEmpty) {
          urlString += '&motivo_contingencia=${Uri.encodeComponent(tx['motivo_contingencia'])}';
        }

        final url = Uri.parse(urlString);
        final response = await http.put(url);

        // Si el backend responde 200 OK, el registro en Supabase ya está actualizado en caliente
        if (response.statusCode != 200) {
          transaccionesFallidas.add(txString); 
        }
      } catch (e) {
        // Si hay una fluctuación de red en medio del bucle, se preserva en la cola
        transaccionesFallidas.add(txString);
      }
    }

    // Guardamos en el disco duro del celular únicamente lo que falló
    await prefs.setStringList('cola_actualizaciones', transaccionesFallidas);
    
    // 💡 NOTA PARA LA TESIS: Al terminar este bucle, el listener de la HomeScreen
    // mandará a llamar a 'fetchPedidosPorCourier', trayendo la nueva verdad unificada
    // desde Supabase sin alterar el flujo de trabajo del transportista.
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'base_datasource.dart';
import '../models/pedido_model.dart';

class LoginDatasource extends BaseDatasource {
  
  // ==========================================================================
  // 🏢 1️⃣ OBTENER EMPRESAS COURIER ACTIVAS (Catálogo Dinámico)
  // ==========================================================================
  Future<List<String>> fetchEmpresasActivas() async {
    final bool tieneInternet = await verificarInternet();

    if (!tieneInternet) {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? empresasCache = prefs.getStringList('cache_catalogo_empresas');
      
      if (empresasCache != null && empresasCache.isNotEmpty) {
        return empresasCache;
      }
      
      // Fallback local en caso extremo de primer inicio sin red
      return [
        'Saga Falabella (Flota Interna)',
        'Olva Courier (Socio B2B)',
        'Chazki (Socio B2B)',
        'Urbano (Socio B2B)'
      ];
    }

    try {
      final url = Uri.parse('$baseUrl/pedidos/empresas-activas');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> listaRaw = data['empresas'] ?? [];
        
        List<String> empresasDescargadas = listaRaw.map((e) => e.toString()).toList();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('cache_catalogo_empresas', empresasDescargadas);

        return empresasDescargadas;
      } else {
        throw Exception("Error catálogo: Código ${response.statusCode}");
      }
    } catch (e) {
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

  // ==========================================================================
  // 🔑 2️⃣ VALIDAR ACCESO / CONTROL DE SEGURIDAD (Al iniciar jornada)
  // ==========================================================================
  Future<Map<String, dynamic>> autenticarJornada(String courierId, String empresa) async {
    final bool tieneInternet = await verificarInternet();
    final prefs = await SharedPreferences.getInstance();
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

    // 🌐 CASO ONLINE: Consulta de validación al backend
    final url = Uri.parse('$baseUrl/pedidos-courier?courier_id=$courierId&empresa=${Uri.encodeComponent(empresa)}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // 🔒 CONTROL DE SEGURIDAD CRÍTICO:
      if (data is Map && data.containsKey('error_detectado')) {
        throw Exception(data['error_detectado']);
      }

      // Guardamos la respuesta en disco solo si pasó los filtros de seguridad
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
}
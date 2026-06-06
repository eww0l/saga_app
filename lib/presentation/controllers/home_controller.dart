import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../data/datasources/pedidos_datasource.dart';
import '../../../data/models/pedido_model.dart';

class HomeController extends ChangeNotifier {
  final PedidosDatasource _datasource = PedidosDatasource();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  // 🔒 Bandera de control para evitar ejecuciones post-dispose
  bool _isDisposed = false;

  // Estados privados
  List<PedidoModel> _pedidos = [];
  bool _cargando = true;
  String? _error;

  // Constantes del Almacén (Origen)
  final double _latAlmacen = -12.046374;
  final double _lngAlmacen = -77.042793;

  // Getters Públicos
  List<PedidoModel> get pedidos => _pedidos;
  bool get cargando => _cargando;
  String? get error => _error;

  // 🛰️ Inicializador de flujos de red y carga híbrida
  void inicializar(String courierId, String empresa) {
    _cargarDatosHibridos(courierId, empresa);

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) async {
      // 🔒 Validamos de inmediato si el controlador ya fue destruido
      if (_isDisposed) return;

      final bool tieneInternet = !results.contains(ConnectivityResult.none);
      if (tieneInternet) {
        try {
          await _datasource.sincronizarColaPendiente();
        } catch (_) {
          // Evitamos que un fallo en la sincronización rompa el stream
        }
      }

      // Volvemos a validar antes de procesar la carga asíncrona
      if (!_isDisposed) {
        _cargarDatosHibridos(courierId, empresa);
      }
    });
  }

  // 📡 Carga asíncrona híbrida de datos
  Future<void> actualizarDatos(String courierId, String empresa) async {
    if (_isDisposed) return;
    await _cargarDatosHibridos(courierId, empresa);
  }

  Future<void> _cargarDatosHibridos(String courierId, String empresa) async {
    try {
      final data = await _datasource.fetchPedidosPorCourier(courierId, empresa);
      
      // 🔒 Verificación intermedia por si la respuesta de la API tardó y el usuario ya salió de la pantalla
      if (_isDisposed) return;

      final List<PedidoModel> listaOriginal = data['pedidos'] as List<PedidoModel>;

      // Segmentación por estado de entrega
      final pedidosEnRutaSucios = listaOriginal.where((p) => p.estado == 'En Ruta').toList();
      final otrosPedidos = listaOriginal.where((p) => p.estado != 'En Ruta').toList();

      // Procesamiento matemático local de ruta óptima
      final pedidosEnRutaOrdenados = _ordenarRutaOptimizada(pedidosEnRutaSucios);

      _pedidos = [...pedidosEnRutaOrdenados, ...otrosPedidos];
      _error = null;
      _cargando = false;
    } catch (e) {
      if (_isDisposed) return;
      _error = e.toString().replaceAll('Exception: ', '');
      _cargando = false;
    }

    // 🔒 Solo notificamos si el árbol de elementos visuales mantiene este controlador activo
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // 📐 ALGORITMO: Distancia en Km usando Haversine
  double _calcularDistanciaHaversine(double lat1, double lon1, double lat2, double lon2) {
    double dLat = (lat2 - lat1) * math.pi / 180.0;
    double dLon = (lon2 - lon1) * math.pi / 180.0;

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
            
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return 6371 * c;
  }

  // 🧠 ALGORITMO JERÁRQUICO DE ENRUTAMIENTO (Greedy Approach)
  List<PedidoModel> _ordenarRutaOptimizada(List<PedidoModel> pedidosEnRuta) {
    List<PedidoModel> bloqueAlta = pedidosEnRuta.where((p) => p.prioridad == 'Alta').toList();
    List<PedidoModel> bloqueBaja = pedidosEnRuta.where((p) => p.prioridad != 'Alta').toList();

    List<PedidoModel> rutaOrdenada = [];
    double puntoActualLat = _latAlmacen;
    double puntoActualLng = _lngAlmacen;

    while (bloqueAlta.isNotEmpty) {
      PedidoModel masCercano = bloqueAlta.reduce((a, b) {
        double distA = _calcularDistanciaHaversine(puntoActualLat, puntoActualLng, a.latitud, a.longitud);
        double distB = _calcularDistanciaHaversine(puntoActualLat, puntoActualLng, b.latitud, b.longitud);
        return distA < distB ? a : b;
      });
      
      rutaOrdenada.add(masCercano);
      puntoActualLat = masCercano.latitud;
      puntoActualLng = masCercano.longitud;
      bloqueAlta.remove(masCercano);
    }

    while (bloqueBaja.isNotEmpty) {
      PedidoModel masCercano = bloqueBaja.reduce((a, b) {
        double distA = _calcularDistanciaHaversine(puntoActualLat, puntoActualLng, a.latitud, a.longitud);
        double distB = _calcularDistanciaHaversine(puntoActualLat, puntoActualLng, b.latitud, b.longitud);
        return distA < distB ? a : b;
      });
      
      rutaOrdenada.add(masCercano);
      puntoActualLat = masCercano.latitud;
      puntoActualLng = masCercano.longitud;
      bloqueBaja.remove(masCercano);
    }

    return rutaOrdenada;
  }

  void liberarRecursos() {
    _connectivitySubscription.cancel();
  }

  // 🔒 Interceptamos el método de destrucción nativo
  @override
  void dispose() {
    _isDisposed = true; // Bloquea cualquier intento de ejecución asíncrona residual
    _connectivitySubscription.cancel(); // Rompe la escucha de red inmediatamente
    super.dispose();
  }
}
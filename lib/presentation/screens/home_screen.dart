import 'dart:async';
import 'dart:math' as math; // 📐 Importación matemática para el cálculo GPS
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../data/datasources/api_datasource.dart';
import '../../../data/models/pedido_model.dart';
import '../widgets/pedido_card.dart';

class HomeScreen extends StatefulWidget {
  final String courierId;
  final String empresa;

  const HomeScreen({super.key, required this.courierId, required this.empresa});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiDatasource _datasource = ApiDatasource();
  List<PedidoModel> _pedidos = [];
  bool _cargando = true;
  String? _error;
  
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  // 📍 COORDENADA DE ORIGEN (Punto de partida del transportista para ordenar las distancias)
  final double _latAlmacen = -12.046374;
  final double _lngAlmacen = -77.042793;

  @override
  void initState() {
    super.initState();
    _cargarDatosHibridos();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) async {
      final bool tieneInternet = !results.contains(ConnectivityResult.none);
      if (tieneInternet) {
        await _datasource.sincronizarColaPendiente();
      }
      _cargarDatosHibridos();
    });
  }

  // 📐 ALGORITMO: Calcula la distancia exacta en kilómetros usando Haversine
  double _calcularDistanciaHaversine(double lat1, double lon1, double lat2, double lon2) {
    double dLat = (lat2 - lat1) * math.pi / 180.0;
    double dLon = (lon2 - lon1) * math.pi / 180.0;

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
            
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return 6371 * c; // Radio de la Tierra en Km
  }

  // 🧠 ALGORITMO JERÁRQUICO DE ENRUTAMIENTO (Réplica exacta de tu Backend en Dart)
  List<PedidoModel> _ordenarRutaOptimizada(List<PedidoModel> pedidosEnRuta) {
    // 1. Separamos estrictamente por los bloques de prioridad de tu negocio
    List<PedidoModel> bloqueAlta = pedidosEnRuta.where((p) => p.prioridad == 'Alta').toList();
    List<PedidoModel> bloqueBaja = pedidosEnRuta.where((p) => p.prioridad != 'Alta').toList();

    List<PedidoModel> rutaOrdenada = [];
    double puntoActualLat = _latAlmacen;
    double puntoActualLng = _lngAlmacen;

    // 🔴 Ordenar bloque de Alta Prioridad por el vecino más cercano (Greedy Approach)
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

    // 🟢 Ordenar bloque de Baja Prioridad partiendo desde donde terminó la última entrega "Alta"
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

  Future<void> _cargarDatosHibridos() async {
    try {
      final data = await _datasource.fetchPedidosPorCourier(
        widget.courierId,
        widget.empresa,
      );

      if (mounted) {
        final List<PedidoModel> listaOriginal = data['pedidos'] as List<PedidoModel>;

        // 📊 Segmentación por Estado
        final pedidosEnRutaSucios = listaOriginal.where((p) => p.estado == 'En Ruta').toList();
        final otrosPedidos = listaOriginal.where((p) => p.estado != 'En Ruta').toList();

        // ⚡ PROCESAMIENTO MATEMÁTICO: Ordenamos la ruta activa usando el algoritmo jerárquico
        final pedidosEnRutaOrdenados = _ordenarRutaOptimizada(pedidosEnRutaSucios);

        setState(() {
          // Unimos las listas: Primero los de "En Ruta" ordenados por parada óptima, abajo el resto
          _pedidos = [...pedidosEnRutaOrdenados, ...otrosPedidos];
          _cargando = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _cargando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    
    if (_error != null) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    }

    // 🔄 Pull to Refresh adaptado para cuando la lista de pedidos se queda vacía
    if (_pedidos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargarDatosHibridos,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(), // Obliga el rebote táctil
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No se encontraron pedidos activos.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Desliza hacia abajo para actualizar', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 🔄 Pull to Refresh adaptado para la lista general de paquetes
    return Scaffold(
      body: RefreshIndicator(
        color: Colors.green, // Indicador visual con el color corporativo
        onRefresh: _cargarDatosHibridos, // Callback que se ejecuta al deslizar abajo
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(), // Evita que Android bloquee el scroll con pocos ítems
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: _pedidos.length,
          itemBuilder: (context, index) {
            return PedidoCard(pedido: _pedidos[index]);
          },
        ),
      ),
    );
  }
}
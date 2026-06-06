import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // 🗺️ OpenStreetMap Libre
import 'package:latlong2/latlong.dart'; // Coordenadas nativas del mapa
import 'package:geolocator/geolocator.dart';

import '../../core/theme.dart';
import '../../../data/datasources/api_datasource.dart';
import '../../../data/models/pedido_model.dart';

class MapScreen extends StatefulWidget {
  final String courierId;
  final String empresa;

  const MapScreen({
    super.key,
    required this.courierId,
    required this.empresa,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ApiDatasource _apiDatasource = ApiDatasource();
  final MapController _mapController = MapController();

  LatLng _miUbicacion = const LatLng(-12.046374, -77.042793);

  bool _actualizando = false;
  bool _cargando = true;

  List<Marker> _marcadores = [];
  List<Polyline> _polilineasRuta = [];
  Stream<Position>? _gpsStream;

  @override
  void initState() {
    super.initState();
    _inicializarGpsYViaje();
    _iniciarTrackingEnTiempoReal();
  }

  // 🛰️ GPS manual inicial
  Future<void> _inicializarGpsYViaje() async {
    LocationPermission permiso = await Geolocator.checkPermission();

    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() => _cargando = false);
      }
      return;
    }

    try {
      final posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _miUbicacion =
          LatLng(posicion.latitude, posicion.longitude);
          _mapController.move(_miUbicacion, _mapController.camera.zoom);

      _descargarEInterpretarRuta();
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  // 📡 Tracking en tiempo real
  void _iniciarTrackingEnTiempoReal() async {
    LocationPermission permiso = await Geolocator.requestPermission();

    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      setState(() => _cargando = false);
      return;
    }

    _gpsStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );

    _gpsStream!.listen((Position posicion) {
      _miUbicacion =
          LatLng(posicion.latitude, posicion.longitude);
          _mapController.move(_miUbicacion, _mapController.camera.zoom);

      _descargarEInterpretarRuta();
    });
  }

  // 🧠 Ruta + marcadores
  Future<void> _descargarEInterpretarRuta() async {
    if (_actualizando) return;
    _actualizando = true;

    try {
      final data = await _apiDatasource.fetchPedidosPorCourier(
        widget.courierId,
        widget.empresa,
        latGps: _miUbicacion.latitude,
        lngGps: _miUbicacion.longitude,
      );

      final List<PedidoModel> pedidos =
    (data['pedidos'] as List<PedidoModel>)
        .where((p) =>
            p.estado != 'Entregado' &&
            p.estado != 'No entregado')
        .toList();

      final List<dynamic> rutaRaw =
          data['ruta_osrm'] as List<dynamic>;

      List<LatLng> puntosDeLaLinea;

      if (rutaRaw.isNotEmpty) {
        puntosDeLaLinea = rutaRaw.map<LatLng>((p) {
          return LatLng(
            (p[1] as num).toDouble(),
            (p[0] as num).toDouble(),
          );
        }).toList();
      } else {
        puntosDeLaLinea = [
          _miUbicacion,
          ...pedidos.map(
            (p) => LatLng(p.latitud, p.longitud),
          )
        ];
      }

      final List<Marker> nuevosMarcadores = [];

      // 🚚 courier
      nuevosMarcadores.add(
        Marker(
          point: _miUbicacion,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.navigation,
            color: Colors.blue,
            size: 32,
          ),
        ),
      );

      // 📦 pedidos
      for (final pedido in pedidos) {
        nuevosMarcadores.add(
          Marker(
            point: LatLng(pedido.latitud, pedido.longitud),
            width: 45,
            height: 45,
            child: Icon(
              Icons.location_on,
              color: pedido.prioridad == 'Alta'
                  ? Colors.red
                  : Colors.green,
              size: 42,
            ),
          ),
        );
      }

      setState(() {
        _marcadores = nuevosMarcadores;
        _polilineasRuta = [
          Polyline(
            points: puntosDeLaLinea,
            strokeWidth: 5,
            color: SagaTheme.primaryGreen,
            borderColor: Colors.white,
            borderStrokeWidth: 1,
          )
        ];
        _cargando = false;
      });

      _actualizando = false;
    } catch (e) {
      setState(() => _cargando = false);
      debugPrint("ERROR MAPA: $e");
    }
  }

  void _mostrarMiniDetalle(PedidoModel pedido) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '📦 [${pedido.prioridad}] ${pedido.descripcionProducto}\n📍 ${pedido.direccionCliente}',
        ),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap( mapController:_mapController,
              options: MapOptions(
                initialCenter: _miUbicacion,
                initialZoom: 13.5,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.saga.app',
                ),

                PolylineLayer(polylines: _polilineasRuta),
                MarkerLayer(markers: _marcadores),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: SagaTheme.primaryGreen,
        foregroundColor: Colors.white,
        onPressed: _inicializarGpsYViaje,
        child: const Icon(Icons.gps_fixed),
      ),
    );
  }
}
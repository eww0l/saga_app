import 'dart:async'; // 💡 OBLIGATORIO: Para poder usar el StreamSubscription
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart'; 
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
  bool _mapaListo = false; // 💡 SOLUCIÓN: Bandera para saber si el mapa ya se renderizó

  List<Marker> _marcadores = [];
  List<Polyline> _polilineasRuta = [];
  
  Stream<Position>? _gpsStream;
  StreamSubscription<Position>? _gpsSubscription; 

  @override
  void initState() {
    super.initState();
    _inicializarGpsYViaje();
    _iniciarTrackingEnTiempoReal();
  }

  @override
  void dispose() {
    // 🔒 Cancelamos de inmediato la escucha nativa para liberar el hardware
    if (_gpsSubscription != null) {
      _gpsSubscription!.cancel();
    }
    _mapController.dispose();
    super.dispose();
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

      if (!mounted) return;
      setState(() {
        _miUbicacion = LatLng(posicion.latitude, posicion.longitude);
      });

      // 🔒 Mover el mapa solo si ya está completamente montado en el árbol
      if (_mapaListo) {
        _mapController.move(_miUbicacion, _mapController.camera.zoom);
      }

      _descargarEInterpretarRuta();
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  // 📡 Tracking en tiempo real continuado
  void _iniciarTrackingEnTiempoReal() async {
    LocationPermission permiso = await Geolocator.checkPermission();

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

    _gpsSubscription = _gpsStream!.listen((Position posicion) {
      if (!mounted) return; 

      setState(() {
        _miUbicacion = LatLng(posicion.latitude, posicion.longitude);
      });

      // 🔒 Evitamos crasheos por llamadas rápidas del GPS
      if (_mapaListo) {
        _mapController.move(_miUbicacion, _mapController.camera.zoom);
      }

      _descargarEInterpretarRuta();
    });
  }

  // 🧠 Ruta + marcadores secuenciales
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

      final List<PedidoModel> pedidos = (data['pedidos'] as List<PedidoModel>)
          .where((p) =>
              p.estado != 'Entregado' &&
              p.estado != 'No entregado' &&
              p.estado != 'Asignado')
          .toList();

      final List<dynamic> rutaRaw = data['ruta_osrm'] as List<dynamic>;
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
          ...pedidos.map((p) => LatLng(p.latitud, p.longitud))
        ];
      }

      final List<Marker> nuevosMarcadores = [];

      // 🚚 Courier
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

      // 📦 Pedidos
      for (final pedido in pedidos) {
        nuevosMarcadores.add(
          Marker(
            point: LatLng(pedido.latitud, pedido.longitud),
            width: 45,
            height: 45,
            child: Icon(
              Icons.location_on,
              color: pedido.prioridad == 'Alta' ? Colors.red : Colors.green,
              size: 42,
            ),
          ),
        );
      }

      if (!mounted) return;
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
        _actualizando = false; 
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _actualizando = false; 
        });
      }
      debugPrint("ERROR MAPA: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap( 
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _miUbicacion,
                initialZoom: 13.5,
                // 💡 SOLUCIÓN CLAVE: Se activa solo cuando Flutter avisa que el mapa está listo
                onMapReady: () {
                  _mapaListo = true;
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
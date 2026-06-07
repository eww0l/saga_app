import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/datasources/pedidos_datasource.dart';
import '../../../data/models/pedido_model.dart';
import '../../core/theme.dart';

class MapScreenController extends ChangeNotifier {
  final PedidosDatasource _datasource = PedidosDatasource();
  final MapController flutterMapController = MapController();

  LatLng miUbicacion = const LatLng(-12.046374, -77.042793);
  
  bool actualizando = false;
  bool cargando = true;
  bool mapaListo = false;

  List<Marker> marcadores = [];
  List<Polyline> polilineasRuta = [];

  Stream<Position>? _gpsStream;
  StreamSubscription<Position>? _gpsSubscription;

  // 🛰️ GPS manual inicial e interpretación de datos
  Future<void> inicializarGpsYViaje(String courierId, String empresa) async {
    LocationPermission permiso = await Geolocator.checkPermission();

    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
      cargando = false;
      notifyListeners();
      return;
    }

    try {
      final posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      miUbicacion = LatLng(posicion.latitude, posicion.longitude);

      if (mapaListo) {
        flutterMapController.move(miUbicacion, flutterMapController.camera.zoom);
      }

      await descargarEInterpretarRuta(courierId, empresa);
    } catch (e) {
      cargando = false;
      notifyListeners();
    }
  }

  // 📡 Tracking en tiempo real continuado
  void iniciarTrackingEnTiempoReal(String courierId, String empresa) async {
    LocationPermission permiso = await Geolocator.checkPermission();

    if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
      cargando = false;
      notifyListeners();
      return;
    }

    _gpsStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );

    _gpsSubscription = _gpsStream!.listen((Position posicion) async {
      miUbicacion = LatLng(posicion.latitude, posicion.longitude);

      if (mapaListo) {
        flutterMapController.move(miUbicacion, flutterMapController.camera.zoom);
      }

      await descargarEInterpretarRuta(courierId, empresa);
    });
  }

  // 🧠 Ruta + marcadores secuenciales (FastAPI/OSRM)
  Future<void> descargarEInterpretarRuta(String courierId, String empresa) async {
    if (actualizando) return;
    actualizando = true;

    try {
      final data = await _datasource.fetchPedidosPorCourier(
        courierId,
        empresa,
        latGps: miUbicacion.latitude,
        lngGps: miUbicacion.longitude,
      );

      final List<PedidoModel> pedidos = (data['pedidos'] as List<PedidoModel>)
          .where((p) => p.estado != 'Entregado' && p.estado != 'No Entregado' && p.estado != 'Asignado')
          .toList();

      final List<dynamic> rutaRaw = data['ruta_osrm'] as List<dynamic>;
      List<LatLng> puntosDeLaLinea;

      if (rutaRaw.isNotEmpty) {
        puntosDeLaLinea = rutaRaw.map<LatLng>((p) {
          return LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble());
        }).toList();
      } else {
        puntosDeLaLinea = [
          miUbicacion,
          ...pedidos.map((p) => LatLng(p.latitud, p.longitud))
        ];
      }

      final List<Marker> nuevosMarcadores = [];

      // 🚚 Courier
      nuevosMarcadores.add(
        Marker(
          point: miUbicacion,
          width: 40,
          height: 40,
          child: const Icon(Icons.navigation, color: Colors.blue, size: 32),
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

      marcadores = nuevosMarcadores;
      polilineasRuta = [
        Polyline(
          points: puntosDeLaLinea,
          strokeWidth: 5,
          color: SagaTheme.primaryGreen,
          borderColor: Colors.white,
          borderStrokeWidth: 1,
        )
      ];
      cargando = false;
      actualizando = false;
    } catch (e) {
      cargando = false;
      actualizando = false;
      debugPrint("ERROR MAPA: $e");
    }
    notifyListeners();
  }

  void cerrarSuscripciones() {
    if (_gpsSubscription != null) {
      _gpsSubscription!.cancel();
    }
    flutterMapController.dispose();
  }
}
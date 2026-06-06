import 'dart:async';
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

  @override
  void initState() {
    super.initState();
    _cargarDatosHibridos();

    // 📡 ESCUCHA EN TIEMPO REAL: Al recuperar internet, procesa la cola y refresca
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) async {
      final bool tieneInternet = !results.contains(ConnectivityResult.none);
      
      if (tieneInternet) {
        // 🚀 1. Sube los pedidos que el chofer entregó estando offline
        await _datasource.sincronizarColaPendiente();
      }
      
      // 🔄 2. Refresca la pantalla con los datos actualizados
      _cargarDatosHibridos();
    });
  }

  Future<void> _cargarDatosHibridos() async {
    try {
      final data = await _datasource.fetchPedidosPorCourier(
        widget.courierId,
        widget.empresa,
      );

      if (mounted) {
        setState(() {
          _pedidos = data['pedidos'] as List<PedidoModel>;
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
    _connectivitySubscription.cancel(); // Evita fugas de memoria
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    
    if (_error != null) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    }

    if (_pedidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No se encontraron pedidos activos.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return Scaffold(
      // 💡 QUITAMOS AbsorbPointer: Ahora el chofer SÍ puede interactuar estando offline
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: _pedidos.length,
        itemBuilder: (context, index) {
          return PedidoCard(pedido: _pedidos[index]);
        },
      ),
    );
  }
}
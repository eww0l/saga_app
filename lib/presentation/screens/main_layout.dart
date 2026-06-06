import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/theme.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'scanner_screen.dart';
import 'login_screen.dart';

class MainLayout extends StatefulWidget {
  final String courierId;
  final String empresa;

  const MainLayout({super.key, required this.courierId, required this.empresa});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  bool _esOffline = false; // Controla la visibilidad del banner naranja
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _verificarRedInicial();

    // 📡 ESCUCHA EN TIEMPO REAL: Detecta instantáneamente si el chofer pierde señal
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (mounted) {
        setState(() {
          _esOffline = results.contains(ConnectivityResult.none);
        });
      }
    });
  }

  void _verificarRedInicial() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _esOffline = connectivityResult.contains(ConnectivityResult.none);
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel(); // 🔒 Evita fugas de memoria al cerrar la jornada
    super.dispose();
  }
  
  // Lista de las pantallas principales del sistema pasándoles las credenciales
  List<Widget> _getScreens() {
    return [
      HomeScreen(courierId: widget.courierId, empresa: widget.empresa), 
      MapScreen(courierId: widget.courierId, empresa: widget.empresa),                     
      const ScannerScreen(),                 
    ];
  }

  void _cerrarSesion() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Finalizar Jornada'),
          content: const Text('¿Está seguro que desea cerrar sesión y salir del sistema?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('CERRAR SESIÓN', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = _getScreens();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'FALABELLA LOGÍSTICA', 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${widget.empresa} • ID: ${widget.courierId}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: Column(
        children: [
          // ⚠️ BANNER REACTIVO: Se inyecta en caliente si el transportista se queda sin cobertura
          if (_esOffline)
            Container(
              color: Colors.orange.shade700,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Text(
                '⚠️ MODO SIN CONEXIÓN - LECTURA DE RESPALDO LOCAL',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 11, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 0.5
                ),
              ),
            ),
          
          // El módulo activo (Home, Mapa o Escáner) ocupa el resto de la pantalla de forma limpia
          Expanded(
            child: screens[_currentIndex],
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: SagaTheme.primaryGreen,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Hoja de Ruta',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Mapa Óptimo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Escanear',
          ),
        ],
      ),
    );
  }
}
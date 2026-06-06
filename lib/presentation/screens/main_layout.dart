import 'package:flutter/material.dart';
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
  
  // 💡 SOLUCIÓN MAESTRA: En lugar de inicializar la lista en el initState, 
  // la generamos dinámicamente en el build. Así evitamos cualquier conflicto 
  // de sincronización de parámetros con la HomeScreen al compilar.
  List<Widget> _getScreens() {
    return [
      HomeScreen(courierId: widget.courierId, empresa: widget.empresa), 
      MapScreen(
  courierId: widget.courierId,
  empresa: widget.empresa,
),                     
      ScannerScreen(),                 
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
            Text(
              'FALABELLA LOGÍSTICA', 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${widget.empresa} • ID: ${widget.courierId}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_outlined, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: SagaTheme.primaryGreen,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: [
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
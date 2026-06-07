import 'package:flutter/material.dart';
import '../controllers/home_controller.dart';
import '../widgets/home/home_loading_error.dart';
import '../widgets/home/home_empty_state.dart';
import '../widgets/pedido_card.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Asegúrate de tener el import arriba

class HomeScreen extends StatefulWidget {
  final String courierId;
  final String empresa;

  const HomeScreen({super.key, required this.courierId, required this.empresa});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeController _controller = HomeController();

  @override
  void initState() {
    super.initState();
    _controller.inicializar(widget.courierId, widget.empresa);

    // ✅ YA NO HAY BORRADO DE EMERGENCIA AQUÍ. LA COLA SOBREVIVE.

    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.liberarRecursos(); // Cancela la suscripción a internet de forma segura
    _controller.dispose();
    super.dispose();
  }
  

  @override
  Widget build(BuildContext context) {
    // 1️⃣ Estado de Carga o Alerta de Error Crítico
    if (_controller.cargando || _controller.error != null) {
      return HomeLoadingError(
        cargando: _controller.cargando,
        error: _controller.error,
      );
    }

    // 2️⃣ Estado Vacío (Sin manifiesto o entregas culminadas)
    if (_controller.pedidos.isEmpty) {
      return HomeEmptyState(
        onRefresh: () => _controller.actualizarDatos(widget.courierId, widget.empresa),
      );
    }

    // 3️⃣ Estado Activo: Renderizado de la Hoja de Ruta Optimizada
    return Scaffold(
      body: RefreshIndicator(
        color: Colors.green,
        onRefresh: () => _controller.actualizarDatos(widget.courierId, widget.empresa),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: _controller.pedidos.length,
          itemBuilder: (context, index) {
            // 🚀 SOLUCIÓN DEFINITIVA: Inyectamos los 3 parámetros requeridos por el constructor
            return PedidoCard(
              pedido: _controller.pedidos[index],
              courierId: widget.courierId, 
              onEstadoActualizado: () {
                // Cada vez que la tarjeta mute (Online u Offline), fuerza al HomeController a refrescar el listado
                _controller.actualizarDatos(widget.courierId, widget.empresa);
              },
            );
          },
        ),
      ),
    );
  } }
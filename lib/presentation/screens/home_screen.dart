import 'package:flutter/material.dart';
import '../controllers/home_controller.dart';
import '../widgets/home/home_loading_error.dart';
import '../widgets/home/home_empty_state.dart';
import '../widgets/pedido_card.dart';

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
    // Encendemos el motor lógico del controlador pasándole las credenciales
    _controller.inicializar(widget.courierId, widget.empresa);

    // Escuchamos los cambios del controlador para redibujar la UI al instante
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
            return PedidoCard(pedido: _controller.pedidos[index]);
          },
        ),
      ),
    );
  }
}
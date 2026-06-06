import 'package:flutter/material.dart';
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
  late Future<List<PedidoModel>> _futurePedidos;

@override
void initState() {
  super.initState();
  _futurePedidos = _cargarPedidos();
}

Future<List<PedidoModel>> _cargarPedidos() async {
  final data = await _datasource.fetchPedidosPorCourier(
    widget.courierId,
    widget.empresa,
  );

  return data['pedidos'] as List<PedidoModel>;
}

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PedidoModel>>(
      future: _futurePedidos,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error al cargar la ruta: ${snapshot.error}'.replaceAll('Exception: ', ''),
              style: const TextStyle(color: Colors.red),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No se encontraron pedidos activos.',
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        final pedidos = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: pedidos.length,
          itemBuilder: (context, index) {
            return PedidoCard(pedido: pedidos[index]);
          },
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import '../../controllers/scanner_controller.dart';

class ScannerManifestSheet extends StatelessWidget {
  final ScannerController controller;

  const ScannerManifestSheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'DETALLE DE CARGA (${controller.listaCargaTemporal.length} PAQUETES)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              controller.listaCargaTemporal.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: Center(child: Text('No hay paquetes en el manifiesto actual.', style: TextStyle(color: Colors.grey))),
                    )
                  : Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: controller.listaCargaTemporal.length,
                        itemBuilder: (context, index) {
                          final item = controller.listaCargaTemporal[index];
                          return Card(
                            elevation: 0,
                            color: Colors.grey[100],
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                              title: Text(item.descripcionProducto, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(item.codigoBarra, style: const TextStyle(color: Colors.blue)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () {
                                  controller.removerItemDeCarga(index);
                                  if (controller.listaCargaTemporal.isEmpty) {
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}
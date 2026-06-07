class PedidoModel {
  final int id;
  final String codigoBarra;
  final String descripcionProducto;
  final String estado;
  final String prioridad;
  final int intentosEntrega;
  final String nombreCliente;
  final String direccionCliente;
  final double latitud;
  final double longitud;

  PedidoModel({
    required this.id,
    required this.codigoBarra,
    required this.descripcionProducto,
    required this.estado,
    required this.prioridad,
    required this.intentosEntrega,
    required this.nombreCliente,
    required this.direccionCliente,
    required this.latitud,
    required this.longitud,
  });

  // 📡 Constructor Factory: Convierte el JSON relacional de FastAPI a objeto Dart
  factory PedidoModel.fromJson(Map<String, dynamic> json) {
    final cliente = json['clientes'] ?? {};

    return PedidoModel(
      id: _parseToInt(json['id']),
      codigoBarra: json['codigo_barra']?.toString() ?? '',
      descripcionProducto: json['descripcion_producto']?.toString() ?? '',
      estado: json['estado']?.toString() ?? 'Asignado',
      prioridad: json['prioridad']?.toString() ?? 'Baja',
      intentosEntrega: _parseToInt(json['intentos_entrega']),
      nombreCliente: cliente['nombre']?.toString() ?? 'No especificado',
      direccionCliente: '${cliente['direccion'] ?? ''}, ${cliente['distrito'] ?? ''}'.trim(),
      latitud: _parseToDouble(cliente['latitud']),
      longitud: _parseToDouble(cliente['longitud']),
    );
  }

  // 💾 NUEVO MÉTODO TOJSON: Crucial para persistir cambios en SharedPreferences (Modo Offline)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo_barra': codigoBarra,
      'descripcion_producto': descripcionProducto,
      'estado': estado,
      'prioridad': prioridad,
      'intentos_entrega': intentosEntrega,
      'clientes': {
        'nombre': nombreCliente,
        'direccion': direccionCliente, // Al guardar localmente, la dirección ya va unificada
        'latitud': latitud,
        'longitud': longitud,
      }
    };
  }
}

// 🔒 Helpers globales compactos (Expresiones de una sola línea, más limpios)
int _parseToInt(dynamic value) => value == null ? 0 : (int.tryParse(value.toString()) ?? 0);
double _parseToDouble(dynamic value) => value == null ? 0.0 : (double.tryParse(value.toString()) ?? 0.0);
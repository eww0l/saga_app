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

  factory PedidoModel.fromJson(Map<String, dynamic> json) {
    final clienteMap = json['clientes'] ?? {};

    return PedidoModel(
      id: _toInt(json['id']),
      codigoBarra: json['codigo_barra']?.toString() ?? '',
      descripcionProducto: json['descripcion_producto']?.toString() ?? '',
      estado: json['estado']?.toString() ?? 'Asignado',
      prioridad: json['prioridad']?.toString() ?? 'Baja',
      intentosEntrega: _toInt(json['intentos_entrega']),

      nombreCliente: clienteMap['nombre']?.toString() ?? 'No especificado',

      direccionCliente:
          '${clienteMap['direccion'] ?? ''}, ${clienteMap['distrito'] ?? ''}',

      latitud: _toDouble(clienteMap['latitud']),
      longitud: _toDouble(clienteMap['longitud']),
    );
  }

  // 🔒 Helpers blindados contra Supabase / String / null / int / double
  static int _toInt(dynamic value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
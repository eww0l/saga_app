class ApiConstants {
  // 💡 NOTA PARA LA DEMO: 
  // Si usas el emulador de Android Studio, '10.0.22' es la IP especial para apuntar al localhost de tu PC.
  // Si usas tu celular real conectado por USB, debes poner la IP local de tu computadora (Ej: 192.168.1.X).
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  
  static const String pedidosCourier = '$baseUrl/pedidos-courier';
  static const String rutaOptimizada = '$baseUrl/mapas/ruta-optima';
  static const String escanearPedido = '$baseUrl/pedidos/escanear';
}
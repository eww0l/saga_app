import 'package:connectivity_plus/connectivity_plus.dart';

abstract class BaseDatasource {
  // ⚙️ Dirección IP o URL unificada para que sea transportable al instante
  // final String baseUrl = "https://saga-api-546y.onrender.com/api";
  final String baseUrl = "http://192.168.1.18:8000/api";

  // 🛠️ FUNCIÓN AUXILIAR GENERAL: Verifica si el dispositivo tiene internet real
  Future<bool> verificarInternet() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }
}
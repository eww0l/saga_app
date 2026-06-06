import 'package:flutter/material.dart';
import '../../../data/datasources/login_datasource.dart';

class LoginController extends ChangeNotifier {
  final LoginDatasource _loginDatasource = LoginDatasource();

  // Estados privados que antes estaban en la pantalla
  List<String> _empresas = [];
  String? _empresaSeleccionada;
  bool _isLoading = false;
  bool _isLoadingEmpresas = true;
  String? _errorMessage;

  // Getters públicos para que la vista pueda leerlos pero no modificarlos directo
  List<String> get empresas => _empresas;
  String? get empresaSeleccionada => _empresaSeleccionada;
  bool get isLoading => _isLoading;
  bool get isLoadingEmpresas => _isLoadingEmpresas;
  String? get errorMessage => _errorMessage;

  // Setter para cuando el usuario cambie el dropdown
  void seleccionarEmpresa(String? nuevaEmpresa) {
    _empresaSeleccionada = nuevaEmpresa;
    notifyListeners(); // 🔔 Redibuja la UI
  }

  // 📡 Función 1: Cargar catálogo de empresas
  Future<void> cargarEmpresas() async {
    try {
      _isLoadingEmpresas = true;
      _errorMessage = null;
      notifyListeners();

      _empresas = await _loginDatasource.fetchEmpresasActivas();
      
      if (_empresas.isNotEmpty) {
        _empresaSeleccionada = _empresas.first;
      }
      _isLoadingEmpresas = false;
    } catch (e) {
      _isLoadingEmpresas = false;
      _errorMessage = "No se pudo conectar con el catálogo de empresas.";
    }
    notifyListeners();
  }

  // 🚀 Función 2: Validar e iniciar jornada (Devuelve true si el login es exitoso)
  Future<bool> iniciarJornada(String codigo) async {
    if (_empresaSeleccionada == null) {
      _errorMessage = "Por favor, espere a que se carguen los operadores.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final respuestaApi = await _loginDatasource.autenticarJornada(
        codigo.trim(),
        _empresaSeleccionada!,
      );

      if (respuestaApi.containsKey('error_detectado')) {
        _isLoading = false;
        _errorMessage = respuestaApi['error_detectado'];
        notifyListeners();
        return false;
      }

      _isLoading = false;
      notifyListeners();
      return true; // 🏁 Login exitoso, autoriza el paso al MainLayout
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
import 'package:flutter/material.dart';
import '../controllers/login_controller.dart'; // 🔄 NUEVO: Importamos el controlador
import 'main_layout.dart'; 
import '../widgets/login/login_header.dart';
import '../widgets/login/login_error.dart';
import '../widgets/login/login_form.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  final LoginController _controller = LoginController(); // 🧠 Instancia del controlador de lógica

  @override
  void initState() {
    super.initState();
    _controller.cargarEmpresas(); // Dispara la carga inicial al abrir la app
    
    // Escuchamos los cambios del controlador para redibujar la UI automáticamente
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _procesarLogin() async {
    if (_formKey.currentState!.validate()) {
      // El controlador hace todo el trabajo y nos devuelve un booleano
      final bool loginExitoso = await _controller.iniciarJornada(_codigoController.text);

      if (loginExitoso && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainLayout(
              courierId: _codigoController.text.trim(),
              empresa: _controller.empresaSeleccionada!,
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _controller.dispose(); // Limpiamos el controlador al destruir la pantalla
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LoginHeader(),
              const SizedBox(height: 30),
              
              // Si el controlador tiene un mensaje de error, lo pintamos
              if (_controller.errorMessage != null) ...[
                LoginError(errorMessage: _controller.errorMessage!),
                const SizedBox(height: 20),
              ],
              
              // Pasamos los datos limpios del controlador al formulario
              LoginForm(
                formKey: _formKey,
                codigoController: _codigoController,
                empresas: _controller.empresas,
                empresaSeleccionada: _controller.empresaSeleccionada,
                isLoading: _controller.isLoading,
                isLoadingEmpresas: _controller.isLoadingEmpresas,
                onEmpresaChanged: _controller.seleccionarEmpresa,
                onFormSubmit: _procesarLogin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
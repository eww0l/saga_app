import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/datasources/api_datasource.dart'; // 💡 NUEVO IMPORT
import 'main_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  final ApiDatasource _apiDatasource = ApiDatasource(); // 💡 INSTANCIA DE LA API
  
  String _empresaSeleccionada = 'Saga Falabella (Flota Interna)';
  bool _isLoading = false;
  String? _errorMessage; // 💡 Para pintar el error en el Login si Python rebota

  final List<String> _empresas = [
    'Saga Falabella (Flota Interna)',
    'Olva Courier (Socio B2B)',
    'Chazki (Socio B2B)',
    'Urbano (Socio B2B)'
  ];

  void _iniciarJornada() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null; // Limpiamos errores previos
      });

      try {
        // 🔥 VALIDACIÓN EN CALIENTE: Consultamos a la API antes de cambiar de pantalla
        await _apiDatasource.fetchPedidosPorCourier(
          _codigoController.text.trim(), 
          _empresaSeleccionada
        );

        if (mounted) {
          setState(() => _isLoading = false);
          
          // Si no saltó ninguna excepción, las credenciales son 100% reales y válidas
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainLayout(
                courierId: _codigoController.text.trim(),
                empresa: _empresaSeleccionada,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            // Limpiamos el texto del error para mostrar solo el mensaje de Python
            _errorMessage = e.toString().replaceAll('Exception: ', '');
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
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
              const Text(
                'FALABELLA',
                style: TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.w900, 
                  color: SagaTheme.primaryGreen,
                  letterSpacing: 2
                ),
              ),
              const Text(
                'Portal de Control de Última Milla',
                style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 30),

              // 💡 Cuadro de error dinámico dentro del Login
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'INICIAR JORNADA',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        DropdownButtonFormField<String>(
                          value: _empresaSeleccionada,
                          isExpanded: true, // 💡 OBLIGATORIO: Fuerza al dropdown a usar todo el ancho disponible sin salirse
                          decoration: const InputDecoration(
                            labelText: 'Operador Logístico',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business),
                          ),
                          items: _empresas.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value, 
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis, // 💡 AGREGA ESTO: Pone el "..." si el texto es muy largo
                                maxLines: 1, // 💡 AGREGA ESTO: Fuerza a que se mantenga en una sola línea
                              ),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() => _empresaSeleccionada = newValue!);
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _codigoController,
                          decoration: const InputDecoration(
                            labelText: 'Código de Courier',
                            hintText: 'Ej: C-001',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Por favor, ingrese su código';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _isLoading ? null : _iniciarJornada,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SagaTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('INICIAR RUTA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
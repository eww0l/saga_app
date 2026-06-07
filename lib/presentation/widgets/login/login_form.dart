import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController codigoController;
  final List<String> empresas;
  final String? empresaSeleccionada;
  final bool isLoading;
  final bool isLoadingEmpresas;
  final ValueChanged<String?> onEmpresaChanged;
  final VoidCallback onFormSubmit;

  const LoginForm({
    super.key,
    required this.formKey,
    required this.codigoController,
    required this.empresas,
    required this.empresaSeleccionada,
    required this.isLoading,
    required this.isLoadingEmpresas,
    required this.onEmpresaChanged,
    required this.onFormSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'INICIAR JORNADA',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              isLoadingEmpresas
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: SagaTheme.primaryGreen,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Cargando operadores logísticos...',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: empresaSeleccionada,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Operador Logístico',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      items: empresas.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: onEmpresaChanged,
                    ),
              const SizedBox(height: 16),

              TextFormField(
                controller: codigoController,
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
                onPressed: (isLoading || isLoadingEmpresas) ? null : onFormSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SagaTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'INICIAR RUTA',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
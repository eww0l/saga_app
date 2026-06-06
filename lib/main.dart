import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'presentation/screens/login_screen.dart';

void main() {
  runApp(const SagaLastMileApp());
}

class SagaLastMileApp extends StatelessWidget {
  const SagaLastMileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saga Falabella Last Mile',
      debugShowCheckedModeBanner: false,
      theme: SagaTheme.lightTheme,
      // 💡 EL ARRANQUE PRINCIPAL: Ahora el sistema inicia controlando el acceso
      home: const LoginScreen(), 
    );
  }
}
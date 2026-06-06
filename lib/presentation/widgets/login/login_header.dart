import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'FALABELLA',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: SagaTheme.primaryGreen,
            letterSpacing: 2,
          ),
        ),
        Text(
          'Portal de Control de Última Milla',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
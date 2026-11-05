import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Logotipo de FarmiQ. Si la imagen no está disponible, dibuja el nombre con los colores de la marca.
class LogoFarmiq extends StatelessWidget {
  const LogoFarmiq({super.key, this.alto = 32});

  final double alto;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.png',
      height: alto,
      fit: BoxFit.contain,
      semanticLabel: 'FarmiQ',
      errorBuilder: (context, error, stackTrace) => _LogoTexto(alto: alto),
    );
  }
}

class _LogoTexto extends StatelessWidget {
  const _LogoTexto({required this.alto});

  final double alto;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      const TextSpan(
        children: [
          TextSpan(text: 'Farm', style: TextStyle(color: AppColors.azul)),
          TextSpan(text: 'iQ', style: TextStyle(color: AppColors.verde)),
        ],
      ),
      style: TextStyle(
        fontSize: alto * 0.9,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    );
  }
}

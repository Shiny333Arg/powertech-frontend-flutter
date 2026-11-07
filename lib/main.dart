import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/pantallas/pantalla_diagnostico.dart';

void main() {
  // go_router entra en el paso siguiente, cuando haya mas de una pantalla
  // y un redirect por estado de sesion que valga la pena.
  runApp(const ProviderScope(child: AppPowerTech()));
}

class AppPowerTech extends StatelessWidget {
  const AppPowerTech({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PowerTech',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
      ),
      home: const PantallaDiagnostico(),
    );
  }
}

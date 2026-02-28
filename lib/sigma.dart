import 'package:flutter/material.dart';
import 'package:sigma/router.dart';

/// Author: Ian Wilkey and Barney Jin
final class SigmaApp extends StatelessWidget {
  const SigmaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sigma',
      debugShowCheckedModeBanner: false,
      routerConfig: SIGMA_ROUTER,
    );
  }
}

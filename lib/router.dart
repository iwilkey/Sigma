import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sigma/capture/capture.dart';
import 'package:sigma/inference/face_mesh.dart';

final GoRouter SIGMA_ROUTER = GoRouter(
  initialLocation: '/capture',
  routes: [
    GoRoute(
      path: '/capture',
      pageBuilder: (context, state) => sheetPage(
        state: state,
        child: FaceCaptureState(
          onCapturePressed: (final FaceMesh mesh) {
            context.push('/review', extra: mesh);
          },
        ),
      ),
    ),
    GoRoute(
      path: '/review',
      pageBuilder: (context, state) {
        final FaceMesh mesh = state.extra as FaceMesh;
        return sheetPage(
          state: state,
          child: FaceReviewState(mesh: mesh),
        );
      },
    ),
  ],
);

CustomTransitionPage<void> sheetPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    opaque: false,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 420),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final CurvedAnimation c = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final Animatable<Offset> s = Tween<Offset>(
        begin: const Offset(0, 1.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      final Animatable<double> sc = Tween<double>(
        begin: 0.98,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      final Animation<double> so = Tween<double>(
        begin: 0.0,
        end: 0.28,
      ).animate(c);
      return Stack(
        children: [
          IgnorePointer(
            child: FadeTransition(
              opacity: so,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
          SlideTransition(
            position: c.drive(s),
            child: ScaleTransition(
              scale: c.drive(sc),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

final class FaceReviewState extends StatelessWidget {
  final FaceMesh mesh;
  const FaceReviewState({super.key, required this.mesh});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: Center(
        child: Text('Points: ${mesh.points.length}'),
      ),
    );
  }
}

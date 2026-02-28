import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sigma/capture/capture.dart';
import 'package:sigma/inference/face_mesh.dart';

final GoRouter SIGMA_ROUTER = GoRouter(
  initialLocation: '/capture',
  routes: [
    GoRoute(
      path: '/capture',
      pageBuilder: (context, state) => _fadeSlidePage(
        state: state,
        child: FaceCaptureState(
          onCapturePressed: (FaceMesh mesh) {
            // Push and pass mesh as "extra"
            context.push('/review', extra: mesh);
          },
        ),
      ),
    ),
    GoRoute(
      path: '/review',
      pageBuilder: (context, state) {
        final FaceMesh mesh = state.extra as FaceMesh;
        return _fadeSlidePage(
          state: state,
          child: FaceReviewState(mesh: mesh),
        );
      },
    ),
  ],
);

CustomTransitionPage<void> _fadeSlidePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final Animatable<Offset> offsetTween = Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: animation.drive(offsetTween),
          child: child,
        ),
      );
    },
  );
}

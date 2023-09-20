import 'package:flutter_auth_refreshtoken/screens/home_screen.dart';
import 'package:flutter_auth_refreshtoken/screens/login_screen.dart';
import 'package:flutter_auth_refreshtoken/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';

final loggedOutRoute = RouteMap(routes: {
  '/': (_) => const MaterialPage(child: LoginScreen()),
  '/signup': (_) => const MaterialPage(child: SignupScreen()),
});
final loggedInRoute = RouteMap(
  routes: {
    '/': (_) => const MaterialPage(child: HomeScreen()),
  },
);

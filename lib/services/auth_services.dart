import 'dart:convert';

import 'package:flutter_auth_refreshtoken/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_auth_refreshtoken/models/user.dart';
import 'package:flutter_auth_refreshtoken/models/secure_storage.dart';
import 'package:flutter_auth_refreshtoken/providers/user_provider.dart';
import 'package:flutter_auth_refreshtoken/screens/home_screen.dart';
import 'package:flutter_auth_refreshtoken/screens/signup_screen.dart';
import 'package:flutter_auth_refreshtoken/utils/constants.dart';
import 'package:flutter_auth_refreshtoken/utils/utils.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class AuthService {
  var logger = Logger(
    printer: PrettyPrinter(),
  );
  final client = RetryClient(http.Client());

  final SecureStorage _secureStorage = SecureStorage();
  Map<String, String> headers = {
    'Content-Type': 'application/json',
  };

  void signUpUser({
    required BuildContext context,
    required String username,
    required String password,
    required String name,
  }) async {
    try {
      User user = User(
        id: '',
        name: name,
        password: password,
        username: username,
        token: '',
      );

      http.Response res = await http.post(
          Uri.parse('${Constants.uri}/api/signup'),
          body: user.toJson(),
          headers: headers);

      httpErrorHandle(
        response: res,
        context: context,
        onSuccess: () {
          showSnackBar(
            context,
            'Account created! Login with the same credentials!',
          );
        },
      );
    } catch (e) {
      showSnackBar(context, e.toString());
    }
  }

  void signInUser({
    required BuildContext context,
    required String username,
    required String password,
  }) async {
    try {
      var userProvider = Provider.of<UserProvider>(context, listen: false);
      final navigator = Navigator.of(context);
      String cookie = "";
      http.Response res = await client.post(Uri.parse('${Constants.uri}/login'),
          body: jsonEncode({
            'username': username,
            'password': password,
          }),
          headers: headers);
      String? rawCookie = res.headers['set-cookie'];
      logger.d('rawCooie $rawCookie');
      if (rawCookie != null) {
        int index = rawCookie.indexOf(';');
        await _secureStorage.setRefreshToken(
            (index == -1) ? rawCookie : rawCookie.substring(0, index));
        cookie = (index == -1) ? rawCookie : rawCookie.substring(0, index);
        logger.w(
            'cookie  ${(index == -1) ? rawCookie : rawCookie.substring(0, index)}\n se: ${await _secureStorage.getRefreshToken()}');
      }
      logger.d(headers);
      logger.d(cookie);
      var response = jsonDecode(res.body);
      await _secureStorage.setAccessToken('${response['accessToken']}');

      http.Response userRes = await http
          .get(Uri.parse('${Constants.uri}/me'), headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        "Cookie": "${await _secureStorage.getRefreshToken()}",
        "Authorization": "Bearer ${await _secureStorage.getAccessToken()}"
      });

      var responseUserRes = jsonDecode(userRes.body);
      logger.d("useres $responseUserRes");
      httpErrorHandle(
        response: res,
        context: context,
        onSuccess: () async {
          final SecureStorage secureStorage = SecureStorage();
          userProvider.setUser(jsonEncode({
            'id': responseUserRes['id'],
            "name":
                "${responseUserRes['firstname']} ${responseUserRes['lastname']}",
            "username": "${responseUserRes['username']}",
          }));
          await secureStorage
              .setAccessToken(jsonDecode(res.body)['accessToken']);
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
            (route) => false,
          );
        },
      );
    } catch (e) {
      showSnackBar(context, e.toString());
    }
  }

  // get user data
  void getUserData(
    BuildContext context,
  ) async {
    try {
      var userProvider = Provider.of<UserProvider>(context, listen: false);
      String? token = await _secureStorage.getAccessToken();

      if (token == null) {
        await _secureStorage.setAccessToken('');
      }

      var tokenRes =
          await http.get(Uri.parse('${Constants.uri}/accesstoken'), headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        "Cookie": "${await _secureStorage.getRefreshToken()}",
      });

      if (tokenRes.statusCode == 200) {
        var response = jsonDecode(tokenRes.body);

        await _secureStorage.setAccessToken('${response['accessToken']}');

        http.Response userRes = await http
            .get(Uri.parse('${Constants.uri}/me'), headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Cookie": "${await _secureStorage.getRefreshToken()}",
          "Authorization": "Bearer ${await _secureStorage.getAccessToken()}"
        });
        var responseUserRes = jsonDecode(userRes.body);
        logger.d('${responseUserRes['id']}');
        userProvider.setUser(jsonEncode({
          "id": responseUserRes['id'],
          "name":
              "${responseUserRes['firstname']} ${responseUserRes['lastname']}",
          "username": "${responseUserRes['username']}",
        }));
      }
    } catch (e) {
      logger.e(e.toString());
      showSnackBar(context, e.toString());
    }
  }

  void signOut(BuildContext context) async {
    final navigator = Navigator.of(context);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('x-auth-token', '');
    http.Response userRes = await http.get(
      Uri.parse('${Constants.uri}/logout'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        "Cookie": "${await _secureStorage.getRefreshToken()}",
      },
    );
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
      (route) => false,
    );
  }
}

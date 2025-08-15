import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Client {
  Future<String> Function(Uri authUri) onAuthWebCall;

  final SharedPreferencesAsync _storage = SharedPreferencesAsync();
  Map<String, dynamic>? _authToken;

  Client({
    required this.onAuthWebCall,
  });

  static Uri _makeUri(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool isV2 = true,
  }) {
    return Uri(
      scheme: "https",
      host: isV2 ? "api.tumblr.com" : "www.tumblr.com",
      path: isV2 ? "v2$path" : path,
      queryParameters: queryParameters,
    );
  }

  Future<void> _getAccessToken() async {
    if (_authToken != null) {
      final resp = await http.post(
        _makeUri("/oauth2/token"),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "grant_type": "refresh_token",
          "client_id": dotenv.env["CLIENT_ID"],
          "client_secret": dotenv.env["CLIENT_SECRET"],
          "refresh_token": _authToken!["refresh_token"],
        },
      );

      if (resp.statusCode == 200) {
        final body = resp.body;
        _authToken = json.decode(body);
        await _storage.setString("TUMBLR_TOKEN", body);
        return;
      } else {
        _authToken = null;
        await _storage.remove("TUMBLR_TOKEN");
      }
    } else {
      final storageToken = await _storage.getString("TUMBLR_TOKEN");
      if (storageToken != null) {
        _authToken = json.decode(storageToken);
        return;
      }
    }

    const uuid = Uuid();

    return onAuthWebCall(
      _makeUri(
        "/oauth2/authorize",
        queryParameters: {
          "client_id": dotenv.env["CLIENT_ID"],
          "response_type": "code",
          "scope": "write offline_access",
          "state": uuid.v1(),
        },
        isV2: false,
      ),
    ).then((verifier) async {
      final resp = await http.post(
        _makeUri("/oauth2/token"),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "grant_type": "authorization_code",
          "code": verifier,
          "client_id": dotenv.env["CLIENT_ID"],
          "client_secret": dotenv.env["CLIENT_SECRET"],
        },
      );

      if (resp.statusCode == 200) {
        final body = resp.body;
        _authToken = json.decode(body);
        await _storage.setString("TUMBLR_TOKEN", body);
      }
    });
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final Uri uri = _makeUri(path, queryParameters: queryParameters);

    if (_authToken == null) {
      return _getAccessToken()
          .then((_) {
            return get(path, queryParameters: queryParameters);
          })
          .catchError((err) {
            debugPrint("GET, ERROR, $err");
            return <String, dynamic>{};
          });
    }

    debugPrint("GET, url = ${uri.toString()}");
    final response = await http.get(
      uri,
      headers: {"Authorization": "Bearer ${_authToken?["access_token"]}"},
    );

    debugPrint("GET, ${response.statusCode}, ${response.reasonPhrase}");

    switch (response.statusCode) {
      case 200:
        {
          final body = response.body;
          debugPrint("GET, body = $body");
          return json.decode(body)["response"];
        }

      case 401:
        return _getAccessToken().then((_) {
          return get(path, queryParameters: queryParameters);
        });

      default:
        throw HttpException(
          "GET, status code = ${response.statusCode}",
          uri: uri,
        );
    }
  }

  Future<void> post(String path, {Map<String, dynamic>? body}) async {
    final Uri uri = _makeUri(path);

    if (_authToken == null) {
      return _getAccessToken()
          .then((_) {
            return post(path, body: body);
          })
          .catchError((err) {
            debugPrint("POST, ERROR, $err");
            return;
          });
    }

    debugPrint("POST, url = ${uri.toString()}");
    final String jsonBody = json.encode(body);
    final bodyBytes = utf8.encode(jsonBody);

    final response = await http.post(
      uri,
      headers: {
        "Authorization": "Bearer ${_authToken?["access_token"]}",
        "Content-Length": bodyBytes.length.toString(),
        "Content-Type": "application/json",
      },
      body: bodyBytes,
    );

    switch (response.statusCode) {
      case 200:
      case 201:
        return;

      case 401:
        return _getAccessToken().then((_) {
          return post(path, body: body);
        });

      default:
        throw HttpException(
          "POST, status code = ${response.statusCode}",
          uri: uri,
        );
    }
  }
}

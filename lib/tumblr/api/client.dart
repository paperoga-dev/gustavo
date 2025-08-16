import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";
import "package:uuid/uuid.dart";

class Client {
  Future<String> Function(Uri authUri) onAuthWebCall;

  final _storage = SharedPreferencesAsync();
  Map<String, dynamic>? _authToken;

  Client({required this.onAuthWebCall});

  static Uri _makeUri(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool isV2 = true,
  }) => Uri(
    scheme: "https",
    host: isV2 ? "api.tumblr.com" : "www.tumblr.com",
    path: isV2 ? "v2$path" : path,
    queryParameters: queryParameters,
  );

  Future<void> _getAccessToken() async {
    if (_authToken != null) {
      final http.Response resp = await http.post(
        _makeUri("/oauth2/token"),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "grant_type": "refresh_token",
          "client_id": const String.fromEnvironment("CLIENT_ID"),
          "client_secret": const String.fromEnvironment("CLIENT_SECRET"),
          "refresh_token": _authToken!["refresh_token"],
        },
      );

      if (resp.statusCode == 200) {
        final String body = resp.body;
        _authToken = json.decode(body);
        await _storage.setString("TUMBLR_TOKEN", body);
        return;
      } else {
        _authToken = null;
        await _storage.remove("TUMBLR_TOKEN");
      }
    } else {
      final String? storageToken = await _storage.getString("TUMBLR_TOKEN");
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
          "client_id": const String.fromEnvironment("CLIENT_ID"),
          "response_type": "code",
          "scope": "write offline_access",
          "state": uuid.v1(),
        },
        isV2: false,
      ),
    ).then((verifier) async {
      final http.Response resp = await http.post(
        _makeUri("/oauth2/token"),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "grant_type": "authorization_code",
          "code": verifier,
          "client_id": const String.fromEnvironment("CLIENT_ID"),
          "client_secret": const String.fromEnvironment("CLIENT_SECRET"),
        },
      );

      if (resp.statusCode == 200) {
        final String body = resp.body;
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
      return _getAccessToken().then(
        (_) => get(path, queryParameters: queryParameters),
      );
    }

    debugPrint("GET, url = $uri");
    final http.Response response = await http.get(
      uri,
      headers: {"Authorization": "Bearer ${_authToken?["access_token"]}"},
    );

    debugPrint("GET, ${response.statusCode}, ${response.reasonPhrase}");

    switch (response.statusCode) {
      case 200:
        {
          final String body = response.body;
          debugPrint("GET, body = $body");
          return json.decode(body)["response"];
        }

      case 401:
        return _getAccessToken().then(
          (_) => get(path, queryParameters: queryParameters),
        );

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
      return _getAccessToken().then((_) => post(path, body: body));
    }

    debugPrint("POST, url = $uri");
    final String jsonBody = json.encode(body);
    final Uint8List bodyBytes = utf8.encode(jsonBody);

    final http.Response response = await http.post(
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
        return _getAccessToken().then((_) => post(path, body: body));

      default:
        throw HttpException(
          "POST, status code = ${response.statusCode}",
          uri: uri,
        );
    }
  }
}

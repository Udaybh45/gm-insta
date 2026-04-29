import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ApiService {
  // Default server host — can be overridden in app settings
  static const String defaultServerHost = 'https://gm-insta-f7vj.onrender.com';
  static String? _cachedServerHost;

  static String getServerHostSync() {
    return _cachedServerHost ?? defaultServerHost;
  }

  // To be called at app startup
  static Future<void> initHost() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedServerHost = prefs.getString('gminsta_server_host') ?? defaultServerHost;
  }

  static Future<void> setServerHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    if (host.isEmpty) {
      await prefs.remove('gminsta_server_host');
      _cachedServerHost = defaultServerHost;
    } else {
      var formatted = host.trim();
      if (!formatted.startsWith('http')) formatted = 'http://$formatted';
      if (formatted.endsWith('/')) formatted = formatted.substring(0, formatted.length - 1);
      if (!formatted.contains(':') || formatted.split(':').length < 3) {
        // Assume default port 5000 if not specified (http: and no port)
        if (!formatted.contains(':5000')) formatted = '$formatted:5000';
      }
      await prefs.setString('gminsta_server_host', formatted);
      _cachedServerHost = formatted;
    }
  }

  /// Automatically scan the local network to find the GMinsta backend.
  static Future<String?> findServerOnLocalNetwork() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      // Try for each network interface (Wi-Fi, Ethernet, Mobile Data)
      for (var interface in interfaces) {
        final address = interface.addresses.first.address;
        final subnet = address.substring(0, address.lastIndexOf('.'));

        // Scan the entire subnet (1-254) concurrently in chunks to not overwhelm the system
        const int chunkSize = 20;
        for (int i = 1; i <= 254; i += chunkSize) {
          final scanRange = List.generate(
            (i + chunkSize > 254) ? 254 - i + 1 : chunkSize,
            (index) => '$subnet.${i + index}',
          );

          final results = await Future.wait(scanRange.map((ip) async {
            try {
              final url = 'http://$ip:5000/api/health';
              final response = await http.get(Uri.parse(url)).timeout(const Duration(milliseconds: 500));
              if (response.statusCode == 200) {
                final body = jsonDecode(response.body);
                if (body['name'] == 'gminsta-backend') {
                  return 'http://$ip:5000';
                }
              }
            } catch (_) {}
            return null;
          }));

          final found = results.firstWhere((url) => url != null, orElse: () => null);
          if (found != null) {
            await setServerHost(found);
            return found;
          }
        }
      }
    } catch (e) {
      print('Discovery error: $e');
    }
    return null;
  }


  static String getBaseUrl() {
    return '${getServerHostSync()}/api';
  }

  static String getFullUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${getServerHostSync()}$path';
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gminsta_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gminsta_token');
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('gminsta_user');
    if (str == null) return null;
    return jsonDecode(str);
  }

  static Future<void> setUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gminsta_user', jsonEncode(user));
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gminsta_token');
    await prefs.remove('gminsta_user');
  }

  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> get(String endpoint) async {
    try {
      final base = getBaseUrl();
      final resp = await http.get(
        Uri.parse('$base$endpoint'),
        headers: await getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return jsonDecode(resp.body);
      }
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Request failed');
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  static Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final base = getBaseUrl();
      final resp = await http.post(
        Uri.parse('$base$endpoint'),
        headers: await getHeaders(),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return jsonDecode(resp.body);
      }
      final respBody = jsonDecode(resp.body);
      throw Exception(respBody['message'] ?? 'Request failed');
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  static Future<dynamic> delete(String endpoint) async {
    try {
      final base = getBaseUrl();
      final resp = await http.delete(
        Uri.parse('$base$endpoint'),
        headers: await getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return jsonDecode(resp.body);
      }
      final body = jsonDecode(resp.body);
      throw Exception(body['message'] ?? 'Request failed');
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  static Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final base = getBaseUrl();
      final resp = await http.put(
        Uri.parse('$base$endpoint'),
        headers: await getHeaders(),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return jsonDecode(resp.body);
      }
      final respBody = jsonDecode(resp.body);
      throw Exception(respBody['message'] ?? 'Request failed');
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  static void _handleError(dynamic e) {
    if (e.toString().contains('SocketException') || e.toString().contains('No route to host')) {
      throw Exception('Cannot connect to server. Please ensure your device is on the same network and the backend is running.');
    } else if (e.toString().contains('TimeoutException')) {
      throw Exception('Connection timed out. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? bio,
    String? website,
    bool? isPrivate,
    List<int>? avatarBytes,
    String? avatarFilename,
  }) async {
    final token = await getToken();
    final base = getBaseUrl();
    final request = http.MultipartRequest('PUT', Uri.parse('$base/users/profile/update'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (fullName != null) request.fields['fullName'] = fullName;
    if (bio != null) request.fields['bio'] = bio;
    if (website != null) request.fields['website'] = website;
    if (isPrivate != null) request.fields['isPrivate'] = isPrivate.toString();
    if (avatarBytes != null && avatarFilename != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'avatar', 
        avatarBytes, 
        filename: avatarFilename,
        contentType: _getMediaType(avatarFilename),
      ));
    }
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body);
      await setUser(Map<String, dynamic>.from(data['user']));
      return data;
    }
    final respBody = jsonDecode(resp.body);
    throw Exception(respBody['message'] ?? 'Profile update failed');
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await post('/auth/login', body: {'email': email, 'password': password});
    await setToken(data['token']);
    await setUser(Map<String, dynamic>.from(data['user']));
    return data;
  }

  static Future<Map<String, dynamic>> createPost({
    required String caption,
    String? location,
    bool isReel = false,
    List<int>? mediaBytes,
    String? filename,
  }) async {
    final token = await getToken();
    final base = getBaseUrl();
    final request = http.MultipartRequest('POST', Uri.parse('$base/posts'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    request.fields['caption'] = caption;
    if (location != null) request.fields['location'] = location;
    request.fields['isReel'] = isReel.toString();

    if (mediaBytes != null && filename != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'media', 
        mediaBytes, 
        filename: filename,
        contentType: _getMediaType(filename),
      ));
    }

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body);
    }
    final respBody = jsonDecode(resp.body);
    throw Exception(respBody['message'] ?? 'Failed to create post');
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    final data = await post('/auth/register', body: {
      'username': username,
      'email': email,
      'password': password,
      'fullName': fullName,
    });
    await setToken(data['token']);
    await setUser(Map<String, dynamic>.from(data['user']));
    return data;
  }

  static String getAvatar(Map<String, dynamic>? user) {
    if (user == null) return '';
    if (user['avatar'] != null && user['avatar'].toString().isNotEmpty) {
      return getFullUrl(user['avatar']);
    }
    final name = Uri.encodeComponent(user['username'] ?? 'U');
    return 'https://ui-avatars.com/api/?name=$name&background=2a2a3a&color=c8a96e&size=128&font-size=0.5&bold=true';
  }

  static MediaType _getMediaType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return MediaType('image', ext == 'jpg' ? 'jpeg' : ext);
    } else if (['mp4', 'mov', 'webm'].contains(ext)) {
      return MediaType('video', ext == 'mov' ? 'quicktime' : (ext == 'webm' ? 'webm' : 'mp4'));
    }
    return MediaType('application', 'octet-stream');
  }
}

import 'dart:convert';
import 'package:app_poli/models/antrian_poli_model.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseURL = 'http://10.30.0.16/api_dev/public/index.php/api';

  static const String antrianMultiPoli = '$baseURL/antrian-multi-poli';
  static const String antrianUpdate = '$baseURL/antrian-update';
  static const String antrianOk = '$baseURL/antrian-ok';

  static Future<List<AntrianPoliModel>> getAntrianMultiPoli() async {
    final response = await http.get(Uri.parse(antrianMultiPoli));

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);

      if (jsonData is Map && jsonData.containsKey('data')) {
        final List<dynamic> dataList = jsonData['data'] ?? [];
        return dataList
            .map((json) => AntrianPoliModel.fromJson(json))
            .toList();
      } else {
        throw Exception('Format JSON tidak valid');
      }
    } else {
      throw Exception('Gagal memuat data antrian (${response.statusCode})');
    }
  }

    static Future<bool> updateAntrian(String unit, String registrasi) async {
    try {
      final response = await http.post(
        Uri.parse(antrianUpdate),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'unit': unit,
          'registrasi': registrasi,
        }),
      );

      if (response.statusCode == 200) {
        // print("Berhasil update antrian ID: $id ke status: $status");
        return true;
      } else {
        // print("Gagal update antrian: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error updateAntrian: $e");
      }
      return false;
    }
  }

}

class AntrianPoliModel {
  final String id;
  final String pasien;
  final String no;
  final int idUnit;
  final String poli;
  final String dokter;
  final int statusPanggilan;

  AntrianPoliModel({
    required this.id,
    required this.pasien,
    required this.no,
    required this.idUnit,
    required this.poli,
    required this.dokter,
    required this.statusPanggilan,
  });

  factory AntrianPoliModel.fromJson(Map<String, dynamic> json) {
    return AntrianPoliModel(
      id: json['id']?.toString() ?? '',
      pasien: json['nama'] ?? '',
      no: json['no_antrian']?.toString() ?? '',
      idUnit: int.tryParse(json['id_unit']?.toString() ?? '0') ?? 0,
      poli: json['nm_layanan'] ?? '',
      dokter: json['nm_dokter'] ?? '',
      statusPanggilan: int.tryParse(json['status_panggilan']?.toString() ?? '0') ?? 0,
    );
  }
}

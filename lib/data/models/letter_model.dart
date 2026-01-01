class LetterModel {
  final String id;
  final String nomorSurat;
  final String perihal;
  final String pihakTerkait; // Bisa 'Asal Surat' (Masuk) atau 'Tujuan Surat' (Keluar)
  final String tanggalSurat;
  final String? fileUrl;
  final String jenis; // 'Masuk' atau 'Keluar'

  LetterModel({
    required this.id,
    required this.nomorSurat,
    required this.perihal,
    required this.pihakTerkait,
    required this.tanggalSurat,
    this.fileUrl,
    required this.jenis,
  });

  // Factory untuk Surat Masuk
  factory LetterModel.fromIncoming(Map<String, dynamic> json) {
    return LetterModel(
      id: json['id'],
      nomorSurat: json['nomor_surat'] ?? '-',
      perihal: json['perihal'] ?? '-',
      pihakTerkait: json['asal_surat'] ?? '-',
      tanggalSurat: json['tanggal_surat'] ?? '',
      fileUrl: json['file_url'],
      jenis: 'Masuk',
    );
  }

  // Factory untuk Surat Keluar
  factory LetterModel.fromOutgoing(Map<String, dynamic> json) {
    return LetterModel(
      id: json['id'],
      nomorSurat: json['nomor_surat'] ?? '-',
      perihal: json['perihal'] ?? '-',
      pihakTerkait: json['tujuan_surat'] ?? '-',
      tanggalSurat: json['tanggal_surat'] ?? '',
      fileUrl: json['file_url'],
      jenis: 'Keluar',
    );
  }
}
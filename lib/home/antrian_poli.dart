import 'dart:async';
import 'package:app_poli/models/antrian_poli_model.dart';
import 'package:app_poli/service%20api/api_service_antrian_poli.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:marquee/marquee.dart';

class AntrianPoliPage extends StatefulWidget {
  const AntrianPoliPage({super.key});

  @override
  State<AntrianPoliPage> createState() => _AntrianPoliPageState();
}

class _AntrianPoliPageState extends State<AntrianPoliPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  final PageController posterController = PageController();

  List<AntrianPoliModel> antrianList = [];
  List<AntrianPoliModel> lastCalledList = [];
  String? lastId;
  bool _showPanggilan = false;
  bool _isFetching = false;
  bool _ttsEnabled = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initAudioAccess();
    _initTts();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initAudioAccess() async {
    if (!kIsWeb) {
      setState(() => _ttsEnabled = true);
    } else {
      setState(() => _ttsEnabled = false);
    }
  }

  //tts
  Future<void> _initTts() async {
    try {
      if (!kIsWeb) {
        // Android / TV / iOS → aktifkan engine Google
      await _flutterTts.setEngine("com.google.android.tts");
    }
      // Bahasa & parameter umum
    await _flutterTts.setLanguage("id-ID");
    await _flutterTts.setSpeechRate(0.47);
    await _flutterTts.setPitch(0.94);
    
    await _flutterTts.setVolume(1.0);

    // Tambahan: deteksi apakah TTS bisa bicara
    final voices = await _flutterTts.getVoices;
      if (voices != null && voices is List) {
        final googleVoice = voices.firstWhere(
          (v) => v.toString().contains("id-id") && v.toString().contains("female"),
          orElse: () => null,
        );
        if (googleVoice != null) {
          await _flutterTts.setVoice(googleVoice);
        }
      }

      //print("TTS berhasil diinisialisasi (${kIsWeb ? "Web" : "Android/iOS"})");
    } catch (e) {
      //print("Gagal inisialisasi TTS: $e");
    }
  }

  void _enableAudio() {
    setState(() {
      _ttsEnabled = true;
    });
    debugPrint("Audio diaktifkan user di web");
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchData());
  }

  // Mainkan bel dan TTS
  Future<void> _playSound(AntrianPoliModel data) async {
    try {
      if (mounted) {
        setState(() {
          lastId = data.id;
          _showPanggilan = true;
        });
      }

      // Hentikan TTS yang sebelumnya
      await _flutterTts.stop();

      //Bunyi awal
      debugPrint("Mainkan ding-47489.mp3");
      await _playAudioFile('sounds/ding-47489.mp3');
      await Future.delayed(const Duration(milliseconds: 200));

      //Suara panggilan utama (wanita)
      await _playFemaleVoiceCall(data);

      //Delay pendek biar layar panggilan tidak langsung hilang
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) setState(() => _showPanggilan = false);

    } catch (e) {
      debugPrint("Gagal memainkan suara utama: $e");
      await _speakSequentially("${data.no}, ${data.poli}");
    }
  }

  //Suara wanita: “nomer.mp3” → TTS nomor → “silahkan_menuju.mp3” → TTS poli
  Future<void> _playFemaleVoiceCall(AntrianPoliModel data) async {
    try {
      debugPrint("Mulai panggilan untuk ${data.no} - ${data.poli}");

      // “nomer.mp3”
      await _playAudioFile('sounds/nomer.mp3');
      await Future.delayed(const Duration(milliseconds: 150));

      // Nomor antrian via TTS
      await _speakSequentially(data.no);
      await Future.delayed(const Duration(milliseconds: 150));

      // “silahkan_menuju.mp3”
      await _playAudioFile('sounds/silahkan_menuju.mp3');
      await Future.delayed(const Duration(milliseconds: 150));

      // Nama poli via TTS
      await _speakSequentially(data.poli);

      debugPrint("Panggilan untuk ${data.no} selesai");

    } catch (e) {
      debugPrint("Error di _playFemaleVoiceCall: $e");
      await _speakSequentially("${data.no}, ${data.poli}");
    }
  }

  // Helper untuk TTS dengan penundaan dan sinkron
  Future<void> _speakSequentially(String text) async {
    final completer = Completer();
    _flutterTts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    debugPrint("[TTS] \"$text\"");
    await _flutterTts.speak(text);
    await completer.future;
  }

  //Helper mainkan file audio asset
  Future<void> _playAudioFile(String filePath) async {
    try {
      debugPrint("Mainkan $filePath");
      await _audioPlayer.play(AssetSource(filePath));
      await _audioPlayer.onPlayerComplete.first;
    } catch (e) {
      debugPrint("Error play file $filePath: $e");
      rethrow;
    }
  }

    //Ambil data dari API dan deteksi antrian baru
    Future<void> _fetchData() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final data = await ApiService.getAntrianMultiPoli();

      if (data.isNotEmpty) {
        data.sort((a, b) => b.id.compareTo(a.id));
        final aktif = data.toList();
        final toCall = aktif.where((item) => item.statusPanggilan == 1).toList();

        for (final item in toCall) {
          debugPrint("Panggilan antrian ID: ${item.id}, Poli: ${item.poli}");

          //Aktifkan highlight
          if (mounted) {
            setState(() {
              lastId = item.id;
              _showPanggilan = true;
              antrianList = aktif;
            });
          }

          //Mainkan suara
          await _playSound(item);

          //Update status di server
          await ApiService.updateAntrian(item.idUnit.toString(), item.id);

          //Simpan riwayat panggilan
          lastCalledList.insert(0, item);
          if (lastCalledList.length > 3) lastCalledList.removeLast();

          //Tunggu beberapa detik sebelum reset warna
          await Future.delayed(const Duration(seconds: 3));

          //Kembalikan warna ke semula
          if (mounted && lastId == item.id) {
            setState(() {
              _showPanggilan = false;
            });
          }

          // Perbarui list agar tetap sinkron
          if (mounted) {
            setState(() {
              antrianList = aktif;
            });
          }

          // Jeda sedikit sebelum memproses panggilan berikutnya
          await Future.delayed(const Duration(seconds: 1));
        }

        if (mounted) setState(() => antrianList = data);
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      _isFetching = false;
    }
  }

  // ukuran font angka
  double _calculateNumberFontSize(double screenWidth, bool isPanggilanAktif) {
    if (screenWidth < 600) return isPanggilanAktif ? 90 : 80;
    if (screenWidth < 1200) return isPanggilanAktif ? 140 : 120;
    if (screenWidth < 1920) return isPanggilanAktif ? 200 : 170;
    return isPanggilanAktif ? 260 : 220;
  }

  double _calculatePoliFontSize(double screenWidth) {
    if (screenWidth < 600) return 22;
    if (screenWidth < 1200) return 30;
    if (screenWidth < 1920) return 42;
    return 48;
  }

  // Tambahkan di bawah fungsi lain
  List<String> _splitPoliText(String text) {
    final words = text.split(' ');
    final lines = <String>[];
    final maxWordsPerLine = 2;
    for (int i = 0; i < words.length; i += maxWordsPerLine) {
      final end = (i + maxWordsPerLine) < words.length ? (i + maxWordsPerLine) : words.length;
      lines.add(words.sublist(i, end).join(' '));
    }
    return lines;
  }


@override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;
  final isTablet = screenWidth >= 600 && screenWidth < 1200;
  final isDesktop = screenWidth >= 1200 && screenWidth < 1920;
  final isTV = screenWidth >= 1920;

  final scaleFactor = (screenWidth / 1920).clamp(0.6, 2.2);
  final textScaleFactor = (screenWidth / 1920).clamp(0.8, 2.0);

  AntrianPoliModel? panggilanAktif;
  try {
    panggilanAktif = antrianList.firstWhere(
      (d) => d.id == lastId && _showPanggilan,
    );
  } catch (e) {
    panggilanAktif = null;
  }

  return Scaffold(
    backgroundColor: const Color(0xFF000000),
    body: GestureDetector(
      // onTap: () {
      //   if (kIsWeb && !_ttsEnabled) _enableAudio();
      // },
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (kIsWeb && !_ttsEnabled)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(15 * scaleFactor),
                    color: Colors.orangeAccent.withOpacity(0.3),
                    child: Text(
                      "Klik layar sekali untuk mengaktifkan suara di browser",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 20 * textScaleFactor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                SizedBox(height: 15 * scaleFactor),

                Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile
                            ? 1
                            : isTablet
                                ? 3
                                : isDesktop
                                    ? 3
                                    : 4,
                        crossAxisSpacing: 10 * scaleFactor,
                        mainAxisSpacing: 10 * scaleFactor,
                        childAspectRatio: isMobile ? 2.5 : isTablet ? 2.4 : 2.2,
                      ),
                      itemCount: antrianList.length,
                      itemBuilder: (context, index) {
                        final data = antrianList[index];
                        final isPanggilanAktif = data.id == lastId && _showPanggilan;
                        final poliLines = _splitPoliText(data.poli.toUpperCase());

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isPanggilanAktif
                                  ? [Colors.deepOrangeAccent, Colors.redAccent.shade700]
                                  : [Colors.blueAccent.shade700, Colors.cyanAccent.shade400],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18 * scaleFactor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 18 * scaleFactor,
                                offset: const Offset(4, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Bagian Nomor Antrian
                              Expanded(
                                flex: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: isPanggilanAktif
                                          ? [Colors.redAccent, Colors.deepOrange]
                                          : [Colors.indigoAccent.shade100, Colors.indigo.shade700],
                                    ),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(12 * scaleFactor),
                                      bottomLeft: Radius.circular(12 * scaleFactor),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      data.no,
                                      style: GoogleFonts.poppins(
                                        fontSize: _calculateNumberFontSize(screenWidth, isPanggilanAktif) *
                                            (isTV
                                                ? 1.4
                                                : isDesktop
                                                    ? 1.2
                                                    : 1.0),
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 2.5 * textScaleFactor,
                                        height: 1.0,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(0.6),
                                            blurRadius: 8,
                                            offset: const Offset(2, 3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Bagian Poli & Dokter
                              Expanded(
                                flex: 4,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isPanggilanAktif
                                          ? [Colors.redAccent.shade700, Colors.purple.shade900]
                                          : [Colors.tealAccent.shade700, Colors.teal.shade900],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(12 * scaleFactor),
                                      bottomRight: Radius.circular(12 * scaleFactor),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10 * scaleFactor,
                                    vertical: 8 * scaleFactor,
                                  ),
                                  child: FittedBox( 
                                    fit: BoxFit.scaleDown,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        
                                        for (var line in poliLines)
                                          Text(
                                            line,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.anton(
                                              fontSize: (screenWidth * 0.025)
                                                  .clamp(18, isTV ? 80 : isDesktop ? 60 : 40), 
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 1.8 * textScaleFactor,
                                              height: 1.2,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black.withOpacity(0.7),
                                                  blurRadius: 8,
                                                  offset: const Offset(2, 3),
                                                ),
                                              ],
                                            ),
                                          ),

                                        if (data.dokter != null && data.dokter.isNotEmpty)
                                          Padding(
                                            padding: EdgeInsets.only(top: 4 * scaleFactor),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                data.dokter,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.poppins(
                                                  fontSize: (screenWidth * 0.012)
                                                      .clamp(10, isTV ? 36 : isDesktop ? 28 : 20),
                                                  color: Colors.white.withOpacity(0.9),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // Kalimat berjalan
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 50 * scaleFactor, 
                padding: EdgeInsets.symmetric(horizontal: 16 * scaleFactor),
                decoration: BoxDecoration(
                  color: Colors.black87.withOpacity(0.8), 
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 8,
                      offset: const Offset(0, -2), 
                    ),
                  ],
                ),
                child: Center(
                  child: Marquee(
                    text:
                        "Selamat datang di RSU Sakina Idaman • Mohon tunggu panggilan Anda • Tetap jaga jarak & protokol kesehatan",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16 * textScaleFactor,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                    velocity: 60.0, // sedikit lebih cepat
                    blankSpace: 100.0,
                    startPadding: 10.0,
                    accelerationDuration: const Duration(milliseconds: 500),
                    accelerationCurve: Curves.easeIn,
                    decelerationDuration: const Duration(milliseconds: 500),
                    decelerationCurve: Curves.easeOut,
                    pauseAfterRound: const Duration(milliseconds: 200),
                  ),
                ),
              ),
            ),

               //tampil saat data kosong
            if (antrianList.isEmpty)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: Container(
                  key: const ValueKey("empty_state"),
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF0B1221),
                        Color(0xFF1C1F3A),
                        Color(0xFF262B50),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Shimmer.fromColors(
                          baseColor: Colors.white.withOpacity(0.15),
                          highlightColor: Colors.cyanAccent.withOpacity(0.9),
                          period: const Duration(seconds: 2),
                          direction: ShimmerDirection.ltr,
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.8),
                                Colors.transparent,
                              ],
                              stops: const [0.35, 0.5, 0.65],
                            ).createShader(bounds),
                            blendMode: BlendMode.srcATop,
                            child: Text(
                              "Belum Ada Data...",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 45,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Shimmer.fromColors(
                          baseColor: Colors.white30,
                          highlightColor: Colors.white70,
                          period: const Duration(seconds: 2),
                          child: const Text(
                            "Menunggu data...",
                            style: TextStyle(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              color: Colors.white70,
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        SizedBox(
                          width: 200,
                          height: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Shimmer.fromColors(
                              baseColor: Colors.blueGrey.shade700,
                              highlightColor: Colors.cyanAccent.withOpacity(0.9),
                              period: const Duration(seconds: 2),
                              direction: ShimmerDirection.ltr,
                              child: Container(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),


              //tampilan saat dipanggil
              if (panggilanAktif != null)
                AnimatedOpacity(
                  opacity: _showPanggilan ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.black.withOpacity(0.9),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "NOMOR ANTRIAN",
                            style: GoogleFonts.poppins(
                              color: Colors.orangeAccent,
                              fontSize: 65 * textScaleFactor,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          //SizedBox(height: 10 * scaleFactor),
                          Text(
                            panggilanAktif.no,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 290 * textScaleFactor,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 7,
                            ),
                          ),
                          //SizedBox(height: 5 * scaleFactor),
                          Text(
                            panggilanAktif.poli.toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: Colors.tealAccent,
                              fontSize: 70 * textScaleFactor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (panggilanAktif.dokter != null &&
                              panggilanAktif.dokter.isNotEmpty)
                            Text(
                              panggilanAktif.dokter,
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 50 * textScaleFactor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
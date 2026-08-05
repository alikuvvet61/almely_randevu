import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';

class MedyaGoruntuleyici extends StatefulWidget {
  final List<String> gorseller;
  final int baslangicIndex;
  final String? muhurRol; // [YENİ]
  final String? muhurTel; // [YENİ]

  const MedyaGoruntuleyici({
    super.key,
    required this.gorseller,
    this.baslangicIndex = 0,
    this.muhurRol,
    this.muhurTel,
  });

  @override
  State<MedyaGoruntuleyici> createState() => _MedyaGoruntuleyiciState();
}

class _MedyaGoruntuleyiciState extends State<MedyaGoruntuleyici> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.baslangicIndex;
    _pageController = PageController(initialPage: widget.baslangicIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text("${_currentIndex + 1} / ${widget.gorseller.length}"),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.gorseller.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final url = widget.gorseller[index];
          bool isVideo = url.contains('.mp4') || url.contains('.mov') || url.contains('video');

          return Stack(
            children: [
              if (isVideo)
                VideoOynatici(url: url)
              else
                PhotoView(
                  imageProvider: NetworkImage(url),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                ),
              
              // [DÜZELTME]: Hem resim hem video üzerinde görünen profesyonel mühür katmanı
              Positioned(
                right: 20,
                bottom: 60,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(15), // Yumuşatılmış kenarlar
                    border: Border.all(color: Colors.white10, width: 0.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.muhurRol != null)
                        Text(
                          (widget.muhurRol == "Musteri" || widget.muhurRol == "Müşteri") ? "Müşteri" : widget.muhurRol!,
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 16, 
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      if (widget.muhurTel != null && widget.muhurTel!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            "Tel: ${widget.muhurTel}",
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('dd.MM.yyyy HH:mm:ss').format(DateTime.now()), // Not: Gelecekte dökümandaki kayıt zamanı basılabilir
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class VideoOynatici extends StatefulWidget {
  final String url;
  final String? rol;
  final String? tel;
  const VideoOynatici({super.key, required this.url, this.rol, this.tel});

  @override
  State<VideoOynatici> createState() => _VideoOynaticiState();
}

class _VideoOynaticiState extends State<VideoOynatici> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
        _controller.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          if (!_controller.value.isPlaying)
            const Icon(Icons.play_arrow, size: 80, color: Colors.white70),
        ],
      ),
    );
  }
}

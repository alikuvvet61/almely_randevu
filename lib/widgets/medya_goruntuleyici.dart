import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

class MedyaGoruntuleyici extends StatefulWidget {
  final List<String> gorseller;
  final int baslangicIndex;

  const MedyaGoruntuleyici({
    super.key,
    required this.gorseller,
    this.baslangicIndex = 0,
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

          if (isVideo) {
            return VideoOynatici(url: url);
          } else {
            return PhotoView(
              imageProvider: NetworkImage(url),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            );
          }
        },
      ),
    );
  }
}

class VideoOynatici extends StatefulWidget {
  final String url;
  const VideoOynatici({super.key, required this.url});

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

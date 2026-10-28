import 'package:flutter/material.dart';

class ArtImage extends StatelessWidget {
  const ArtImage({super.key, this.url, this.size = 48});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.music_note, size: size * 0.5),
    );
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: (u == null || u.isEmpty)
          ? fallback
          : Image.network(
              u,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

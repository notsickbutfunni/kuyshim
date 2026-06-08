/// Story data — slide-based visual novel model.
/// Stories are fetched from the backend (kui_story_slides table).
/// This file contains the model + offline fallback data for bundled lessons.
library;

const String cdnBase =
    'https://cdn.jsdelivr.net/gh/sulaakula1/kuishim-assets@main';

/// A single slide in a küy story — one page of the visual novel.
class StorySlide {
  final int order;
  final String imageUrl;
  final Map<String, String> textTranslations;
  final String? audioUrl;

  const StorySlide({
    required this.order,
    required this.imageUrl,
    required this.textTranslations,
    this.audioUrl,
  });

  /// Returns localized text for this slide.
  String text(String lang) {
    return textTranslations[lang] ??
        textTranslations['kz'] ??
        textTranslations.values.first;
  }

  /// Parse from API JSON response.
  factory StorySlide.fromJson(Map<String, dynamic> json) {
    return StorySlide(
      order: json['slide_order'] as int,
      imageUrl: json['image_url'] as String,
      textTranslations: {'api': json['text'] as String},
      audioUrl: json['audio_url'] as String?,
    );
  }
}

/// Full story for one küy (multiple slides).
class KuiStory {
  final String lessonId;
  final List<StorySlide> slides;

  const KuiStory({
    required this.lessonId,
    required this.slides,
  });
}


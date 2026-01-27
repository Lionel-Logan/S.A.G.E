class TTSConfig {
  final int voiceSpeed;
  final double voiceVolume;
  final String voiceGender;
  final String? voiceId;
  final String voiceLanguage;
  final String engine;

  TTSConfig({
    required this.voiceSpeed,
    required this.voiceVolume,
    required this.voiceGender,
    this.voiceId,
    required this.voiceLanguage,
    required this.engine,
  });

  factory TTSConfig.fromJson(Map<String, dynamic> json) {
    return TTSConfig(
      voiceSpeed: json['voice_speed'] ?? 175,
      voiceVolume: (json['voice_volume'] ?? 0.9).toDouble(),
      voiceGender: json['voice_gender'] ?? 'female',
      voiceId: json['voice_id'],
      voiceLanguage: json['voice_language'] ?? 'en-US',
      engine: json['engine'] ?? 'pyttsx3',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'voice_speed': voiceSpeed,
      'voice_volume': voiceVolume,
      'voice_gender': voiceGender,
      if (voiceId != null) 'voice_id': voiceId,
      'voice_language': voiceLanguage,
      'engine': engine,
    };
  }

  TTSConfig copyWith({
    int? voiceSpeed,
    double? voiceVolume,
    String? voiceGender,
    String? voiceId,
    String? voiceLanguage,
    String? engine,
  }) {
    return TTSConfig(
      voiceSpeed: voiceSpeed ?? this.voiceSpeed,
      voiceVolume: voiceVolume ?? this.voiceVolume,
      voiceGender: voiceGender ?? this.voiceGender,
      voiceId: voiceId ?? this.voiceId,
      voiceLanguage: voiceLanguage ?? this.voiceLanguage,
      engine: engine ?? this.engine,
    );
  }
}

class TTSVoice {
  final String id;
  final String name;
  final List<String> languages;
  final String gender;
  final String description;

  TTSVoice({
    required this.id,
    required this.name,
    required this.languages,
    required this.gender,
    required this.description,
  });

  factory TTSVoice.fromJson(Map<String, dynamic> json) {
    return TTSVoice(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      languages: List<String>.from(json['languages'] ?? []),
      gender: json['gender'] ?? 'Male',
      description: json['description'] ?? json['name'] ?? '',
    );
  }
}

class TTSPreset {
  final String name;
  final String voiceId;
  final String description;
  final String icon;

  TTSPreset({
    required this.name,
    required this.voiceId,
    required this.description,
    required this.icon,
  });

  static List<TTSPreset> getPresets() {
    return [
      TTSPreset(
        name: 'Default Female',
        voiceId: 'en+f1',
        description: 'Standard female voice',
        icon: '👩',
      ),
      TTSPreset(
        name: 'Default Male',
        voiceId: 'en',
        description: 'Standard male voice',
        icon: '👨',
      ),
      TTSPreset(
        name: 'Female Variant 2',
        voiceId: 'en+f2',
        description: 'Alternative female voice',
        icon: '👩',
      ),
      TTSPreset(
        name: 'Female Variant 3',
        voiceId: 'en+f3',
        description: 'Higher female voice',
        icon: '👩',
      ),
      TTSPreset(
        name: 'Male Variant 1',
        voiceId: 'en+m1',
        description: 'Alternative male voice',
        icon: '👨',
      ),
      TTSPreset(
        name: 'Male Variant 3',
        voiceId: 'en+m3',
        description: 'Deeper male voice',
        icon: '👨',
      ),
      TTSPreset(
        name: 'Whisper',
        voiceId: 'en+whisper',
        description: 'Soft whisper mode',
        icon: '🤫',
      ),
      TTSPreset(
        name: 'Croaky',
        voiceId: 'en+croak',
        description: 'Raspy voice effect',
        icon: '🎭',
      ),
    ];
  }
}

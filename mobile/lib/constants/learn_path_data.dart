library learn_path_data;

import 'package:flutter/material.dart';
import '../models/kui_note.dart';
import '../main.dart'; // for KColors

enum NodeType {
  skill,
  kui,
  video,
}

class LearnNode {
  final String id;
  final String title;
  final String description;
  final NodeType type;
  final List<KuiNote> notes;
  final bool isPitchGate;
  final String? storyText;
  /// Path to bundled video asset (for NodeType.video)
  final String? videoAsset;
  /// Language-keyed audio narration assets (for NodeType.video)
  /// e.g. {'kz': 'assets/learn_assets/learn_intro_kz.mp3', ...}
  final Map<String, String>? audioAssets;

  const LearnNode({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.notes,
    this.isPitchGate = false,
    this.storyText,
    this.videoAsset,
    this.audioAssets,
  });
}

final List<LearnNode> learnNodes = [
  // ── Intro Video ───────────────────────────────────────────────
  const LearnNode(
    id: 'node_0_intro_video',
    title: 'How Notes Work',
    description: 'Watch a quick video to learn how the app works.',
    type: NodeType.video,
    notes: [],
    videoAsset: 'assets/learn_assets/learn_intro.mp4',
    audioAssets: {
      'kz': 'assets/learn_assets/learn_intro_kz.mp3',
      'en': 'assets/learn_assets/learn_intro_en.mp3',
      'ru': 'assets/learn_assets/learn_intro_ru.mp3',
    },
  ),
  // ── Meet Your Dombra ──────────────────────────────────────────
  LearnNode(
    id: 'node_1_meet',
    title: 'Meet Your Dombra',
    description: 'Learn to play the open strings (D3 and G3).',
    type: NodeType.skill,
    isPitchGate: true,
    notes: [
      KuiNote(id: 1, timeMs: 4000, type: 1, technique: 'sherpe', primaryNote: 'D3', primaryHz: 146.83, stringName: 'bass', fret: 0, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 2, timeMs: 8000, type: 1, technique: 'sherpe', primaryNote: 'G3', primaryHz: 196.00, stringName: 'treble', fret: 0, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 3, timeMs: 12000, type: 1, technique: 'sherpe', primaryNote: 'D3', primaryHz: 146.83, stringName: 'bass', fret: 0, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 4, timeMs: 16000, type: 1, technique: 'sherpe', primaryNote: 'G3', primaryHz: 196.00, stringName: 'treble', fret: 0, lane: 1, strokeDirection: 'down'),
    ],
  ),
  LearnNode(
    id: 'node_2_frets',
    title: 'First Frets',
    description: 'Press the 2nd and 4th frets on the top string (bass).',
    type: NodeType.skill,
    isPitchGate: true,
    notes: [
      KuiNote(id: 1, timeMs: 2000, type: 1, technique: 'sherpe', primaryNote: 'E3', primaryHz: 164.81, stringName: 'bass', fret: 2, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 2, timeMs: 4000, type: 1, technique: 'sherpe', primaryNote: 'F#3', primaryHz: 185.00, stringName: 'bass', fret: 4, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 3, timeMs: 6000, type: 1, technique: 'sherpe', primaryNote: 'E3', primaryHz: 164.81, stringName: 'bass', fret: 2, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 4, timeMs: 8000, type: 1, technique: 'sherpe', primaryNote: 'F#3', primaryHz: 185.00, stringName: 'bass', fret: 4, lane: 1, strokeDirection: 'down'),
    ],
  ),
    LearnNode(
    id: 'node_3_upstrokes',
    title: 'Upstrokes (Жоғары қағыс)',
    description: 'Learn alternate picking: down-up-down-up.',
    type: NodeType.skill,
    isPitchGate: true,
    notes: [
      KuiNote(id: 1, timeMs: 2000, type: 1, technique: 'sherpe', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 2, timeMs: 3500, type: 1, technique: 'sherpe', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 3, timeMs: 5000, type: 1, technique: 'sherpe', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 4, timeMs: 6500, type: 1, technique: 'sherpe', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 1, strokeDirection: 'up'),
    ],
  ),
  LearnNode(
    id: 'node_4_kenes',
    title: 'Кеңес (Kenes)',
    description: 'A traditional song to practice your upstrokes.',
    type: NodeType.skill,
    isPitchGate: true,
    storyText: '"Kenes" means council or conversation. This piece mimics a lively discussion between elders. Use your newly learned upstrokes to keep up the pace!',
    notes: [
      KuiNote(id: 1, timeMs: 2000, type: 1, technique: 'sherpe', primaryNote: 'A3', primaryHz: 220.0, stringName: 'treble', fret: 7, lane: 2, strokeDirection: 'down'),
      KuiNote(id: 2, timeMs: 3000, type: 1, technique: 'sherpe', primaryNote: 'A3', primaryHz: 220.0, stringName: 'treble', fret: 7, lane: 2, strokeDirection: 'up'),
      KuiNote(id: 3, timeMs: 4000, type: 1, technique: 'sherpe', primaryNote: 'B3', primaryHz: 246.94, stringName: 'treble', fret: 9, lane: 3, strokeDirection: 'down'),
      KuiNote(id: 4, timeMs: 5000, type: 1, technique: 'sherpe', primaryNote: 'B3', primaryHz: 246.94, stringName: 'treble', fret: 9, lane: 3, strokeDirection: 'up'),
      KuiNote(id: 5, timeMs: 6000, type: 1, technique: 'sherpe', primaryNote: 'A3', primaryHz: 220.0, stringName: 'treble', fret: 7, lane: 2, strokeDirection: 'down'),
    ],
  ),
  LearnNode(
    id: 'node_5_erkem_1',
    title: 'Еркем-ай: 1-такт',
    description: 'Learn the first measure of Erkem-ai.',
    type: NodeType.skill,
    isPitchGate: true,
    storyText: 'In the vast steppes, nomads carried their culture through music. "Erkem-ai" is a gentle melody often played for loved ones. Let\'s play it together.',
    notes: [
      // Такт 1: П V П V П V П
      // Удар 1 (П): Бас 4 / Требл 5
      KuiNote(id: 1, timeMs: 2000, type: 1, technique: 'qagys', primaryNote: 'F#3', primaryHz: 185.00, stringName: 'bass', fret: 4, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 2, timeMs: 2000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      // Удар 2 (V): Бас 7 / Требл 5
      KuiNote(id: 3, timeMs: 2500, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 4, timeMs: 2500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      // Удар 3 (П): Бас 7 / Требл 5
      KuiNote(id: 5, timeMs: 3000, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 6, timeMs: 3000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      // Удар 4 (V): Бас 7 / Требл 5
      KuiNote(id: 7, timeMs: 3500, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 8, timeMs: 3500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      // Удар 5 (П): Бас 7 / Требл 5
      KuiNote(id: 9, timeMs: 4000, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 10, timeMs: 4000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      // Удар 6 (V): Бас 4 / Требл 5
      KuiNote(id: 11, timeMs: 4500, type: 1, technique: 'qagys', primaryNote: 'F#3', primaryHz: 185.00, stringName: 'bass', fret: 4, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 12, timeMs: 4500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      // Удар 7 (П): Бас 5 / Требл 5
      KuiNote(id: 13, timeMs: 5000, type: 1, technique: 'qagys', primaryNote: 'G3', primaryHz: 196.00, stringName: 'bass', fret: 5, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 14, timeMs: 5000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
    ],
  ),
  LearnNode(
    id: 'node_5_erkem_2',
    title: 'Еркем-ай: 2-такт',
    description: 'Learn the second measure of Erkem-ai.',
    type: NodeType.skill,
    isPitchGate: true,
    notes: [
      // Такт 2: П V П V П V П
      // Удар 8 (П): Бас 5 / Требл 7
      KuiNote(id: 1, timeMs: 2000, type: 1, technique: 'qagys', primaryNote: 'G3', primaryHz: 196.00, stringName: 'bass', fret: 5, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 2, timeMs: 2000, type: 1, technique: 'qagys', primaryNote: 'D4', primaryHz: 293.66, stringName: 'treble', fret: 7, lane: 0, strokeDirection: 'down'),
      // Удар 9 (V): Бас 9 / Требл 7
      KuiNote(id: 3, timeMs: 2500, type: 1, technique: 'qagys', primaryNote: 'B3', primaryHz: 246.94, stringName: 'bass', fret: 9, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 4, timeMs: 2500, type: 1, technique: 'qagys', primaryNote: 'D4', primaryHz: 293.66, stringName: 'treble', fret: 7, lane: 0, strokeDirection: 'up'),
      // Удар 10 (П): Бас 9 / Требл 7
      KuiNote(id: 5, timeMs: 3000, type: 1, technique: 'qagys', primaryNote: 'B3', primaryHz: 246.94, stringName: 'bass', fret: 9, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 6, timeMs: 3000, type: 1, technique: 'qagys', primaryNote: 'D4', primaryHz: 293.66, stringName: 'treble', fret: 7, lane: 0, strokeDirection: 'down'),
      // Удар 11 (V): Бас 9 / Требл 7
      KuiNote(id: 7, timeMs: 3500, type: 1, technique: 'qagys', primaryNote: 'B3', primaryHz: 246.94, stringName: 'bass', fret: 9, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 8, timeMs: 3500, type: 1, technique: 'qagys', primaryNote: 'D4', primaryHz: 293.66, stringName: 'treble', fret: 7, lane: 0, strokeDirection: 'up'),
      // Удар 12 (П): Бас 9 / Требл 7
      KuiNote(id: 9, timeMs: 4000, type: 1, technique: 'qagys', primaryNote: 'B3', primaryHz: 246.94, stringName: 'bass', fret: 9, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 10, timeMs: 4000, type: 1, technique: 'qagys', primaryNote: 'D4', primaryHz: 293.66, stringName: 'treble', fret: 7, lane: 0, strokeDirection: 'down'),
      // Удар 13 (V): Бас 5 / Требл 7
      KuiNote(id: 11, timeMs: 4500, type: 1, technique: 'qagys', primaryNote: 'G3', primaryHz: 196.00, stringName: 'bass', fret: 5, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 12, timeMs: 4500, type: 1, technique: 'qagys', primaryNote: 'D4', primaryHz: 293.66, stringName: 'treble', fret: 7, lane: 0, strokeDirection: 'up'),
      // Удар 14 (П): Бас 7 / Требл 7
      KuiNote(id: 13, timeMs: 5000, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 14, timeMs: 5000, type: 1, technique: 'qagys', primaryNote: 'D4', primaryHz: 293.66, stringName: 'treble', fret: 7, lane: 0, strokeDirection: 'down'),
    ],
  ),
  LearnNode(
    id: 'node_5_erkem_3',
    title: 'Еркем-ай: 3-такт',
    description: 'Learn the third measure of Erkem-ai.',
    type: NodeType.skill,
    isPitchGate: true,
    notes: [
      // Такт 3: П V П V П V П
      // Удар 15 (П): Бас 4 / Требл 5
      KuiNote(id: 1, timeMs: 2000, type: 1, technique: 'qagys', primaryNote: 'F#3', primaryHz: 185.00, stringName: 'bass', fret: 4, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 2, timeMs: 2000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      // Удар 16 (V): Бас 7 / Требл 5
      KuiNote(id: 3, timeMs: 2500, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 4, timeMs: 2500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      // Удар 17 (П): Бас 7 / Требл 5
      KuiNote(id: 5, timeMs: 3000, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 6, timeMs: 3000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      // Удар 18 (V): Бас 7 / Требл 5
      KuiNote(id: 7, timeMs: 3500, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 8, timeMs: 3500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      // Удар 19 (П): Бас 7 / Требл 5
      KuiNote(id: 9, timeMs: 4000, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 10, timeMs: 4000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      // Удар 20 (V): Бас 4 / Требл 5
      KuiNote(id: 11, timeMs: 4500, type: 1, technique: 'qagys', primaryNote: 'F#3', primaryHz: 185.00, stringName: 'bass', fret: 4, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 12, timeMs: 4500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      // Удар 21 (П): Бас 5 / Требл 5
      KuiNote(id: 13, timeMs: 5000, type: 1, technique: 'qagys', primaryNote: 'G3', primaryHz: 196.00, stringName: 'bass', fret: 5, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 14, timeMs: 5000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
    ],
  ),
  LearnNode(
    id: 'node_5_erkem_4',
    title: 'Еркем-ай: 4-такт',
    description: 'Learn the fourth measure of Erkem-ai.',
    type: NodeType.skill,
    isPitchGate: true,
    notes: [
      // Такт 4: П V П V П V П
      // Удар 22 (П): Бас 5 / Требл 5
      KuiNote(id: 1, timeMs: 2000, type: 1, technique: 'qagys', primaryNote: 'G3', primaryHz: 196.00, stringName: 'bass', fret: 5, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 2, timeMs: 2000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      // Удар 23 (V): Бас 7 / Требл 5
      KuiNote(id: 3, timeMs: 2500, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 4, timeMs: 2500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      // Удар 24 (П): Бас 4 / Требл 5
      KuiNote(id: 5, timeMs: 3000, type: 1, technique: 'qagys', primaryNote: 'F#3', primaryHz: 185.00, stringName: 'bass', fret: 4, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 6, timeMs: 3000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      // Удар 25 (V): Бас 4 / Требл 5
      KuiNote(id: 7, timeMs: 3500, type: 1, technique: 'qagys', primaryNote: 'F#3', primaryHz: 185.00, stringName: 'bass', fret: 4, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 8, timeMs: 3500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      // Удар 26 (П): Бас 2 / Требл 0
      KuiNote(id: 9, timeMs: 4000, type: 1, technique: 'qagys', primaryNote: 'E3', primaryHz: 164.81, stringName: 'bass', fret: 2, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 10, timeMs: 4000, type: 1, technique: 'qagys', primaryNote: 'G3', primaryHz: 196.00, stringName: 'treble', fret: 0, lane: 0, strokeDirection: 'down'),
      // Удар 27 (V): Бас 2 / Требл 0
      KuiNote(id: 11, timeMs: 4500, type: 1, technique: 'qagys', primaryNote: 'E3', primaryHz: 164.81, stringName: 'bass', fret: 2, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 12, timeMs: 4500, type: 1, technique: 'qagys', primaryNote: 'G3', primaryHz: 196.00, stringName: 'treble', fret: 0, lane: 0, strokeDirection: 'up'),
      // Удар 28 (П): Бас 0 / Требл 5
      KuiNote(id: 13, timeMs: 5000, type: 1, technique: 'qagys', primaryNote: 'D3', primaryHz: 146.83, stringName: 'bass', fret: 0, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 14, timeMs: 5000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
    ],
  ),
  LearnNode(
    id: 'node_5_erkem_full',
    title: 'Еркем-ай: Толық нұсқасы',
    description: 'Play the full version of Erkem-ai.',
    type: NodeType.skill,
    isPitchGate: true,
    storyText: 'In the vast steppes, nomads carried their culture through music. "Erkem-ai" is a gentle melody often played for loved ones. Now play it in full!',
    notes: [
      // Такт 1: П V П V П V П
      KuiNote(id: 1, timeMs: 2000, type: 1, technique: 'qagys', primaryNote: 'F#3', primaryHz: 185.00, stringName: 'bass', fret: 4, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 2, timeMs: 2000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 3, timeMs: 2500, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 4, timeMs: 2500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      KuiNote(id: 5, timeMs: 3000, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 6, timeMs: 3000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 7, timeMs: 3500, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 8, timeMs: 3500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      KuiNote(id: 9, timeMs: 4000, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 10, timeMs: 4000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 11, timeMs: 4500, type: 1, technique: 'qagys', primaryNote: 'F#3', primaryHz: 185.00, stringName: 'bass', fret: 4, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 12, timeMs: 4500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      KuiNote(id: 13, timeMs: 5000, type: 1, technique: 'qagys', primaryNote: 'G3', primaryHz: 196.00, stringName: 'bass', fret: 5, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 14, timeMs: 5000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),

      // Такт 2: П V П V П V П
      KuiNote(id: 15, timeMs: 5500, type: 1, technique: 'qagys', primaryNote: 'G3', primaryHz: 196.00, stringName: 'bass', fret: 5, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 16, timeMs: 5500, type: 1, technique: 'qagys', primaryNote: 'D4', primaryHz: 293.66, stringName: 'treble', fret: 7, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 17, timeMs: 6000, type: 1, technique: 'qagys', primaryNote: 'B3', primaryHz: 246.94, stringName: 'bass', fret: 9, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 18, timeMs: 6000, type: 1, technique: 'qagys', primaryNote: 'D4', primaryHz: 293.66, stringName: 'treble', fret: 7, lane: 0, strokeDirection: 'up'),
      KuiNote(id: 19, timeMs: 6500, type: 1, technique: 'qagys', primaryNote: 'B3', primaryHz: 246.94, stringName: 'bass', fret: 9, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 20, timeMs: 6500, type: 1, technique: 'qagys', primaryNote: 'D4', primaryHz: 293.66, stringName: 'treble', fret: 7, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 21, timeMs: 7000, type: 1, technique: 'qagys', primaryNote: 'B3', primaryHz: 246.94, stringName: 'bass', fret: 9, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 22, timeMs: 7000, type: 1, technique: 'qagys', primaryNote: 'D4', primaryHz: 293.66, stringName: 'treble', fret: 7, lane: 0, strokeDirection: 'up'),
      KuiNote(id: 23, timeMs: 7500, type: 1, technique: 'qagys', primaryNote: 'B3', primaryHz: 246.94, stringName: 'bass', fret: 9, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 24, timeMs: 7500, type: 1, technique: 'qagys', primaryNote: 'D4', primaryHz: 293.66, stringName: 'treble', fret: 7, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 25, timeMs: 8000, type: 1, technique: 'qagys', primaryNote: 'G3', primaryHz: 196.00, stringName: 'bass', fret: 5, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 26, timeMs: 8000, type: 1, technique: 'qagys', primaryNote: 'D4', primaryHz: 293.66, stringName: 'treble', fret: 7, lane: 0, strokeDirection: 'up'),
      KuiNote(id: 27, timeMs: 8500, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 28, timeMs: 8500, type: 1, technique: 'qagys', primaryNote: 'D4', primaryHz: 293.66, stringName: 'treble', fret: 7, lane: 0, strokeDirection: 'down'),

      // Такт 3: П V П V П V П
      KuiNote(id: 29, timeMs: 9000, type: 1, technique: 'qagys', primaryNote: 'F#3', primaryHz: 185.00, stringName: 'bass', fret: 4, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 30, timeMs: 9000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 31, timeMs: 9500, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 32, timeMs: 9500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      KuiNote(id: 33, timeMs: 10000, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 34, timeMs: 10000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 35, timeMs: 10500, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 36, timeMs: 10500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      KuiNote(id: 37, timeMs: 11000, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 38, timeMs: 11000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 39, timeMs: 11500, type: 1, technique: 'qagys', primaryNote: 'F#3', primaryHz: 185.00, stringName: 'bass', fret: 4, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 40, timeMs: 11500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      KuiNote(id: 41, timeMs: 12000, type: 1, technique: 'qagys', primaryNote: 'G3', primaryHz: 196.00, stringName: 'bass', fret: 5, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 42, timeMs: 12000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),

      // Такт 4: П V П V П V П
      KuiNote(id: 43, timeMs: 12500, type: 1, technique: 'qagys', primaryNote: 'G3', primaryHz: 196.00, stringName: 'bass', fret: 5, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 44, timeMs: 12500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 45, timeMs: 13000, type: 1, technique: 'qagys', primaryNote: 'A3', primaryHz: 220.00, stringName: 'bass', fret: 7, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 46, timeMs: 13000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      KuiNote(id: 47, timeMs: 13500, type: 1, technique: 'qagys', primaryNote: 'F#3', primaryHz: 185.00, stringName: 'bass', fret: 4, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 48, timeMs: 13500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 49, timeMs: 14000, type: 1, technique: 'qagys', primaryNote: 'F#3', primaryHz: 185.00, stringName: 'bass', fret: 4, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 50, timeMs: 14000, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'up'),
      KuiNote(id: 51, timeMs: 14500, type: 1, technique: 'qagys', primaryNote: 'E3', primaryHz: 164.81, stringName: 'bass', fret: 2, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 52, timeMs: 14500, type: 1, technique: 'qagys', primaryNote: 'G3', primaryHz: 196.00, stringName: 'treble', fret: 0, lane: 0, strokeDirection: 'down'),
      KuiNote(id: 53, timeMs: 15000, type: 1, technique: 'qagys', primaryNote: 'E3', primaryHz: 164.81, stringName: 'bass', fret: 2, lane: 1, strokeDirection: 'up'),
      KuiNote(id: 54, timeMs: 15000, type: 1, technique: 'qagys', primaryNote: 'G3', primaryHz: 196.00, stringName: 'treble', fret: 0, lane: 0, strokeDirection: 'up'),
      KuiNote(id: 55, timeMs: 15500, type: 1, technique: 'qagys', primaryNote: 'D3', primaryHz: 146.83, stringName: 'bass', fret: 0, lane: 1, strokeDirection: 'down'),
      KuiNote(id: 56, timeMs: 15500, type: 1, technique: 'qagys', primaryNote: 'C4', primaryHz: 261.63, stringName: 'treble', fret: 5, lane: 0, strokeDirection: 'down'),
    ],
  ),

];

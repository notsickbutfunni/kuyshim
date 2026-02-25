export type Screen = 'onboarding' | 'library' | 'game' | 'tuner' | 'profile' | 'results';

export interface User {
  isGuest: boolean;
  username: string;
  avatar: string;
  level: number;
  rank: 'Student' | 'Akyn' | 'Master' | 'Legend';
  stats: {
    totalPractice: string;
    mastery: number;
    streak: number;
    avgBpm?: number;
    noteAccuracy?: number;
  };
  activity: { date: string; value: number }[]; // Simple activity heatmap data
}

export interface Lesson {
  id: string;
  title: string;
  composer: string;
  difficulty: number; // 1-5
  progress: number;
  image: string;
  notes: GameNote[];
  isPremium: boolean;
}

export interface GameNote {
  time: number; // in seconds
  string: 1 | 2;
  fret: number;
  duration: number;
}

export interface GameResult {
  score: number;
  perfect: number;
  good: number;
  miss: number;
  accuracy: number;
  lessonTitle: string;
  rank: 'S' | 'A' | 'B' | 'C';
  suggestion: string;
}

/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState } from 'react';
import { OnboardingScreen } from './components/OnboardingScreen';
import { LibraryScreen } from './components/LibraryScreen';
import { GameScreen } from './components/GameScreen';
import { TunerScreen } from './components/TunerScreen';
import { ProfileScreen } from './components/ProfileScreen';
import { ResultsScreen } from './components/ResultsScreen';
import { Screen, Lesson, GameResult, User } from './types';
import { Phone } from 'lucide-react';

export default function App() {
  const [currentScreen, setCurrentScreen] = useState<Screen>('onboarding');
  const [selectedLesson, setSelectedLesson] = useState<Lesson | null>(null);
  const [lastResult, setLastResult] = useState<GameResult | null>(null);
  const [user, setUser] = useState<User>({
    isGuest: true,
    username: 'Guest Player',
    avatar: 'https://picsum.photos/seed/guest/200/200',
    level: 1,
    rank: 'Student',
    stats: {
      totalPractice: '0h',
      mastery: 0,
      streak: 0
    },
    activity: []
  });

  const handleStartGuest = () => {
    setCurrentScreen('library');
  };

  const handleSignIn = () => {
    setUser({
      isGuest: false,
      username: 'Bauyrzhan K.',
      avatar: 'https://picsum.photos/seed/bauyrzhan/200/200',
      level: 8,
      rank: 'Akyn',
      stats: {
        totalPractice: '24.5h',
        mastery: 88,
        streak: 7,
        avgBpm: 120,
        noteAccuracy: 92
      },
      activity: [
        { date: '2026-02-01', value: 1 },
        { date: '2026-02-02', value: 2 },
        { date: '2026-02-03', value: 0 },
        { date: '2026-02-04', value: 3 },
        { date: '2026-02-05', value: 1 },
        { date: '2026-02-06', value: 2 },
        { date: '2026-02-07', value: 4 },
        { date: '2026-02-08', value: 1 },
        { date: '2026-02-09', value: 0 },
        { date: '2026-02-10', value: 2 },
      ]
    });
    setCurrentScreen('library');
  };

  const handleLogout = () => {
    setUser({
      isGuest: true,
      username: 'Guest Player',
      avatar: 'https://picsum.photos/seed/guest/200/200',
      level: 1,
      rank: 'Student',
      stats: {
        totalPractice: '0h',
        mastery: 0,
        streak: 0
      },
      activity: []
    });
    setCurrentScreen('onboarding');
  };

  const handleSelectLesson = (lesson: Lesson) => {
    setSelectedLesson(lesson);
    setCurrentScreen('game');
  };

  const handleGameFinish = (result: GameResult) => {
    setLastResult(result);
    setCurrentScreen('results');
  };

  return (
    <div className="h-screen w-screen overflow-hidden">
      {/* Portrait Warning Overlay */}
      <div className="portrait-warning landscape-only">
        <div className="flex flex-col items-center gap-6">
          <div className="w-20 h-20 bg-white/10 rounded-full flex items-center justify-center animate-pulse">
            <Phone className="text-white rotate-90" size={40} />
          </div>
          <div>
            <h2 className="text-2xl font-bold mb-2">Rotate your device</h2>
            <p className="text-white/40 max-w-[240px]">Kuyshim is best experienced in landscape mode.</p>
          </div>
        </div>
      </div>

      {/* Screen Router */}
      {currentScreen === 'onboarding' && (
        <OnboardingScreen 
          onStartGuest={handleStartGuest}
          onSignIn={handleSignIn}
        />
      )}

      {currentScreen === 'library' && (
        <LibraryScreen 
          user={user}
          onSelectLesson={handleSelectLesson} 
          onGoToTuner={() => setCurrentScreen('tuner')}
          onGoToProfile={() => setCurrentScreen('profile')}
        />
      )}

      {currentScreen === 'game' && selectedLesson && (
        <GameScreen 
          lesson={selectedLesson} 
          onBack={() => setCurrentScreen('library')}
          onFinish={handleGameFinish}
        />
      )}

      {currentScreen === 'tuner' && (
        <TunerScreen onBack={() => setCurrentScreen('library')} />
      )}

      {currentScreen === 'profile' && (
        <ProfileScreen 
          user={user}
          onBack={() => setCurrentScreen('library')} 
          onLogout={handleLogout}
        />
      )}

      {currentScreen === 'results' && lastResult && (
        <ResultsScreen 
          result={lastResult}
          user={user}
          onRetry={() => setCurrentScreen('game')}
          onNext={() => setCurrentScreen('library')}
          onMenu={() => setCurrentScreen('library')}
          onSignIn={handleSignIn}
        />
      )}
    </div>
  );
}

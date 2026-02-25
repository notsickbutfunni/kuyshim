import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { ChevronLeft, Play, Pause, RotateCcw, Settings, Volume2, Activity } from 'lucide-react';
import { Waveform } from './Waveform';
import { Lesson, GameResult } from '../types';

interface GameScreenProps {
  lesson: Lesson;
  onBack: () => void;
  onFinish: (result: GameResult) => void;
}

export const GameScreen: React.FC<GameScreenProps> = ({ lesson, onBack, onFinish }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [playbackTime, setPlaybackTime] = useState(0);
  const [playbackSpeed, setPlaybackSpeed] = useState(1);
  const [score, setScore] = useState(0);
  const [combo, setCombo] = useState(0);
  const [feedback, setFeedback] = useState<{ text: string; id: number } | null>(null);
  const [showPauseMenu, setShowPauseMenu] = useState(false);
  
  const [analyzer, setAnalyzer] = useState<AnalyserNode | null>(null);
  const [audioContext, setAudioContext] = useState<AudioContext | null>(null);
  
  const statsRef = useRef({ perfect: 0, good: 0, miss: 0 });
  const lastUpdateRef = useRef(0);
  const strikeLinePos = 150; // px from left

  useEffect(() => {
    let interval: number;
    if (isPlaying && !showPauseMenu) {
      interval = window.setInterval(() => {
        setPlaybackTime(prev => {
          const next = prev + (0.05 * playbackSpeed);
          if (next >= 15) { // Mock end of lesson
            handleFinish();
            return prev;
          }
          return next;
        });
      }, 50);
    }
    return () => clearInterval(interval);
  }, [isPlaying, playbackSpeed, showPauseMenu]);

  const handleFinish = () => {
    setIsPlaying(false);
    const total = statsRef.current.perfect + statsRef.current.good + statsRef.current.miss || 1;
    const accuracy = Math.round((statsRef.current.perfect + statsRef.current.good * 0.7) / total * 100);
    
    let rank: 'S' | 'A' | 'B' | 'C' = 'C';
    if (accuracy > 95) rank = 'S';
    else if (accuracy > 85) rank = 'A';
    else if (accuracy > 70) rank = 'B';

    onFinish({
      score,
      perfect: statsRef.current.perfect,
      good: statsRef.current.good,
      miss: statsRef.current.miss,
      accuracy,
      lessonTitle: lesson.title,
      rank,
      suggestion: accuracy < 80 ? "You struggled with the bridge section. Try practicing at 0.75x speed?" : "Great performance! Ready for the next challenge?"
    });
  };

  const startAudio = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const ctx = new AudioContext();
      const source = ctx.createMediaStreamSource(stream);
      const anal = ctx.createAnalyser();
      source.connect(anal);
      setAudioContext(ctx);
      setAnalyzer(anal);
    } catch (err) {
      console.error("Microphone access denied", err);
    }
  };

  const triggerFeedback = (text: string) => {
    setFeedback({ text, id: Date.now() });
    if (text === 'Perfect') {
      setScore(s => s + 100);
      setCombo(c => c + 1);
      statsRef.current.perfect++;
    } else if (text === 'Good') {
      setScore(s => s + 50);
      setCombo(c => c + 1);
      statsRef.current.good++;
    } else {
      setCombo(0);
      statsRef.current.miss++;
    }
  };

  // Note detection logic
  useEffect(() => {
    const hitWindow = 0.2;
    const currentNote = lesson.notes.find(n => Math.abs(n.time - playbackTime) < hitWindow);
    
    if (currentNote && playbackTime - lastUpdateRef.current > 0.3) {
      // Mocking a successful hit
      triggerFeedback(Math.random() > 0.4 ? 'Perfect' : 'Good');
      lastUpdateRef.current = playbackTime;
    } else if (!currentNote && lesson.notes.some(n => playbackTime > n.time + hitWindow && playbackTime < n.time + hitWindow + 0.1)) {
      // Missed note logic would go here
    }
  }, [playbackTime, lesson.notes]);

  return (
    <div className="flex flex-col h-screen bg-[#0f1115] overflow-hidden relative">
      {/* Header */}
      <div className="flex items-center justify-between p-6 z-10">
        <div className="flex items-center gap-4">
          <button onClick={onBack} className="p-2 hover:bg-white/10 rounded-full transition-colors">
            <ChevronLeft size={24} />
          </button>
          <div>
            <h1 className="text-xl font-bold">{lesson.title}</h1>
            <p className="text-xs text-white/40 font-mono uppercase tracking-widest">{lesson.composer}</p>
          </div>
        </div>
        
        <div className="flex items-center gap-8">
          <div className="text-right">
            <div className="text-sm text-white/40 font-mono uppercase">Score</div>
            <div className="text-2xl font-black text-emerald-400 tracking-tighter">{score.toLocaleString()}</div>
          </div>
          <div className="text-right min-w-[80px]">
            <div className="text-sm text-white/40 font-mono uppercase">Combo</div>
            <div className="text-2xl font-black text-yellow-400 tracking-tighter">x{combo}</div>
          </div>
          <button onClick={() => setShowPauseMenu(true)} className="p-3 bg-white/5 rounded-2xl hover:bg-white/10 transition-all">
            <Settings size={20} />
          </button>
        </div>
      </div>

      {/* Stage Area */}
      <div className="flex-1 relative flex flex-col justify-center">
        {/* Horizontal Strings */}
        <div className="absolute inset-0 flex flex-col justify-center gap-24 pointer-events-none">
          <div className="w-full h-[2px] bg-white/10 relative">
             <div className="absolute inset-0 bg-emerald-500/20 blur-sm" />
          </div>
          <div className="w-full h-[2px] bg-white/10 relative">
             <div className="absolute inset-0 bg-emerald-500/20 blur-sm" />
          </div>
        </div>

        {/* Strike Line */}
        <div 
          className="absolute top-0 bottom-0 w-1 bg-white/20 z-10" 
          style={{ left: strikeLinePos }}
        >
          <div className="absolute top-1/2 -translate-y-1/2 -left-4 w-9 h-48 bg-emerald-500/10 blur-xl rounded-full" />
        </div>

        {/* Notes Container */}
        <div className="relative h-48 w-full">
          {lesson.notes.map((note, idx) => {
            const x = strikeLinePos + (note.time - playbackTime) * 400; // 400px per second
            if (x < -100 || x > 2000) return null;

            return (
              <motion.div
                key={idx}
                className={`absolute w-12 h-12 rounded-full border-4 flex items-center justify-center font-bold text-xs shadow-2xl ${
                  note.string === 1 ? 'top-0 border-emerald-400 bg-emerald-400/20' : 'bottom-0 border-blue-400 bg-blue-400/20'
                }`}
                style={{ left: x }}
              >
                {note.fret}
              </motion.div>
            );
          })}
        </div>
      </div>

      {/* Bottom Controls */}
      <div className="p-8 flex items-center justify-between z-10">
        <div className="flex items-center gap-6">
          <div className="relative">
            <Waveform analyzer={analyzer} isActive={isPlaying} />
            <div className="absolute inset-0 bg-gradient-to-t from-[#0f1115] to-transparent opacity-50" />
          </div>
          {!analyzer && (
            <button onClick={startAudio} className="flex items-center gap-2 px-4 py-2 bg-emerald-500 text-white rounded-xl text-sm font-bold hover:scale-105 transition-all">
              <Activity size={16} />
              Enable Mic
            </button>
          )}
        </div>

        <div className="flex items-center gap-4">
          <div className="flex bg-white/5 rounded-2xl p-1 border border-white/10">
            {[0.5, 0.75, 1].map(speed => (
              <button
                key={speed}
                onClick={() => setPlaybackSpeed(speed)}
                className={`px-4 py-2 rounded-xl text-xs font-mono transition-all ${
                  playbackSpeed === speed ? 'bg-white text-black' : 'text-white/40 hover:text-white/60'
                }`}
              >
                {speed}x
              </button>
            ))}
          </div>
          
          <button 
            onClick={() => setIsPlaying(!isPlaying)}
            className="w-16 h-16 flex items-center justify-center bg-white text-black rounded-3xl hover:scale-105 active:scale-95 transition-all shadow-2xl"
          >
            {isPlaying ? <Pause fill="black" size={28} /> : <Play fill="black" size={28} className="ml-1" />}
          </button>
        </div>
      </div>

      {/* Feedback & Pause Menu Overlays */}
      <AnimatePresence>
        {feedback && (
          <motion.div
            key={feedback.id}
            initial={{ opacity: 0, scale: 0.5, x: '-50%', y: '-50%' }}
            animate={{ opacity: 1, scale: 1.2 }}
            exit={{ opacity: 0, scale: 1.5 }}
            className="fixed top-1/2 left-1/2 pointer-events-none z-50"
          >
            <span className={`text-7xl font-black italic uppercase tracking-tighter drop-shadow-[0_0_30px_rgba(0,0,0,0.5)] ${
              feedback.text === 'Perfect' ? 'text-yellow-400' : 'text-emerald-400'
            }`}>
              {feedback.text}!
            </span>
          </motion.div>
        )}

        {showPauseMenu && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/80 backdrop-blur-md z-[100] flex items-center justify-center p-12"
          >
            <div className="bg-[#1a1c23] border border-white/10 rounded-[40px] p-12 w-full max-w-2xl shadow-2xl">
              <h2 className="text-4xl font-serif italic font-bold mb-12 text-center">Paused</h2>
              
              <div className="space-y-8 mb-12">
                <div className="space-y-4">
                  <div className="flex justify-between text-sm text-white/40 uppercase tracking-widest font-mono">
                    <span>Volume</span>
                    <span>80%</span>
                  </div>
                  <div className="h-2 bg-white/5 rounded-full overflow-hidden">
                    <div className="h-full w-[80%] bg-white" />
                  </div>
                </div>

                <div className="flex items-center justify-between p-6 bg-white/5 rounded-3xl border border-white/10">
                  <div className="flex items-center gap-4">
                    <Volume2 className="text-white/60" />
                    <span className="font-bold">Metronome</span>
                  </div>
                  <div className="w-12 h-6 bg-emerald-500 rounded-full relative">
                    <div className="absolute right-1 top-1 w-4 h-4 bg-white rounded-full" />
                  </div>
                </div>

                <div className="space-y-4">
                  <div className="flex justify-between text-sm text-white/40 uppercase tracking-widest font-mono">
                    <span>Noise Gate Sensitivity</span>
                    <span>Medium</span>
                  </div>
                  <div className="grid grid-cols-3 gap-2">
                    {['Low', 'Med', 'High'].map(v => (
                      <button key={v} className={`py-2 rounded-xl text-xs font-bold border transition-all ${v === 'Med' ? 'bg-white text-black border-white' : 'bg-white/5 text-white/40 border-white/10'}`}>
                        {v}
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              <div className="flex gap-4">
                <button onClick={() => setShowPauseMenu(false)} className="flex-1 py-4 bg-white text-black rounded-2xl font-bold hover:scale-[1.02] transition-all">Resume</button>
                <button onClick={onBack} className="flex-1 py-4 bg-white/5 border border-white/10 text-white rounded-2xl font-bold hover:bg-white/10 transition-all">Exit Practice</button>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};

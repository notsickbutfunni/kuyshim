import React from 'react';
import { motion } from 'motion/react';
import { Play, Music, Trophy, User as UserIcon, Settings, Lock, Zap } from 'lucide-react';
import { Lesson, User } from '../types';
import { LESSONS } from '../constants';

interface LibraryScreenProps {
  user: User;
  onSelectLesson: (lesson: Lesson) => void;
  onGoToTuner: () => void;
  onGoToProfile: () => void;
}

export const LibraryScreen: React.FC<LibraryScreenProps> = ({ user, onSelectLesson, onGoToTuner, onGoToProfile }) => {
  return (
    <div className="flex h-screen bg-[#0f1115]">
      {/* Sidebar Navigation */}
      <div className="w-20 border-r border-white/5 flex flex-col items-center py-8 gap-8">
        <div className="w-12 h-12 bg-emerald-500 rounded-2xl flex items-center justify-center shadow-lg shadow-emerald-500/20 mb-4">
          <Music className="text-white" size={24} />
        </div>
        
        <nav className="flex flex-col gap-6">
          <button className="p-3 bg-white/10 text-white rounded-xl transition-all">
            <Play size={24} />
          </button>
          <button onClick={onGoToTuner} className="p-3 text-white/40 hover:text-white hover:bg-white/5 rounded-xl transition-all">
            <Settings size={24} />
          </button>
          <button onClick={onGoToProfile} className="p-3 text-white/40 hover:text-white hover:bg-white/5 rounded-xl transition-all">
            <UserIcon size={24} />
          </button>
        </nav>

        <div className="mt-auto flex flex-col gap-4">
          <button className="p-3 text-white/20 hover:text-white transition-all">
            <Zap size={20} className="text-yellow-500" />
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="p-8 flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-serif italic font-bold text-white/90">Kuyshim Library</h1>
            <p className="text-white/40 text-sm mt-1">
              {user.isGuest ? 'Guest Access: 1 Lesson Available' : `Welcome back, ${user.username}`}
            </p>
          </div>
          
          <div className="flex items-center gap-4">
            <div className="bg-white/5 border border-white/10 rounded-full px-4 py-2 flex items-center gap-2">
              <Trophy size={16} className="text-yellow-500" />
              <span className="text-sm font-bold">{user.isGuest ? '0' : '2,450'} XP</span>
            </div>
          </div>
        </header>

        <main className="flex-1 overflow-x-auto px-8 pb-8 no-scrollbar">
          <div className="flex gap-8 h-full items-center min-w-max">
            {LESSONS.map((lesson, idx) => {
              const isLocked = user.isGuest && lesson.isPremium;
              
              return (
                <motion.div
                  key={lesson.id}
                  initial={{ opacity: 0, x: 50 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: idx * 0.1 }}
                  onClick={() => !isLocked && onSelectLesson(lesson)}
                  className={`group relative flex-shrink-0 w-[400px] h-[480px] bg-[#1a1c23] rounded-[40px] border border-white/10 overflow-hidden transition-all ${
                    isLocked ? 'cursor-not-allowed opacity-60' : 'cursor-pointer hover:border-emerald-500/50 hover:shadow-2xl hover:shadow-emerald-500/10'
                  }`}
                >
                  <div className="relative h-64 overflow-hidden">
                    <img 
                      src={lesson.image} 
                      alt={lesson.title}
                      className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110"
                      referrerPolicy="no-referrer"
                    />
                    <div className="absolute inset-0 bg-gradient-to-t from-[#1a1c23] via-transparent to-transparent" />
                    
                    {isLocked && (
                      <div className="absolute inset-0 flex items-center justify-center bg-black/40 backdrop-blur-[2px]">
                        <div className="bg-white/10 border border-white/20 p-4 rounded-3xl backdrop-blur-md">
                          <Lock className="text-white" size={32} />
                        </div>
                      </div>
                    )}

                    <div className="absolute top-6 right-6 flex gap-1">
                      {Array.from({ length: 5 }).map((_, i) => (
                        <Music 
                          key={i} 
                          size={12} 
                          className={i < lesson.difficulty ? 'text-emerald-400' : 'text-white/20'} 
                          fill={i < lesson.difficulty ? 'currentColor' : 'none'}
                        />
                      ))}
                    </div>
                  </div>
                  
                  <div className="p-8 flex flex-col h-[calc(480px-256px)]">
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-[10px] font-mono text-white/30 uppercase tracking-[0.2em]">{lesson.composer}</span>
                      <div className="relative w-8 h-8">
                        <svg className="w-full h-full -rotate-90">
                          <circle cx="16" cy="16" r="14" stroke="currentColor" strokeWidth="2" fill="transparent" className="text-white/5" />
                          <circle 
                            cx="16" cy="16" r="14" stroke="currentColor" strokeWidth="2" fill="transparent" 
                            strokeDasharray={2 * Math.PI * 14}
                            strokeDashoffset={2 * Math.PI * 14 * (1 - lesson.progress / 100)}
                            className="text-emerald-500"
                          />
                        </svg>
                        <span className="absolute inset-0 flex items-center justify-center text-[8px] font-bold">{lesson.progress}%</span>
                      </div>
                    </div>
                    
                    <h3 className="text-2xl font-bold mb-6 group-hover:text-emerald-400 transition-colors">{lesson.title}</h3>
                    
                    <div className="mt-auto">
                      <button 
                        disabled={isLocked}
                        className={`w-full py-4 rounded-2xl text-sm font-bold transition-all flex items-center justify-center gap-2 ${
                          isLocked 
                            ? 'bg-white/5 text-white/20' 
                            : 'bg-white text-black hover:scale-[1.02] active:scale-[0.98]'
                        }`}
                      >
                        {isLocked ? 'Premium Only' : (
                          <>
                            <Play size={16} fill="black" />
                            Start Practice
                          </>
                        )}
                      </button>
                    </div>
                  </div>
                </motion.div>
              );
            })}
          </div>
        </main>
      </div>
    </div>
  );
};

import React from 'react';
import { motion } from 'motion/react';
import { Trophy, CheckCircle, Target, RotateCcw, ArrowRight, Menu, Share2, Sparkles, UserPlus } from 'lucide-react';
import { GameResult, User } from '../types';

interface ResultsScreenProps {
  result: GameResult;
  user: User;
  onRetry: () => void;
  onNext: () => void;
  onMenu: () => void;
  onSignIn: () => void;
}

export const ResultsScreen: React.FC<ResultsScreenProps> = ({ result, user, onRetry, onNext, onMenu, onSignIn }) => {
  return (
    <div className="flex h-screen bg-[#0f1115] overflow-hidden">
      {/* Left Side: Hero Stats */}
      <div className="w-1/2 flex flex-col items-center justify-center p-12 border-r border-white/5 relative">
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[400px] h-[400px] bg-emerald-500/5 blur-[100px] rounded-full" />
        
        <motion.div
          initial={{ scale: 0.8, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          className="text-center z-10"
        >
          <div className="text-white/40 uppercase tracking-[0.4em] text-xs font-mono mb-4">Performance Rank</div>
          
          <div className="relative inline-block mb-8">
            <motion.div
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{ type: "spring", delay: 0.5 }}
              className={`text-[10rem] font-black italic leading-none tracking-tighter drop-shadow-[0_0_50px_rgba(16,185,129,0.3)] ${
                result.rank === 'S' ? 'text-yellow-400' : 
                result.rank === 'A' ? 'text-emerald-400' : 
                result.rank === 'B' ? 'text-blue-400' : 'text-white/60'
              }`}
            >
              {result.rank}
            </motion.div>
          </div>
          
          <div className="space-y-1">
            <div className="text-5xl font-black text-white tracking-tighter">
              {result.score.toLocaleString()}
            </div>
            <div className="text-xs text-white/40 uppercase tracking-[0.3em] font-mono">Final Score</div>
          </div>
        </motion.div>
      </div>

      {/* Right Side: Breakdown & Analysis */}
      <div className="w-1/2 flex flex-col p-16 justify-center">
        <h2 className="text-3xl font-serif italic font-bold mb-8">{result.lessonTitle} Analysis</h2>
        
        <div className="grid grid-cols-3 gap-4 mb-10">
          <StatMini label="Perfect" value={`${result.perfect}`} color="text-yellow-400" />
          <StatMini label="Good" value={`${result.good}`} color="text-emerald-400" />
          <StatMini label="Miss" value={`${result.miss}`} color="text-red-400" />
        </div>

        <div className="bg-white/5 border border-white/10 p-8 rounded-[32px] mb-12 relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
            <Sparkles size={48} />
          </div>
          <div className="flex items-center gap-3 mb-3">
            <div className="w-8 h-8 bg-emerald-500/20 rounded-xl flex items-center justify-center">
              <Sparkles size={16} className="text-emerald-400" />
            </div>
            <span className="text-xs text-white/40 uppercase tracking-widest font-mono font-bold">Smart Suggestion</span>
          </div>
          <p className="text-lg text-white/80 leading-relaxed italic">
            "{result.suggestion}"
          </p>
        </div>

        {user.isGuest && (
          <motion.div 
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className="bg-emerald-500/10 border border-emerald-500/20 p-6 rounded-3xl mb-8 flex items-center justify-between"
          >
            <div className="flex items-center gap-4">
              <div className="w-10 h-10 bg-emerald-500/20 rounded-xl flex items-center justify-center">
                <UserPlus size={20} className="text-emerald-400" />
              </div>
              <div>
                <div className="font-bold text-sm">Want to save this progress?</div>
                <div className="text-xs text-white/40">Create an account to track your mastery.</div>
              </div>
            </div>
            <button 
              onClick={onSignIn}
              className="px-4 py-2 bg-emerald-500 text-white rounded-xl text-xs font-bold hover:bg-emerald-600 transition-colors"
            >
              Create Account
            </button>
          </motion.div>
        )}

        <div className="flex flex-col gap-4">
          <button 
            onClick={onNext}
            className="w-full py-5 bg-white text-black rounded-2xl font-bold flex items-center justify-center gap-3 hover:scale-[1.02] active:scale-[0.98] transition-all shadow-xl"
          >
            Next Lesson
            <ArrowRight size={20} />
          </button>
          
          <div className="grid grid-cols-3 gap-4">
            <button 
              onClick={onRetry}
              className="py-4 bg-white/5 border border-white/10 text-white rounded-2xl font-bold flex items-center justify-center gap-2 hover:bg-white/10 transition-all"
            >
              <RotateCcw size={18} />
              Restart
            </button>
            <button 
              onClick={onMenu}
              className="py-4 bg-white/5 border border-white/10 text-white rounded-2xl font-bold flex items-center justify-center gap-2 hover:bg-white/10 transition-all"
            >
              <Menu size={18} />
              Menu
            </button>
            <button 
              className="py-4 bg-white/5 border border-white/10 text-white rounded-2xl font-bold flex items-center justify-center gap-2 hover:bg-white/10 transition-all"
            >
              <Share2 size={18} />
              Share
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

const StatMini = ({ label, value, color }: { label: string; value: string; color: string }) => (
  <div className="bg-white/5 border border-white/10 p-5 rounded-2xl text-center">
    <div className="text-[10px] text-white/30 uppercase tracking-widest font-mono mb-1">{label}</div>
    <div className={`text-xl font-bold ${color}`}>{value}</div>
  </div>
);

import React from 'react';
import { motion } from 'motion/react';
import { Music, User, LogIn } from 'lucide-react';

interface OnboardingScreenProps {
  onStartGuest: () => void;
  onSignIn: () => void;
}

export const OnboardingScreen: React.FC<OnboardingScreenProps> = ({ onStartGuest, onSignIn }) => {
  return (
    <div className="h-screen w-screen bg-[#0f1115] flex flex-col items-center justify-center p-12 overflow-hidden relative">
      {/* Background Glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-emerald-500/10 blur-[120px] rounded-full pointer-events-none" />
      
      <motion.div
        initial={{ scale: 0.8, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ duration: 0.8, ease: "easeOut" }}
        className="flex flex-col items-center text-center z-10"
      >
        <motion.div 
          animate={{ 
            rotate: [0, 5, -5, 0],
            scale: [1, 1.05, 1]
          }}
          transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
          className="w-32 h-32 bg-emerald-500 rounded-[40px] flex items-center justify-center shadow-2xl shadow-emerald-500/20 mb-8"
        >
          <Music className="text-white" size={64} />
        </motion.div>
        
        <h1 className="text-6xl font-serif italic font-bold tracking-tighter mb-4">Kuyshim</h1>
        <p className="text-white/40 text-lg max-w-md mb-12">
          Master the ancient art of the Dombra with real-time AI feedback.
        </p>
        
        <div className="flex flex-col gap-4 w-full max-w-xs">
          <button
            onClick={onStartGuest}
            className="w-full py-4 bg-white text-black rounded-2xl font-bold text-lg hover:scale-105 active:scale-95 transition-all shadow-xl flex items-center justify-center gap-3"
          >
            <User size={20} />
            Start Playing
          </button>
          
          <button
            onClick={onSignIn}
            className="w-full py-4 bg-white/5 border border-white/10 text-white rounded-2xl font-bold text-lg hover:bg-white/10 transition-all flex items-center justify-center gap-3"
          >
            <LogIn size={20} />
            Sign In
          </button>

          <button
            className="mt-4 text-white/30 hover:text-white/60 text-sm font-medium transition-colors"
          >
            Switch Account
          </button>
        </div>
        
        <div className="mt-12 flex gap-8 text-white/20 text-xs font-mono uppercase tracking-widest">
          <span>Tradition</span>
          <span>•</span>
          <span>Technology</span>
          <span>•</span>
          <span>Mastery</span>
        </div>
      </motion.div>
    </div>
  );
};

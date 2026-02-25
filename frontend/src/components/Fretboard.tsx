import React, { useEffect, useRef } from 'react';
import { motion } from 'motion/react';

interface FretboardProps {
  activeNotes: { string: number; fret: number }[];
  playbackTime: number;
}

export const Fretboard: React.FC<FretboardProps> = ({ activeNotes }) => {
  const frets = 19; // Standard Dombra frets
  
  return (
    <div className="relative w-full h-48 bg-[#1a1c23] rounded-xl border border-white/10 overflow-hidden shadow-2xl">
      {/* Wood texture simulation */}
      <div className="absolute inset-0 opacity-10 pointer-events-none bg-[url('https://www.transparenttextures.com/patterns/wood-pattern.png')]" />
      
      {/* Strings */}
      <div className="absolute top-1/3 w-full h-[2px] bg-yellow-600/50 shadow-[0_0_5px_rgba(202,138,4,0.3)]" />
      <div className="absolute top-2/3 w-full h-[2px] bg-yellow-600/50 shadow-[0_0_5px_rgba(202,138,4,0.3)]" />

      {/* Frets */}
      <div className="flex h-full w-full">
        {Array.from({ length: frets }).map((_, i) => (
          <div 
            key={i} 
            className="flex-1 border-r border-white/20 relative flex flex-col justify-around items-center"
          >
            <span className="absolute -top-1 text-[10px] text-white/30 font-mono">{i}</span>
            
            {/* String 1 Active Indicator */}
            <div className="h-1/3 w-full flex items-center justify-center">
              {activeNotes.some(n => n.string === 1 && n.fret === i) && (
                <motion.div 
                  initial={{ scale: 0 }}
                  animate={{ scale: 1 }}
                  className="w-6 h-6 rounded-full bg-emerald-500 shadow-[0_0_15px_rgba(16,185,129,0.6)] border-2 border-white"
                />
              )}
            </div>

            {/* String 2 Active Indicator */}
            <div className="h-1/3 w-full flex items-center justify-center">
              {activeNotes.some(n => n.string === 2 && n.fret === i) && (
                <motion.div 
                  initial={{ scale: 0 }}
                  animate={{ scale: 1 }}
                  className="w-6 h-6 rounded-full bg-emerald-500 shadow-[0_0_15px_rgba(16,185,129,0.6)] border-2 border-white"
                />
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

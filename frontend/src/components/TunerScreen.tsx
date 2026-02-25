import React, { useState, useEffect, useRef } from 'react';
import { motion } from 'motion/react';
import { ChevronLeft, Mic, ArrowUp, ArrowDown } from 'lucide-react';
import { PitchDetector } from 'pitchy';

interface TunerScreenProps {
  onBack: () => void;
}

export const TunerScreen: React.FC<TunerScreenProps> = ({ onBack }) => {
  const [pitch, setPitch] = useState<number | null>(null);
  const [note, setNote] = useState<string>('--');
  const [cents, setCents] = useState(0);
  const [activeString, setActiveString] = useState<1 | 2>(1);
  const [isListening, setIsListening] = useState(false);
  
  const audioContextRef = useRef<AudioContext | null>(null);
  const analyzerRef = useRef<AnalyserNode | null>(null);
  const detectorRef = useRef<PitchDetector<Float32Array> | null>(null);
  const animationFrameRef = useRef<number>(0);

  const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  const getNote = (frequency: number) => {
    const noteNum = 12 * (Math.log(frequency / 440) / Math.log(2));
    const roundedNote = Math.round(noteNum) + 69;
    const cents = Math.floor((noteNum - Math.round(noteNum)) * 100);
    return {
      name: notes[roundedNote % 12] + Math.floor(roundedNote / 12 - 1),
      cents
    };
  };

  const startTuning = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const ctx = new AudioContext();
      const analyzer = ctx.createAnalyser();
      const source = ctx.createMediaStreamSource(stream);
      source.connect(analyzer);
      
      const detector = PitchDetector.forFloat32Array(analyzer.fftSize);
      const input = new Float32Array(detector.inputLength);
      
      audioContextRef.current = ctx;
      analyzerRef.current = analyzer;
      detectorRef.current = detector;
      setIsListening(true);

      const update = () => {
        analyzer.getFloatTimeDomainData(input);
        const [p, clarity] = detector.findPitch(input, ctx.sampleRate);
        
        if (clarity > 0.8 && p > 50 && p < 1000) {
          setPitch(p);
          const { name, cents } = getNote(p);
          setNote(name);
          setCents(cents);
        }
        animationFrameRef.current = requestAnimationFrame(update);
      };
      update();
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    return () => cancelAnimationFrame(animationFrameRef.current);
  }, []);

  const getStatusHint = () => {
    if (!pitch) return "Play a string...";
    if (Math.abs(cents) < 5) return "Perfect!";
    return cents > 0 ? "Tune down" : "Tighten slightly";
  };

  const isInTune = Math.abs(cents) < 5;

  return (
    <div className="flex flex-col h-screen bg-[#0f1115] p-12 overflow-hidden relative">
      {/* Background Glow */}
      <div className={`absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] blur-[120px] rounded-full transition-colors duration-1000 ${
        isInTune ? 'bg-emerald-500/10' : 'bg-white/5'
      }`} />

      <div className="flex items-center justify-between mb-12 z-10">
        <div className="flex items-center gap-4">
          <button onClick={onBack} className="p-3 hover:bg-white/10 rounded-2xl transition-colors">
            <ChevronLeft size={24} />
          </button>
          <h1 className="text-2xl font-serif italic font-bold">Precision Tuner</h1>
        </div>
        
        {!isListening && (
          <button 
            onClick={startTuning}
            className="flex items-center gap-2 px-6 py-3 bg-emerald-500 text-white rounded-2xl font-bold hover:scale-105 transition-all shadow-xl shadow-emerald-500/20"
          >
            <Mic size={20} />
            Start Listening
          </button>
        )}
      </div>

      <div className="flex-1 flex flex-col items-center justify-center gap-16 z-10">
        {/* Note Display */}
        <div className="relative">
          <motion.div 
            animate={{ 
              scale: isInTune ? [1, 1.05, 1] : 1,
              color: isInTune ? '#10b981' : '#ffffff'
            }}
            className="text-[12rem] font-black font-mono tracking-tighter leading-none"
          >
            {note}
          </motion.div>
          <div className="absolute -bottom-8 left-1/2 -translate-x-1/2 text-sm text-white/20 font-mono uppercase tracking-[0.4em]">
            {pitch ? `${Math.round(pitch)} Hz` : '-- Hz'}
          </div>
        </div>

        {/* Scale */}
        <div className="w-full max-w-3xl px-12">
          <div className="relative h-1 bg-white/10 rounded-full mb-12">
            {/* Center Mark */}
            <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 w-[2px] h-8 bg-white/40" />
            
            {/* Needle */}
            <motion.div 
              animate={{ left: `${50 + cents}%` }}
              transition={{ type: 'spring', stiffness: 120, damping: 20 }}
              className="absolute top-1/2 -translate-y-1/2 flex flex-col items-center"
            >
              <div className={`w-1 h-12 rounded-full shadow-2xl transition-colors ${
                isInTune ? 'bg-emerald-400 shadow-emerald-400/50' : 'bg-white'
              }`} />
              <div className={`mt-2 text-xs font-mono font-bold ${isInTune ? 'text-emerald-400' : 'text-white/40'}`}>
                {cents > 0 ? `+${cents}` : cents}
              </div>
            </motion.div>

            <div className="absolute -bottom-8 left-0 text-[10px] text-white/20 font-mono">-50 CENTS</div>
            <div className="absolute -bottom-8 right-0 text-[10px] text-white/20 font-mono">+50 CENTS</div>
          </div>

          <div className="flex flex-col items-center gap-4">
            <span className={`text-xl font-bold uppercase tracking-[0.2em] transition-colors ${
              isInTune ? 'text-emerald-400' : 'text-white/60'
            }`}>
              {getStatusHint()}
            </span>
            {pitch && !isInTune && (
              <motion.div 
                animate={{ y: [0, 5, 0] }}
                transition={{ repeat: Infinity, duration: 1 }}
                className="text-white/40"
              >
                {cents > 0 ? <ArrowDown size={32} /> : <ArrowUp size={32} />}
              </motion.div>
            )}
          </div>
        </div>

        {/* String Selector */}
        <div className="flex gap-6">
          {[
            { id: 1, label: 'Upper String', ref: 'G' },
            { id: 2, label: 'Lower String', ref: 'D' }
          ].map(s => (
            <button
              key={s.id}
              onClick={() => setActiveString(s.id as 1 | 2)}
              className={`px-10 py-5 rounded-[32px] border transition-all flex flex-col items-center gap-1 ${
                activeString === s.id 
                  ? 'bg-white text-black border-white shadow-2xl' 
                  : 'bg-white/5 text-white/40 border-white/10 hover:bg-white/10'
              }`}
            >
              <span className="text-sm font-bold">{s.label}</span>
              <span className="text-[10px] font-mono opacity-60 uppercase tracking-widest">{s.ref} Reference</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
};

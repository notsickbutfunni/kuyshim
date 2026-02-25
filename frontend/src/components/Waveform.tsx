import React, { useEffect, useRef } from 'react';

interface WaveformProps {
  analyzer: AnalyserNode | null;
  isActive: boolean;
}

export const Waveform: React.FC<WaveformProps> = ({ analyzer, isActive }) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (!analyzer || !isActive) return;

    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const bufferLength = analyzer.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);

    let animationId: number;

    const draw = () => {
      animationId = requestAnimationFrame(draw);
      analyzer.getByteTimeDomainData(dataArray);

      ctx.fillStyle = '#0f1115';
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      ctx.lineWidth = 2;
      ctx.strokeStyle = '#10b981';
      ctx.beginPath();

      const sliceWidth = canvas.width / bufferLength;
      let x = 0;

      for (let i = 0; i < bufferLength; i++) {
        const v = dataArray[i] / 128.0;
        const y = (v * canvas.height) / 2;

        if (i === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }

        x += sliceWidth;
      }

      ctx.lineTo(canvas.width, canvas.height / 2);
      ctx.stroke();
    };

    draw();

    return () => cancelAnimationFrame(animationId);
  }, [analyzer, isActive]);

  return (
    <canvas 
      ref={canvasRef} 
      width={300} 
      height={80} 
      className="rounded-lg bg-black/20 border border-white/5"
    />
  );
};

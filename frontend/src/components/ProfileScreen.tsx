import React, { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { 
  ChevronLeft, 
  Trophy, 
  Clock, 
  Target, 
  Star, 
  Settings as SettingsIcon, 
  LogOut, 
  Lock, 
  Zap, 
  Play,
  User as UserIcon,
  ShieldCheck,
  CreditCard,
  Bell
} from 'lucide-react';
import { User } from '../types';
import { cn } from '../utils';

interface ProfileScreenProps {
  user: User;
  onBack: () => void;
  onLogout: () => void;
}

export const ProfileScreen: React.FC<ProfileScreenProps> = ({ user, onBack, onLogout }) => {
  const [showSettings, setShowSettings] = useState(false);

  const badges = [
    { name: 'Fast Fingers', icon: '⚡', date: user.isGuest ? 'Locked' : 'Feb 12' },
    { name: 'Tradition Keeper', icon: '📜', date: user.isGuest ? 'Locked' : 'Feb 15' },
    { name: 'Perfect Adai', icon: '🔥', date: user.isGuest ? 'Locked' : 'Feb 18' },
    { name: 'Early Bird', icon: '🌅', date: 'Locked' },
  ];

  const getRankColor = (rank: string) => {
    switch (rank) {
      case 'Legend': return 'from-yellow-400 to-orange-500';
      case 'Master': return 'from-purple-400 to-pink-500';
      case 'Akyn': return 'from-emerald-400 to-blue-500';
      default: return 'from-slate-400 to-slate-600';
    }
  };

  return (
    <div className="flex h-screen bg-[#0f1115] overflow-hidden relative">
      {/* Left: Identity & Growth */}
      <div className="w-[450px] border-r border-white/5 p-12 flex flex-col">
        <div className="flex items-center justify-between mb-12">
          <button onClick={onBack} className="p-3 hover:bg-white/10 rounded-2xl transition-colors">
            <ChevronLeft size={24} />
          </button>
          <div className="flex items-center gap-2">
            <button 
              onClick={() => setShowSettings(true)}
              className="p-3 hover:bg-white/10 rounded-2xl transition-colors text-white/40 hover:text-white"
            >
              <SettingsIcon size={20} />
            </button>
          </div>
        </div>

        <div className="flex flex-col items-center mb-12">
          <div className="relative mb-6">
            <div className={cn(
              "w-32 h-32 rounded-[40px] p-1 bg-gradient-to-br shadow-2xl",
              getRankColor(user.rank)
            )}>
              <div className="w-full h-full rounded-[38px] bg-[#0f1115] p-1">
                {user.isGuest ? (
                  <div className="w-full h-full rounded-[34px] bg-white/5 flex items-center justify-center">
                    <UserIcon size={48} className="text-white/20" />
                  </div>
                ) : (
                  <img 
                    src={user.avatar} 
                    alt="Avatar" 
                    className="w-full h-full rounded-[34px] object-cover"
                    referrerPolicy="no-referrer"
                  />
                )}
              </div>
            </div>
            {!user.isGuest && (
              <div className="absolute -bottom-2 -right-2 w-10 h-10 bg-yellow-500 rounded-2xl border-4 border-[#0f1115] flex items-center justify-center text-xs font-bold text-black shadow-xl">
                Lvl {user.level}
              </div>
            )}
          </div>

          <h2 className="text-2xl font-bold mb-1">{user.username}</h2>
          <div className="flex items-center gap-2 mb-8">
            <span className="text-xs text-white/40 uppercase tracking-[0.2em] font-mono">Rank:</span>
            <span className={cn(
              "text-xs font-bold uppercase tracking-widest px-2 py-0.5 rounded-md",
              user.isGuest ? "bg-white/5 text-white/40" : "bg-emerald-500/20 text-emerald-400"
            )}>
              {user.rank}
            </span>
          </div>

          {!user.isGuest && (
            <div className="w-full bg-white/5 rounded-2xl p-4 border border-white/10 mb-8">
              <div className="flex justify-between text-[10px] uppercase tracking-widest font-mono text-white/40 mb-2">
                <span>Progress to {user.level + 1}</span>
                <span>{user.stats.mastery}%</span>
              </div>
              <div className="h-2 w-full bg-white/5 rounded-full overflow-hidden">
                <motion.div 
                  initial={{ width: 0 }}
                  animate={{ width: `${user.stats.mastery}%` }}
                  className="h-full bg-emerald-500 shadow-[0_0_10px_rgba(16,185,129,0.5)]"
                />
              </div>
            </div>
          )}

          {user.isGuest ? (
            <div className="text-center">
              <p className="text-sm text-white/40 mb-6 leading-relaxed">
                Your journey begins here. Play your first kyi to unlock stats and track your progress.
              </p>
              <button 
                onClick={onBack}
                className="flex items-center gap-2 px-6 py-3 bg-white text-black rounded-2xl font-bold hover:scale-105 transition-all mx-auto"
              >
                <Play size={18} fill="currentColor" />
                Start Learning
              </button>
            </div>
          ) : (
            <button 
              onClick={onLogout}
              className="flex items-center gap-2 px-6 py-3 bg-red-500/10 text-red-400 border border-red-500/20 rounded-2xl font-bold hover:bg-red-500/20 transition-all"
            >
              <LogOut size={18} />
              Log Out
            </button>
          )}
        </div>

        {/* Dynamic Stats Section */}
        {!user.isGuest && (
          <div className="mt-auto space-y-4">
             <h3 className="text-[10px] text-white/20 uppercase tracking-[0.3em] font-mono font-bold mb-2">Detailed Analytics</h3>
             <div className="grid grid-cols-2 gap-4">
                <div className="bg-white/5 border border-white/10 p-4 rounded-2xl">
                  <div className="text-[10px] text-white/30 uppercase tracking-widest mb-1">Avg BPM</div>
                  <div className="text-xl font-bold text-emerald-400">{user.stats.avgBpm}</div>
                </div>
                <div className="bg-white/5 border border-white/10 p-4 rounded-2xl">
                  <div className="text-[10px] text-white/30 uppercase tracking-widest mb-1">Accuracy</div>
                  <div className="text-xl font-bold text-blue-400">{user.stats.noteAccuracy}%</div>
                </div>
             </div>
          </div>
        )}
      </div>

      {/* Right: Achievements & Activity */}
      <div className="flex-1 p-16 overflow-y-auto no-scrollbar flex flex-col">
        <div className="mb-16">
          <div className="flex items-center justify-between mb-8">
            <h3 className="text-2xl font-serif italic font-bold">Your Achievements</h3>
            {user.isGuest && (
              <span className="text-[10px] text-white/20 uppercase tracking-widest font-mono">Play to unlock</span>
            )}
          </div>
          <div className="grid grid-cols-4 gap-6">
            {badges.map((badge, idx) => (
              <div 
                key={idx}
                className={cn(
                  "p-6 rounded-[32px] border flex flex-col items-center text-center transition-all relative group",
                  badge.date === 'Locked' 
                    ? "bg-white/[0.02] border-white/5 opacity-40" 
                    : "bg-white/5 border-white/10 hover:border-emerald-500/50 hover:bg-white/10"
                )}
              >
                <div className={cn(
                  "text-4xl mb-4 transition-transform duration-500",
                  badge.date !== 'Locked' && "group-hover:scale-110"
                )}>
                  {badge.date === 'Locked' ? <Lock size={32} className="text-white/20" /> : badge.icon}
                </div>
                <h4 className="font-bold text-sm mb-1">{badge.name}</h4>
                <p className="text-[10px] text-white/30 uppercase tracking-widest font-mono">{badge.date}</p>
              </div>
            ))}
          </div>
        </div>

        <div className="mt-auto">
          <div className="flex items-center justify-between mb-8">
            <h3 className="text-2xl font-serif italic font-bold">Activity Tracker</h3>
            <div className="flex items-center gap-4 text-xs font-mono text-white/40 uppercase tracking-widest">
              <span>Total Hours: <span className="text-white">{user.stats.totalPractice}</span></span>
              <span>Streak: <span className="text-yellow-400">{user.stats.streak} Days</span></span>
            </div>
          </div>
          
          <div className="bg-white/5 border border-white/10 p-8 rounded-[40px]">
            <div className="flex gap-2 mb-4">
              {Array.from({ length: 24 }).map((_, i) => {
                const activity = user.activity.find(a => a.date.endsWith(`${i + 1 < 10 ? '0' : ''}${i + 1}`));
                const intensity = activity ? activity.value : 0;
                return (
                  <div 
                    key={i} 
                    className={cn(
                      "w-4 h-4 rounded-sm transition-colors",
                      intensity === 0 ? "bg-white/5" :
                      intensity === 1 ? "bg-emerald-900" :
                      intensity === 2 ? "bg-emerald-700" :
                      intensity === 3 ? "bg-emerald-500" : "bg-emerald-400"
                    )}
                    title={activity ? `${activity.date}: ${activity.value} sessions` : 'No activity'}
                  />
                );
              })}
            </div>
            <div className="flex justify-between text-[10px] text-white/20 uppercase tracking-widest font-mono">
              <span>January</span>
              <span>February</span>
            </div>
          </div>
        </div>
      </div>

      {/* Settings Modal Overlay */}
      <AnimatePresence>
        {showSettings && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="absolute inset-0 z-50 bg-black/80 backdrop-blur-xl flex items-center justify-center p-12"
          >
            <motion.div 
              initial={{ scale: 0.9, y: 20 }}
              animate={{ scale: 1, y: 0 }}
              className="bg-[#1a1c23] border border-white/10 w-full max-w-2xl rounded-[48px] overflow-hidden shadow-2xl"
            >
              <div className="p-12">
                <div className="flex items-center justify-between mb-12">
                  <h2 className="text-3xl font-serif italic font-bold">Account Settings</h2>
                  <button 
                    onClick={() => setShowSettings(false)}
                    className="p-3 hover:bg-white/10 rounded-2xl transition-colors text-white/40"
                  >
                    <ChevronLeft size={24} className="rotate-180" />
                  </button>
                </div>

                <div className="space-y-4">
                  <SettingsItem icon={<UserIcon size={20} />} label="Profile Details" sub="Name, Avatar, Bio" />
                  <SettingsItem icon={<ShieldCheck size={20} />} label="Security" sub="Password, 2FA, Sessions" />
                  <SettingsItem icon={<CreditCard size={20} />} label="Subscription" sub="Pro Plan, Billing History" />
                  <SettingsItem icon={<Bell size={20} />} label="Notifications" sub="Practice reminders, News" />
                </div>

                <div className="mt-12 pt-12 border-t border-white/5 flex gap-4">
                  <button 
                    onClick={onLogout}
                    className="flex-1 py-4 bg-red-500/10 text-red-400 border border-red-500/20 rounded-2xl font-bold flex items-center justify-center gap-2 hover:bg-red-500/20 transition-all"
                  >
                    <LogOut size={20} />
                    Log Out
                  </button>
                  <button 
                    onClick={() => setShowSettings(false)}
                    className="flex-1 py-4 bg-white text-black rounded-2xl font-bold hover:scale-105 transition-all"
                  >
                    Save Changes
                  </button>
                </div>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};

const SettingsItem = ({ icon, label, sub }: { icon: React.ReactNode; label: string; sub: string }) => (
  <button className="w-full p-6 bg-white/5 border border-white/10 rounded-3xl flex items-center gap-6 hover:bg-white/10 hover:border-white/20 transition-all text-left group">
    <div className="w-12 h-12 bg-white/5 rounded-2xl flex items-center justify-center group-hover:scale-110 transition-transform">
      {icon}
    </div>
    <div>
      <div className="font-bold text-lg mb-0.5">{label}</div>
      <div className="text-sm text-white/40">{sub}</div>
    </div>
    <ChevronLeft size={20} className="ml-auto rotate-180 text-white/20" />
  </button>
);

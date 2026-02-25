import { Lesson } from './types';

export const LESSONS: Lesson[] = [
  {
    id: '1',
    title: 'Aksak Kulan',
    composer: 'Ketbuqa',
    difficulty: 2,
    progress: 0,
    isPremium: false,
    image: 'https://picsum.photos/seed/aksak/800/450',
    notes: [
      { time: 1, string: 1, fret: 0, duration: 0.5 },
      { time: 2, string: 1, fret: 2, duration: 0.5 },
      { time: 3, string: 2, fret: 0, duration: 0.5 },
      { time: 4, string: 2, fret: 3, duration: 0.5 },
      { time: 5, string: 1, fret: 5, duration: 1 },
      { time: 7, string: 2, fret: 5, duration: 1 },
    ]
  },
  {
    id: '2',
    title: 'Saryarka',
    composer: 'Kurmangazy',
    difficulty: 5,
    progress: 15,
    isPremium: true,
    image: 'https://picsum.photos/seed/saryarka/800/450',
    notes: [
      { time: 1, string: 1, fret: 5, duration: 0.2 },
      { time: 1.5, string: 2, fret: 5, duration: 0.2 },
      { time: 2, string: 1, fret: 7, duration: 0.2 },
      { time: 2.5, string: 2, fret: 7, duration: 0.2 },
    ]
  },
  {
    id: '3',
    title: 'Balbyrau',
    composer: 'Kurmangazy',
    difficulty: 3,
    progress: 45,
    isPremium: true,
    image: 'https://picsum.photos/seed/balbyrau/800/450',
    notes: []
  },
  {
    id: '4',
    title: 'Adai',
    composer: 'Kurmangazy',
    difficulty: 5,
    progress: 10,
    isPremium: true,
    image: 'https://picsum.photos/seed/adai/800/450',
    notes: []
  },
  {
    id: '5',
    title: 'Konil Ashar',
    composer: 'Dauletkerey',
    difficulty: 2,
    progress: 100,
    isPremium: true,
    image: 'https://picsum.photos/seed/konil/800/450',
    notes: []
  }
];

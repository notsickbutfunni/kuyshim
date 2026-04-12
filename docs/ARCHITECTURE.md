# Kuyshim Architecture Document

## System Overview

Kuyshim is a three-tier system for learning the dombra:

```
┌─────────────────────────────────────────────────────────────┐
│                  Mobile App (Flutter)                        │
│           (UI, Audio Capture, User Interaction)             │
└────────────────┬────────────────────────────────────────────┘
                 │ REST API (HTTPS)
┌────────────────▼────────────────────────────────────────────┐
│                  Backend API Server                          │
│      (User Mgmt, Lessons, Progress, Orchestration)          │
├─────────────────────────────────────────────────────────────┤
│ ┌──────────────────────┐    ┌──────────────────────────┐   │
│ │    Database          │    │  ML Inference Service    │   │
│ │  (Users, Lessons,    │    │  (Audio Analysis,        │   │
│ │   Progress, etc)     │    │   Chord Detection)       │   │
│ └──────────────────────┘    └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│         ML Pipeline (Python)                                 │
│  (Pitch Detection, Chord Recognition, Performance Eval)     │
└─────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Mobile App (Flutter)
**Purpose**: User-facing application for learning

**Key Responsibilities**:
- Display lessons with chord diagrams
- Capture real-time audio via microphone
- Send audio to backend for analysis
- Display real-time feedback (pitch visualization, scoring)
- Show progress, achievements, and statistics
- Offline support for cached lessons

**Data Flow**:
```
User Input (Audio)
    ↓
Local Audio Processing
    ↓
Send to Backend API
    ↓
Display Results & Feedback
```

### 2. Backend API (Node.js/Python/Java)
**Purpose**: Business logic, user management, and orchestration

**Key Responsibilities**:
- User authentication (JWT tokens)
- Lesson management & delivery
- Progress tracking
- Gamification engine (scoring, achievements)
- Route audio data to ML service
- Store and retrieve user data
- API security and rate limiting

**API Categories**:
- **Auth**: `/auth/register`, `/auth/login`, `/auth/refresh`
- **Users**: `/users/:id`, `/users/:id/profile`
- **Lessons**: `/lessons`, `/lessons/:id`
- **Progress**: `/progress/:userId`, `/progress/:userId/:lessonId`
- **Performance**: `/evaluate-performance` (routes to ML)
- **Gamification**: `/achievements`, `/leaderboard`

**Database Schema**:
- Users (authentication, profile)
- Lessons (content, difficulty, metadata)
- UserProgress (completion status, high scores)
- Achievements (badges, milestones)

### 3. ML Service (Python)
**Purpose**: Audio intelligence for learning feedback

**Key Responsibilities**:
- Real-time pitch detection
- Chord recognition
- Performance evaluation (accuracy scoring)
- User feedback generation
- Model training pipeline

**Processing Pipeline**:
```
Raw Audio Input
    ↓
Preprocessing (normalization, noise reduction)
    ↓
Feature Extraction (spectral features, chromagram)
    ↓
Pitch Detection
    ↓
Chord Recognition
    ↓
Performance Scoring
    ↓
Return Feedback
```

**Key Algorithms**:
- **Pitch Detection**: Autocorrelation or PYIN
- **Chord Recognition**: CNN or Hidden Markov Model
- **Scoring**: Weighted combination of accuracy metrics

---

## Data Flow Examples

### Use Case: User Practices a Lesson

```
1. Mobile App:
   - User starts "Chord D" lesson
   - App fetches lesson details from Backend
   - User plays audio (microphone captures)

2. Backend:
   - Receives audio chunk
   - Routes to ML service

3. ML Service:
   - Analyzes pitch, rhythm, timing
   - Returns: {pitch_accuracy: 0.95, timing_accuracy: 0.87, score: 45}

4. Backend:
   - Calculates final score
   - Updates user progress
   - Checks for achievement unlocks

5. Mobile App:
   - Displays feedback: "Great! 95% accuracy"
   - Updates progress bar
   - Shows achievement notification if earned
```

### Use Case: User Logs In

```
1. Mobile App: POST /auth/login (email, password)
2. Backend: Validates credentials, generates JWT token
3. Mobile App: Stores token, uses for authenticated requests
4. Subsequent requests include: Authorization: Bearer {token}
```

---

## Technology Decisions

### Backend
- **Option 1**: Python FastAPI (easy ML integration, modern)
- **Option 2**: Node.js Express (rapid development, larger ecosystem)
- **Option 3**: Java Spring Boot (enterprise-grade, scalable)

**Recommendation**: FastAPI for ML integration benefits

### Database
- **Primary**: PostgreSQL (relational, reliable)
- **Cache**: Redis (session, leaderboard caching)

### ML Serving
- **REST API** (over HTTP) - Simple, but slower
- **gRPC** (binary protocol) - Faster, lower latency
- **Message Queue** (async) - For batched processing

**Recommendation**: REST for simplicity initially, optimize later

### Deployment
- **Backend**: Docker containers, deployed on AWS/GCP/Heroku
- **ML**: Separate container or serverless (AWS Lambda)
- **Mobile**: iOS App Store & Google Play

---

## Development Workflow

### Phase 1: MVP
- [ ] Basic backend with user auth
- [ ] Simple lesson delivery
- [ ] Pitch detection prototype
- [ ] Flutter UI with audio capture

### Phase 2: Enhancement
- [ ] Chord recognition
- [ ] Gamification (achievements, scoring)
- [ ] Performance analytics
- [ ] Leaderboards

### Phase 3: Polish
- [ ] Offline support
- [ ] Advanced ML models
- [ ] App store deployment
- [ ] Performance optimization

---

## Security Considerations

- **Authentication**: JWT tokens with refresh mechanism
- **Audio Privacy**: Clear data retention policy, secure deletion
- **API Security**: Rate limiting, input validation, CORS
- **Database**: Encrypted passwords, TLS for transit
- **Mobile**: No sensitive data in local storage (except encrypted tokens)

---

## Scalability Notes

- **Horizontal scaling**: Load balance API servers
- **ML Service**: Could become bottleneck - consider caching or batch processing
- **Database**: Connection pooling, read replicas for analytics
- **CDN**: Static content (lessons, audio references)

---

## Team Communication

### Daily Standup
- What works, what doesn't, blockers

### Weekly Integration
- Test cross-component interactions
- Sync API contracts

### API Contract-First Development
- Define API endpoints before implementation
- Mobile team waits for API, not implementation details

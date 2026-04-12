FROM python:3.11-slim

# Install system dependencies (FFmpeg for audio processing)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        libsndfile1 \
        libavcodec-extra && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code and models
COPY . .

# Expose port
EXPOSE 8001

# Run the ML API server
CMD ["uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8001"]

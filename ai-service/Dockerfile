FROM python:3.10-slim

WORKDIR /app

# Install system dependencies required for OpenCV and face recognition
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsm6 \
    libxext6 \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first to leverage caching
COPY requirements.txt .

# Install python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app ./app
COPY firebase-credentials.json .
COPY precompute_embeddings.py .

# Create directories for embeddings and temp images
RUN mkdir -p embeddings temp_images

# Set environment variables
ENV FIREBASE_CREDENTIALS_PATH=/app/firebase-credentials.json
ENV PORT=8001

# Expose the port
EXPOSE 8001

# Command to run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]

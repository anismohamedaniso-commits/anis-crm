FROM python:3.11-slim

WORKDIR /app

# Install dependencies (path relative to repo root build context)
COPY server/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy server source
COPY server/ .

# Create data directory for JSON fallback storage
RUN mkdir -p data logs

EXPOSE 8000

# Use Python to read PORT env var as integer — avoids all shell expansion issues
CMD ["python", "-c", "import os,uvicorn; uvicorn.run('main:app', host='0.0.0.0', port=int(os.environ.get('PORT',8000)))"]

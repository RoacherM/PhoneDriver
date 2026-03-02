FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ADB_SERVER_SOCKET=tcp:host.docker.internal:5037

# Install ADB client (server runs on host)
RUN apt-get update && \
    apt-get install -y --no-install-recommends android-tools-adb && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY qwen_vl_agent.py phone_agent.py ui.py config.json ./

# Create screenshots directory
RUN mkdir -p /app/screenshots

EXPOSE 7860

CMD ["python", "ui.py"]

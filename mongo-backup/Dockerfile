FROM python:3.10-slim

# Install system tools
RUN apt-get update && apt-get install -y \
    openssh-client \
    gzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy script
COPY backup.py /app/backup.py
WORKDIR /app

ENTRYPOINT ["python", "backup.py"]


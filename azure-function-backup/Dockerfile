# Dockerfile for backup job container
FROM python:3.10-slim

# Install dependencies
RUN apt-get update && apt-get install -y openssh-client sshpass && rm -rf /var/lib/apt/lists/*

# Install required Python packages
RUN pip install azure-storage-blob paramiko

# Add backup script
COPY backup.py /app/backup.py
WORKDIR /app

# Entry point
ENTRYPOINT ["python", "backup.py"]

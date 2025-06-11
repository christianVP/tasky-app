import os
import io
import paramiko
from azure.storage.blob import BlobServiceClient
from datetime import datetime

# === Load variables ===
vm_ip = os.getenv("VM_HOST")
username = os.getenv("VM_USER")
key_path = os.getenv("PRIVATE_KEY_PATH")
storage_conn_str = os.getenv("BLOB_CONN_STRING")
container_name = "tasky-backups"

# === SSH setup ===
print("🔐 Connecting via SSH...")
# key = paramiko.RSAKey.from_private_key_file(key_path)

print("🔐 Connecting via SSH...")
key = paramiko.RSAKey.from_private_key_file(key_path)
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=vm_ip, username=username, pkey=key)

# === Remote mongodump ===
timestamp = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
backup_filename = f"tasky_backup_{timestamp}.gz"
remote_path = f"/tmp/{backup_filename}"
dump_cmd = f"mongodump --archive={remote_path} --gzip --username=admin --password=mongo --authenticationDatabase=admin"

print("📦 Running mongodump on remote VM...")
stdin, stdout, stderr = ssh.exec_command(dump_cmd)
print(stdout.read().decode(), stderr.read().decode())

# === Download backup ===
print("📥 Downloading backup...")
sftp = ssh.open_sftp()
sftp.get(remote_path, backup_filename)
sftp.close()
ssh.close()

# === Upload to Azure Blob ===
print("☁️ Uploading to Azure Blob Storage...")
blob_service = BlobServiceClient.from_connection_string(storage_conn_str)
blob_client = blob_service.get_blob_client(container=container_name, blob=backup_filename)
with open(backup_filename, "rb") as data:
    blob_client.upload_blob(data)
print(f"✅ Backup uploaded as {backup_filename}")


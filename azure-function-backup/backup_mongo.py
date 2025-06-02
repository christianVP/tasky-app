# backup_mongo.py
import datetime
import logging
import os
import paramiko
import azure.functions as func
from azure.storage.blob import BlobServiceClient

app = func.FunctionApp()

@app.function_name(name="MongoBackupTimer")
@app.schedule(schedule="0 0 * * * *", arg_name="timer", run_on_startup=False,
              use_monitor=True)  # Every hour
def mongo_backup(timer: func.TimerRequest) -> None:
    logging.info('Mongo backup function triggered at %s', datetime.datetime.utcnow())

    try:
        vm_ip = os.getenv("MONGO_VM_IP")
        username = os.getenv("VM_USERNAME")
        key_path = os.getenv("PRIVATE_KEY_PATH")
        storage_conn_str = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
        container_name = os.getenv("AZURE_CONTAINER_NAME")

        # SSH setup
        key = paramiko.RSAKey.from_private_key_file(key_path)
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(hostname=vm_ip, username=username, pkey=key)

        # Remote mongodump
        timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
        backup_file = f"tasky_backup_{timestamp}.gz"
        remote_cmd = f"mongodump --archive=/tmp/{backup_file} --gzip --username=admin --password=mongo --authenticationDatabase=admin"
        stdin, stdout, stderr = ssh.exec_command(remote_cmd)
        stdout.channel.recv_exit_status()  # Wait for command to finish
        logging.info("mongodump stdout: %s", stdout.read().decode())
        logging.error("mongodump stderr: %s", stderr.read().decode())

        # SFTP download
        sftp = ssh.open_sftp()
        sftp.get(f"/tmp/{backup_file}", f"/tmp/{backup_file}")
        sftp.close()
        ssh.close()

        # Upload to Azure Blob
        blob_service = BlobServiceClient.from_connection_string(storage_conn_str)
        blob_client = blob_service.get_blob_client(container=container_name, blob=backup_file)
        with open(f"/tmp/{backup_file}", "rb") as data:
            blob_client.upload_blob(data)
        logging.info("Backup %s uploaded to Azure Blob Storage", backup_file)

    except Exception as e:
        logging.exception("Backup failed: %s", str(e))



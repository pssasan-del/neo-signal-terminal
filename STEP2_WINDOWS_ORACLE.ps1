$ErrorActionPreference='Stop'
$Key='C:\Users\DELL\Downloads\ssh-key-2026-08-31.key'
$HostName='129.154.35.105'
$Source=Split-Path -Parent $MyInvocation.MyCommand.Path
scp -i $Key -r "$Source\backend" "opc@${HostName}:/home/opc/neo_v18_upload_backend"
scp -i $Key "$Source\STEP2_ORACLE_DEPLOY.sh" "opc@${HostName}:/home/opc/STEP2_ORACLE_DEPLOY.sh"
ssh -i $Key "opc@$HostName" "chmod +x /home/opc/STEP2_ORACLE_DEPLOY.sh && SRC_BACK=/home/opc/neo_v18_upload_backend bash -lc 'rm -rf /home/opc/neo_v18_package && mkdir -p /home/opc/neo_v18_package && cp -a /home/opc/neo_v18_upload_backend /home/opc/neo_v18_package/backend && cp /home/opc/STEP2_ORACLE_DEPLOY.sh /home/opc/neo_v18_package/ && cd /home/opc/neo_v18_package && ./STEP2_ORACLE_DEPLOY.sh'"

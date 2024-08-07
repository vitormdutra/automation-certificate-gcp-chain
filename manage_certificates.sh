#!/bin/bash

dns_dir=$1

# Verifica se o argumento foi passado
if [[ -z "$dns_dir" ]]; then
    echo "Uso: $0 <dns_dir>"
    exit 1
fi

# Caminho para os arquivos gerados
cert_dir="/etc/letsencrypt/live/$dns_dir"
privkey="$cert_dir/privkey.pem"
fullchain="$cert_dir/fullchain.pem"
output_path="/etc/mongo-tls/gcp/mongodb.pem"

# Verifica se os arquivos existem
if [[ -f "$privkey" && -f "$fullchain" ]]; then
    echo "Concatenando chave privada e certificado..."
    sudo mkdir -p /etc/mongo-tls/gcp
    cat "$privkey" "$fullchain" | sudo tee "$output_path" >/dev/null

    # Ajusta as permissões
    echo "Ajustando permissões..."
    sudo chown -R mongod:mongod /etc/mongo-tls/gcp
    sudo chmod 600 "$output_path"
else
    echo "Falha ao encontrar os arquivos de certificado necessários."
    exit 1
fi

# Executa o comando no MongoDB para rotacionar certificados
echo "Executando comando de rotação de certificados no MongoDB..."
mongosh --eval "db.runCommand({rotateCertificates: 1})" admin

if [ $? -ne 0 ]; then
    echo "Falha ao executar o comando de rotação de certificados no MongoDB."
    exit 1
fi

echo "Certificados manipulados e rotação concluída com sucesso."

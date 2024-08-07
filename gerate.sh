#!/bin/bash

email=$1
dns=$2
member=$3
path=$4

# Verifica se todos os argumentos necessários foram fornecidos
if [[ -z "$email" || -z "$dns" || -z "$member" || -z "$path" ]]; then
    echo "Uso: $0 <email> <dns> <member> <path>"
    exit 1
fi

# Verifica se o comando está instalado
command_exists() {
    command -v "$1" &>/dev/null
}

# Função para instalar um pacote usando yum
install_package() {
    if ! rpm -q "$1" &>/dev/null; then
        echo "Instalando $1..."
        sudo yum install -y "$1" || { echo "Falha ao instalar $1."; exit 1; }
    else
        echo "$1 já está instalado."
    fi
}

# Instala pacotes necessários
install_package epel-release
install_package certbot
install_package python3-certbot-dns-cloudflare

# Verifica se o gcloud está instalado
if ! command_exists gcloud; then
    echo "gcloud não está instalado. Instale o Google Cloud SDK primeiro."
    exit 1
fi

# Adiciona binding de política IAM no projeto
echo "Adicionando binding de política IAM no projeto..."
gcloud projects add-iam-policy-binding vaas-dev-core-app-0 \
  --member=serviceAccount:"$member" \
  --role=roles/publicca.externalAccountKeyCreator || { echo "Falha ao adicionar binding de política IAM."; exit 1; }

# Cria uma chave de conta externa
echo "Criando chave de conta externa..."
output=$(gcloud publicca external-account-keys create 2>&1)
if [ $? -ne 0 ]; then
    echo "Falha ao criar chave de conta externa: $output"
    exit 1
fi

b64MacKey=$(echo "$output" | grep "b64MacKey:" | awk '{print $2}')
keyId=$(echo "$output" | grep "keyId:" | awk '{print $2}' | sed 's/\]$//')

if [[ -z "$keyId" || -z "$b64MacKey" ]]; then
    echo "Falha ao obter keyId ou b64MacKey."
    exit 1
fi

echo "Chave de conta externa criada com sucesso."

# Verifica se o Certbot já está registrado
account_dir="/etc/letsencrypt/accounts/dv.acme-v02.api.pki.goog/directory"

if [ -d "$account_dir" ] && [ -n "$(ls -A $account_dir)" ]; then
    echo "O Certbot já está registrado. Pulando o registro."
else
    echo "Registrando com Certbot..."
    certbot register \
        --email "$email" \
        --no-eff-email \
        --server "https://dv.acme-v02.api.pki.goog/directory" \
        --eab-kid "$keyId" \
        --eab-hmac-key "$b64MacKey" \
        --agree-tos || { echo "Falha ao registrar com Certbot."; exit 1; }
fi

# Executa o comando certbot certonly utilizando o plugin Cloudflare
echo "Solicitando certificado com Certbot usando o plugin Cloudflare..."
certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials "$path" \
    --preferred-challenges "dns-01" \
    --server "https://dv.acme-v02.api.pki.goog/directory" \
    --domains "$dns" || { echo "Falha ao solicitar certificado."; exit 1; }

echo "Script concluído com sucesso."

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

# Função para verificar se um pacote está instalado
is_installed() {
    rpm -q "$1" &>/dev/null
}

# Função para instalar um pacote usando yum
install_package() {
    sudo yum install -y "$1"
}

# Verifica se o certbot está instalado
if ! is_installed certbot; then
    echo "Certbot não está instalado. Instalando..."
    sudo yum install -y epel-release
    install_package certbot
    if [ $? -ne 0 ]; then
        echo "Falha ao instalar o certbot."
        exit 1
    fi
else
    echo "Certbot já está instalado."
fi

# Verifica se o plugin do Cloudflare para certbot está instalado
if ! is_installed python3-certbot-dns-cloudflare; then
    echo "Plugin Cloudflare para Certbot não está instalado. Instalando..."
    install_package python3-certbot-dns-cloudflare
    if [ $? -ne 0 ]; then
        echo "Falha ao instalar o plugin Cloudflare."
        exit 1
    fi
else
    echo "Plugin Cloudflare para Certbot já está instalado."
fi

# Executa o comando gcloud para adicionar a política de IAM
echo "Adicionando binding de política IAM no projeto..."
gcloud projects add-iam-policy-binding vaas-dev-core-app-0 \
  --member=$member \
  --role=roles/publicca.externalAccountKeyCreator
if [ $? -ne 0 ]; then
    echo "Falha ao adicionar binding de política IAM."
    exit 1
fi

# Cria uma chave de conta externa e captura os valores gerados
echo "Criando chave de conta externa..."
output=$(gcloud publicca external-account-keys create)
if [ $? -ne 0 ]; then
    echo "Falha ao criar chave de conta externa."
    exit 1
fi
keyId=$(echo "$output" | grep "keyId:" | awk '{print $2}')
b64MacKey=$(echo "$output" | grep "b64MacKey:" | awk '{print $2}')

if [[ -z "$keyId" || -z "$b64MacKey" ]]; then
    echo "Falha ao obter keyId ou b64MacKey."
    exit 1
fi

echo "Chave de conta externa criada com sucesso."

# Executa o comando certbot register
echo "Registrando com Certbot..."
certbot register \
    --email "$email" \
    --no-eff-email \
    --server "https://dv.acme-v02.api.pki.goog/directory" \
    --eab-kid "$keyId" \
    --eab-hmac-key "$b64MacKey"
if [ $? -ne 0 ]; then
    echo "Falha ao registrar com Certbot."
    exit 1
fi

# Executa o comando certbot certonly utilizando o plugin Cloudflare
echo "Solicitando certificado com Certbot usando o plugin Cloudflare..."
certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials $path \
    --manual \
    --preferred-challenges "dns-01" \
    --server "https://dv.acme-v02.api.pki.goog/directory" \
    --domains "$dns"
if [ $? -ne 0 ]; then
    echo "Falha ao solicitar certificado."
    exit 1
fi

echo "Script concluído com sucesso."

# Certificados de Automação e Rotação no MongoDB

Este repositório contém dois scripts bash para automatizar a geração de certificados TLS usando Certbot e a rotação de certificados no MongoDB. Os scripts são projetados para serem executados em um servidor Linux com acesso à CLI do Google Cloud e ao Certbot.

## Scripts

1. **`generate_certificates.sh`**

   Este script principal automatiza o processo de registro de uma conta no Certbot, geração de certificados TLS usando um plugin de DNS do Cloudflare, e chama um script secundário para manipular os certificados e rotacioná-los no MongoDB.

2. **`manage_certificates.sh`**

   Este script secundário manipula os certificados gerados, concatenando a chave privada e o certificado completo em um único arquivo para uso pelo MongoDB. Também executa um comando no MongoDB para rotacionar os certificados.

## Requisitos

- **Certbot**: Instalado e configurado.
- **Google Cloud CLI**: Instalado e configurado.
- **MongoDB Shell (`mongosh`)**: Instalado e configurado no servidor.
- **Permissões**: Acesso de administrador para executar comandos que manipulam certificados e interagem com o MongoDB.

## Configuração

Antes de executar os scripts, certifique-se de que os seguintes pré-requisitos estão atendidos:

1. **API do Cloudflare**: Tenha suas credenciais do Cloudflare disponíveis em um arquivo `.ini` que será usado pelo Certbot.
2. **Permissões**: Assegure-se de que o usuário executando os scripts tenha permissões para criar e modificar diretórios e arquivos necessários.
3. **Executar Permissões**: Garanta que os scripts tenham permissões de execução:

   ```bash
   chmod +x generate_certificates.sh manage_certificates.sh

## Uso

**`generate_certificates.sh`**

Este script é o ponto de entrada principal. Ele executa os seguintes passos:

1. **Registra uma conta no Certbot**: Se uma conta ainda não estiver registrada.

2. **Gera certificados TLS**: Usando o plugin de DNS do Cloudflare para validar o domínio.

3. **Chama o script secundário**: Para manipular os certificados e rotacioná-los no MongoDB.

### Sintaxe
    ```bash
        ./generate_certificates.sh <email> <dns> <member> <path_to_cloudflare_ini>
    ```

- `<email>`: O endereço de e-mail para registro no Certbot.
- `<dns>`: O domínio para o qual o certificado deve ser gerado (use um curinga, se necessário, como *.example.com).
- `<member>`: O membro da conta de serviço do Google Cloud para adicionar a política de IAM.
- `<path_to_cloudflare_ini>`: Caminho para o arquivo de credenciais do Cloudflare.

---
**`manage_certificates.sh`**

Este script secundário é chamado pelo script principal para manipular e rotacionar os certificados no MongoDB.

### Sintaxe

***Este script não deve ser chamado diretamente, pois depende de variáveis e arquivos configurados pelo script principal.***


## Detalhes Técnicos

1. **Certificados**: Os certificados são gerados em `/etc/letsencrypt/live/<domain>/`

2. **Manipulação de Certificados**: Os certificados e chaves privadas são concatenados em `/etc/mongo-tls/gcp/mongodb.pem`.

3. **Permissões de Certificados**: Os arquivos e diretórios gerados são atribuídos ao usuário e grupo mongod com permissões restritas.

4. **Rotação de Certificados no MongoDB**: Executa `db.runCommand({rotateCertificates: 1})` usando mongosh.

## Considerações de Segurança

1. **Credenciais Sensíveis**: Mantenha o arquivo .ini do Cloudflare seguro e restrinja o acesso.

2. **Auditoria**: Verifique regularmente os logs e o comportamento do MongoDB para garantir que a rotação de certificados ocorra conforme esperado.
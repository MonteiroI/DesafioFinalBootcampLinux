# Projeto de conclusão do bootcamp Linux Experience da DIO realizado por Igor O. Monteiro baseado no roteiro
# apresentado pelo Professor Denilson Bonatti.
#
# Descrição: neste projeto segui o roteiro do Prof. Denilson Bonatti no curso Linux Experience para implementação
# de um cluster de servidores para um banco de dados mysql. Uma diferença em minha implementação, quando comparada a
# do Professor Denilson, é que implementei em duas máquinas virtuais na minha máquina pessoal em vez de implementar
# na cloud AWS como fez o Denilson. A razão para isto é que não me senti seguro de criar uma conta na AWS com meu
# cartão de crédito sem ter um conhecimento mais aprofundado deste serviço. Mas por um lado foi bom porque, desta forma,
# meu projeto foi ligeiramente diferente daquele que o Denilson apresentou. Como não tenho um IP universal (como no caso
# das máquinas da AWS) não foi possível realizar o teste de stress sobre o servidor. Mas os outros testes foram todos realizados
# sendo o teste de stress algo simples após o cluster estar rodando.

# Começamos instalando o docker em servidor1 e servidor2 (os servidores são servidores ubuntu 22.04 rodando Oracle VM virtual box)
apt update -y
apt upgrade -y
apt install ca-certificates curl gnupg lsb-release -y
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update -y
apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

# Agora será inicializadoo container apache/php para receber os acessos externos e incluir dados no banco de dados comforme o código disponibilizado
# pelo Prof. Denilson.
docker run --name web-server -dt -p 80:80 --mount type=volume,src=app,dst=/app/ webdevops/php-apache:alpine-php7

# Inicialização do container do servidor mysql
docker run -e MYSQL_ROOT_PASSWORD=senha123 -e MYSQL_DATABASE=mydb --name mymysql -d -p 3306:3306 --mount type=volume,src=data,dst=/var/lib/mysql/ mysql:5.7

# Instalação do cliente mysql para acesso ao banco de dados no container
sudo apt install mysql-client

## Para logar no mysql, usar mysql -u root -p -P3306 -h127.0.0.1

##Criando o banco de dados
##create mydb;
##use mydb;
##create table dados(AlunoID int, Nome varchar(50), Sobrenome varchar(100), Endereco varchar(100), Cidade varchar(50), Host varchar(50));
##
## Inserir código PHP fornecido pelo Denilson Bonatti na pasta /var/lib/docker/volumes/app/_data/
## Neste ponto é possível acessar o servidor apache2 e a cada acesso é inserido uma linha nova de dados randômicos na tabela dados do banco de dados conforme o código em PHP do Denilson Bonatti.
## O próximo passo é matar o container do web-server para gerar um novo cluster web-server. Para isto usar docker rm --force web-server

## Vamos começar agora o cluster de containers
## Na máquina manager, inicializar o docker swarm
docker swarm init
## Nas máquinas workers (no meu caso 1 só) usar o comando de saida do docker swarm (com o docker instalado na máquina virtual worker tambem)
docker swarm join --token SWMTKN-1-4wrcf8l7a8jjgt055jt2zlitm5s2aa8p388re38ydml2agsiws-avrbakhaxomtctiyt4cwknb5d 192.168.1.239:2377

## Agora reinicializar o web-server alpine/php no cluste de containers. No meu caso foram 5 réplicas em duas máquinas virtuais (1 manager+1 worker)
docker service create --name web-server --replicas 5 -dt -p 80:80 --mount type=volume,src=app,dst=/app/ webdevops/php-apache:alpine-php7
## Verificar se todos os containers estão ativos
docker service ps web-server
## Configurar o NFS para espelhar a pasta /var/lib/docker/volumes/app/_data para o nó worker. 
sudo apt install nfs-server #Na máquina manager
sudo apt install nfs-common #Nas máquinas worker
##Editar o arquivo /etc/exports acrescentado a seguinte linha no fim
## /var/lib/docker/volumes/app/_data *(rw,sync,subtree_check)
## Agora compartilhar a pasta /var/lib/docker/volumes/app/_data
exportfs -ar ##Exporta a pasta acima para os outros servidores
showmount -e ##Mostra o que está compartilhado no servidor1
## O próximo passo é montar a pasta /var/lib/docker/volumes/app/_data no nó worker
mount -o v3 192.168.1.239:/var/lib/docker/volumes/app/_data /var/lib/docker/volumes/app/_data  #monta a pasta de dados no servidor2
## Vamos configurar agora o nginx para distribuir os acessos
# No servidor1 criar a pasta proxy
mkdir /proxy
cd /proxy
vim nginx.conf #Criando a configuração do proxy
## Inserir no nginx.conf
#http {
#
#    upstream all {
#        server 192.168.1.239:80;
#        server 192.168.1.191:80;
#    }
#
#    server {
#         listen 4500;
#         location / {
#              proxy_pass http://all/;
#         }
#    }
#
#}
#
#
#events { }

vim dockerfile
## Inserir no dockerfile
##FROM nginx
##COPY nginx.conf /etc/nginx/nginx.conf
## Baixar a imagem
docker build -t proxy-app .
## Inicializar o container
docker container run --name my-proxy-app -dti -p 4500:4500 proxy-app #subindo o container
## Fim. Agora os acessos ao servidor são distribuidos pelos 5 containers ativos. Testei o cluster acessando o servidor das máquinas da
## minha casa e a cada acesso uma nova linha é inserida na tabela dados do banco de dados mysql que chamei de mydb

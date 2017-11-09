#!/bin/bash
# ----------------------------------------------------------------------------------------
#
# deploy.sh - Geração de pacotes de deploy
#
# Autor		: Wellington F. Silva (wsilva@usp.br)
# Contribuições de rrosa@sciere.com.br e mzuliani@sciere.com.br
#
# out/2011
#
# ----------------------------------------------------------------------------------------
# 
# Este script recebe como parâmetros o SHA1 de um commit e o diretório onde vai
# gerar o pacote compactado
#
#
# Requisito:
# o script deploy.sh deve estar na pasta raiz do projeto
#
# ----------------------------------------------------------------------------------------
#
# Histórico:
# 
# Versão 1.0	2011-10-13	Wellington Silva
#	- Versão inicial que lê parâmetros e gera o pacote no diretório informado
# Versão 1.1	2011-10-14	Wellington Silva
#	- Melhorada mensagem de confirmação
#	- Alterados os nomes dos arquivos gerados
# Versão 1.2	2011-10-27	Wellington Silva
#	- Melhorada mensagem de confirmação
#	- Alterados os nomes dos arquivos gerados
#	- Correção de bug ao gerar pacote informando um path com e sem barra no final do path
#	- Correção da quebra de linha no arquivo com a linha de remoção de arquivos
#	- Gerando template de readme e passos de backend
#	- Agrupando em um pacote único
# Versão 2.0    2012-05-02  Wellington Silva
#   - Maior interatividade
#   - Possível selecionar arquivos de instruções para adicionar ao pacote
#   - Guardando os SHA1 utilizados para montagem do pacote
#   - Possibilidade de usar 2 sha1 (inicial e final)
#   - Possibilidade de montar o pacote em apenas uma linha passando os parâmetros
#   - A ordem dos parâmetros informados não importa
#   - Gera script para backup dos arquivos a serem alterados
#   - Melhoria nos textos da tela e do arquivo README gerado automaticamente
# Versão 3.0    2012-07-20  Wellington Silva
#   - Maior interatividade
#   - Possível escolher um label para o arquivo gerado pelo pacote
#   - Bugs ao gerar pacotes com sha1 inicial e final iguais corrigido
#   - Bugs ao gerar pacotes sem o path para gravação corrigido
#   - Melhoria nos textos da tela e do arquivo README gerado automaticamente
#   - Adicionando mensagem dos commits envolvidos ao arquivo README
#   - Adicionado algumas cores para destacar algumas mensagens ----------------------------------------------------------------------------------------
MENSAGEM_USO="
Uso: $(basename "$0") [Opções] ou [parâmetros]

Parâmetros:
    -p ou --path /caminho/onde/sera/gerado  
        onde será gerado o pacote
    -si ou --sha1-ini sha1sha1sha1sha1sha1sha1sha1
        sha1 para adicionar somente os arquivos que foram alterados desde o sha1 informado
    -sf ou --sha1-fin sha1sha1sha1sha1sha1sha1sha1
        sha1 para adicionar somente os arquivos que foram alterados até o sha1 informado
    -d ou --db /caminho/para/o/arquivo.sql
        para adicionar arquivo sql com as alterações de banco que serão executadas
    -b ou --backend /caminho/para/o/backend.txt
        para adicionar arquivo com as instruções de retaguarda que serão executadas
    -c ou --config /caminho/para/o/configuration.txt
        para adicionar arquivo com as instruções de alteração em arquivos de configuração
    
    *Pelo menos um parâmetro deve ser informado

Opções:
	-h, --help		Mostra esta tela de ajuda e sai.
	-v, --version	Mostra a versão do programa e sai.
	
Exemplos de uso:
	completo: ./deploy.sh --path /home/usuario/Desktop --sha1-ini {sha1 inicial} --sha1-fin {sha1 final} --backend /caminho/para/o/backend.txt --db /caminho/para/o/arquivo.sql --config /caminho/para/o/configuration.txt
	curto:  ./deploy.sh -p /home/usuario/Desktop -si {sha1 inicial} -sf {sha1 final} -b /caminho/para/o/backend.txt -d /caminho/para/o/arquivo.sql -c /caminho/para/o/configuration.txt
	versão: ./deploy.sh -v ou ./deploy.sh --version
	ajuda: ./deploy.sh -h ou ./deploy.sh --help
"
# testando se não foram passados parametros
if test -z "$1"
then
    clear
	echo "--------------------------------------------------------------------------------"
	echo -e "\033[91m Atenção. Nenhum parâmetro informado.\033[0m"
	echo "	Execute " 
	echo "	$0 --help"
	echo "	ou "
	echo "	$0 -h"
	echo "	para ver as opções disponíveis."
	echo "--------------------------------------------------------------------------------"
	exit 0

elif [ "$1" == "-v" ]  || [ "$1" == "--version" ]
then  
    clear
	# Extrai a versão do próprio cabeçalho
	VERSAO=`grep '^# Vers' "$0" |tail -1 |cut -f 1 |tr -d \#`
	echo "--------------------------------------------------------------------------------"		
	echo "$(basename $0) ($VERSAO )"
	echo "--------------------------------------------------------------------------------"
	exit 0
elif [ "$1" == "-h" ]  || [ "$1" == "--help" ]
then  
    clear
	echo "--------------------------------------------------------------------------------"
	echo "$MENSAGEM_USO"
	echo "--------------------------------------------------------------------------------"
	exit 0
else

    # inicializando variavel para as mensagens de commit
    MSGSCOMMITS=""

    # pegando os parametros passados
    while test "$1"
    do
        # testando o parametro
        case "$1" in
        
            # label para o pacote
            -l | --label)
                
                shift
                
                # pega o label
	            LABEL=$1
            ;;
            
            # path onde vai salvar
            -p | --path)
                
                shift
                
                # pega o dir informado
	            DIR=$1

	            # verificando se o ultimo char do path é uma barra "/"
	            LASTPOS=`expr length $DIR`
	            LASTCHAR=$(echo "$DIR" | cut -c$LASTPOS)

	            if [ $LASTCHAR == '/' ]; then
	                # removendo último caractere
	                DIR=$(echo $DIR | sed 's/.$//')
	            fi
	
	            # verificando existencia do diretório
	            if [ ! -d $DIR ]; then
                    echo "Diretório $DIR não existe "
                    exit 0
                fi
            ;;
            
            # sha1 / commits
            -si | --sha1-ini)
                shift
        
                # pega o dir informado
	            SHA1INI=$1
            ;;
            
            # sha1 / commits
            -sf | --sha1-fin)
                shift
        
                # pega o dir informado
	            SHA1FIN=$1
            ;;
            
            # arquivo com alterações de banco
            -d | --db)
                shift
                SQLFILE=$1
            ;;
            
            # arquivo com passos de backend
            -b | --backend)
                shift
                BACKENDFILE=$1            
            ;;
            
            # arquivo com as alterações de parâmetros de configuração
            -c | --config)
                shift
                CONFIGFILE=$1
            ;;
            
            # parametro desconhecido
            *)
                echo "Parâmetro desconhecido: 
$1"
                exit 0
            ;;
        esac
        shift
    done
    
    # testando se não foi passado sha1 final...
    if test -z "$SHA1FIN"
    then
        
        # ...pegamos o ultimo commit local
        SHA1FIN=`git log |grep commit |head -n 1| cut -b 8-`
    fi
	

	# data agora
	AGORA=`date +%Y-%m-%d_%H_%M`
	
	
    # se o diretório não foi informado tentamos pegá-lo
	if test -z "$DIR"
    then
        clear
	    echo "--------------------------------------------------------------------------------"
	    echo -e "Informe o\033[93m caminho para o arquivo\033[0m que será gerado (ex.: /tmp/):"
	    echo "--------------------------------------------------------------------------------"
	    read DIR
	    echo " "
	    echo "--------------------------------------------------------------------------------"
	    # verificando se o ultimo char do path é uma barra "/"
        LASTPOS=`expr length $DIR`
        LASTCHAR=$(echo "$DIR" | cut -c$LASTPOS)

        if [ $LASTCHAR == '/' ]; then
            # removendo último caractere
            DIR=$(echo $DIR | sed 's/.$//')
        fi
        
        # se o diretório ainda não exite encerramos
        if test -z "$DIR"
        then
            clear
            echo "--------------------------------------------------------------------------------"
            echo "Nenhum diretório informado"
            echo " "
            echo "Encerrando prematuramente a geração do pacote."
	        echo "--------------------------------------------------------------------------------"
            exit 0
        fi

        # verificando novamente a existencia do diretório
        if [ ! -d $DIR ]; then
            clear
	        echo "--------------------------------------------------------------------------------"
            echo -e "Diretório\033[93m \"$DIR\"\033[0m informado não existe."
            echo " "
            echo "Encerrando prematuramente a geração do pacote."
	        echo "--------------------------------------------------------------------------------"
            exit 0
        fi
    fi
    
    
	# se o sha1 não foi informado tentamos pegá-lo
	if test -z "$SHA1INI"
    then
        clear
	    echo "--------------------------------------------------------------------------------"
	    echo -e "Informe o\033[93m SHA1\033[0m do commit do\033[93m último pacote\033[0m gerado anteriormente:"
	    echo "--------------------------------------------------------------------------------"
	    read SHA1INI
	    echo " "
	    echo "--------------------------------------------------------------------------------"
	
    fi
    
    # se ainda não temos o sha1 inicial não dá pra gerar pacote
    if test -z "$SHA1INI"
    then
        clear
	    echo "--------------------------------------------------------------------------------"
        echo "SHA1 inicial não informado, impossível gerar pacote sem informar desde que ponto deve ser gerado."
        echo " "
        echo "Encerrando prematuramente a geração do pacote."
	    echo "--------------------------------------------------------------------------------"
        exit 0
    fi
    
    # se os SHA1s forem iguais não teremos diferenças
    if [ "$SHA1INI" == "$SHA1FIN" ]
    then
        clear
	    echo "------------------------------------------------------------------------------------------"
        echo "SHA1 inicial e final são iguais portanto não há diferenças entre os commits. Impossível gerar pacote vazio."
        echo " "
        echo "Encerrando prematuramente a geração do pacote."
	    echo "--------------------------------------------------------------------------------"
        exit 0
    fi
    
    # pegando os SHA1 curtos
    SHA1INICURTO=`echo "$SHA1INI" | cut -c 1-7`
    SHA1FINCURTO=`echo "$SHA1FIN" | cut -c 1-7`
    
    # pegando as mensagens desses commits
    rm $DIR/msgcommits.txt && touch $DIR/msgcommits.txt
    git log --oneline $SHA1FINCURTO | while read linha
    do
        SHA1CURTO=`echo $linha | cut -c 1-7`
        MSG=`echo $linha | cut -c 9-`
        echo " - $MSG" >> $DIR/msgcommits.txt        
        if [ "$SHA1CURTO" == "$SHA1INICURTO" ]; then
            exit 0
        fi
    done    
    
    # arquivo sql
    if test -z "$SQLFILE"
    then
        clear
        echo "--------------------------------------------------------------------------------"
        echo -e "Se existir um arquivo com o\033[93m script SQL\033[0m a ser executado no servidor de banco de dados informe o path para este arquivo ser adicionado ou deixe em branco para nenhum:"
        echo "--------------------------------------------------------------------------------"
        read SQLFILE
    fi
    
    
    # arquivo backend
    if test -z "$BACKENDFILE"
    then
        clear
        echo "--------------------------------------------------------------------------------"
        echo -e "Se existir um arquivo com\033[93m instruções de backend\033[0m  informe o path para este arquivo ser adicionado ou deixe em branco para nenhum:"
        echo "--------------------------------------------------------------------------------"
        read BACKENDFILE
    fi
    
    # arquivo de configuração
    if test -z "$CONFIGFILE"
    then
        clear
        echo "--------------------------------------------------------------------------------"
        echo -e "Se existir um arquivo com\033[93m  instruções para alterar arquivos de configuração\033[0m  tais como application.ini, configuration.php, config.ini, informe o path para este arquivo ser adicionado ou deixe em branco para nenhum:"
        echo "--------------------------------------------------------------------------------"
        read CONFIGFILE
    fi
    
    # label se não informado
    if test -z "$LABEL"
    then
        clear
        echo "--------------------------------------------------------------------------------"
        echo -e "Se deseja\033[93m informar um rótulo (label)\033[0m  para o pacote informe:"
        echo "--------------------------------------------------------------------------------"
        read LABEL        
    fi
          
    clear
    echo "--------------------------------------------------------------------------------"
	echo -e "\033[93m Commit inicial informado:\033[0m $SHA1INI
\033[93m Commit final:\033[0m $SHA1FIN
Será criado um pacote em\033[93m $DIR/deploy-$LABEL-$AGORA.tar.gz\033[0m com:

1) um pacote\033[93m $AGORA.fontes.tar.gz\033[0m com o\033[91m ESTADO ATUAL\033[0m dos arquivos alterados entre os commits informados ou alterados desde o commit informado;
2) um arquivo\033[93m $AGORA.para.remover.sh\033[0m que apaga os arquivos removidos entre os commits informados ou removidos desde o commit informado;
3) um arquivo\033[93m $AGORA.para.backup.sh\033[0m que gera um arquivo de backup de fontes na raiz do site com o nome {data e hora do servidor}_bkp.tar.gz somente com os arquivos alterados ou removidos entre os commits informados;
4) um arquivo\033[93m README\033[0m com um template de instruções de aplicação."
    echo "--------------------------------------------------------------------------------"

    # testando existência de arquivo sql
    if test -z $SQLFILE
    then
        echo "Nenhum arquivo sql será adicionado."
    else
        if test -f $SQLFILE 
        then
            echo "O arquivo\033[93m $SQLFILE\033[0m com as alterações de banco de dados também será adicionado ao pacote."
        else
            echo "Nenhum arquivo sql será adicionado. O path informado ($SQLFILE) é inválido." 
        fi
    fi
    
    # testando a existência do arquivo backend
    if test -z $BACKENDFILE
    then
        echo "Nenhum arquivo com instruções de backend será adicionado."
    else
        if test -f $BACKENDFILE 
        then
            echo "O arquivo\033[93m $BACKENDFILE\033[0m  com instruções de backend também será adicionado ao pacote."
        else
            echo "Nenhum arquivo com instruções de backend será adicionado. O path informado ($BACKENDFILE) é inválido."
        fi
    fi
    
    # testando a existência do arquivo config
    if test -z $CONFIGFILE
    then
        echo "Nenhum arquivo com instruções para arquivos de configuração será adicionado."
    else
        if test -f $CONFIGFILE
        then
            echo "O arquivo\033[93m $CONFIGFILE\033[0m  com instruções para arquivos de configuração também será adicionado ao pacote."
        else
            echo "Nenhum arquivo com instruções para arquivos de configuração será adicionado. O path informado ($CONFIGFILE) é inválido."
        fi
    fi

    echo "--------------------------------------------------------------------------------"
	echo "
Deseja continuar? (s/n)"
	read CONTINUAR

	# se não informar sim paramos execução
	if [ "$CONTINUAR" == "n" ] || [ "$CONTINUAR" == "N" ]; then
	    echo "Selecionada opção NÃO. Criação do pacote cancelada."
	    exit 0
	elif [ "$CONTINUAR" == "s" ] || [ "$CONTINUAR" == "S" ]; then

		# criando arquivo README
		clear
		echo "--------------------------------------------------------------------------------"
		echo "Criando arquivo README"
		MSGSCOMMITS=`cat $DIR/msgcommits.txt`
		echo "--------------------------------------------------------------------------------
Pacote Gerado através dos commits abaixo
inicial: $SHA1INI
final: $SHA1FIN

--------------------------------------------------------------------------------
Alterações:
$MSGSCOMMITS

--------------------------------------------------------------------------------
PASSO 1: 
No servidor WEB, na raiz do site executar o arquivo $AGORA.para.backup.sh com o comando ./$AGORA.para.backup.sh para gerar um arquivo de backup também na raiz do site com o nome {data e hora do servidor}_bkp.tar.gz  com os arquivos que serão sobreescritos durante o release.

PASSO 2:
No sevidor de banco de dados efetuar um backup das bases de dados utilizadas.

PASSO 3:
De volta no servidor WEB, na raiz do site executar o arquivo $AGORA.para.remover.sh com o comando ./$AGORA.para.remover.sh para apagar os arquivos removidos durante o desenvolvimento.

PASSO 4:
Descompactar o arquivo $AGORA.fontes.tar.gz na raiz do site sobreescrevendo os arquivos antigos." > $DIR/README

        # iniciando o contador de passos
        PASSOCOUNTER=5
        
        # testando existência de arquivo sql e colocando a instrução no arquivo readme
        if test -z $SQLFILE
        then
            echo "Nenhum arquivo sql será adicionado."
        else
            if test -f $SQLFILE 
            then
                echo "
PASSO $PASSOCOUNTER:  
No servidor de banco de dados executar o script script_alteracoes.sql com o comando mysql -u {usuario com acesso ao Banco de dados} -p {nome do banco de dados no servidor} < script_alteracoes.sql" >> $DIR/README
                PASSOCOUNTER=$((PASSOCOUNTER+1))
                echo "Copiando $SQLFILE"
                cp $SQLFILE $DIR/script_alteracoes.sql
            else
                echo "Nenhum arquivo sql será adicionado. O path informado ($SQLFILE) é inválido." 
            fi
        fi
        
        # testando a existência do arquivo backend e colocando a instrução no arquivo readme
        if test -z $BACKENDFILE
        then
            echo "Nenhum arquivo com instruções de backend será adicionado."
        else
            if test -f $BACKENDFILE 
            then
                echo "
PASSO $PASSOCOUNTER:  
No servidor web acesse a área administrativa e siga os passos conforme descrito no arquivo IntrucoesDeBackend.txt" >> $DIR/README
                PASSOCOUNTER=$((PASSOCOUNTER+1))
                echo "Copiando $BACKENDFILE"
        		cp $BACKENDFILE $DIR/IntrucoesDeBackend.txt
            else
                echo "Nenhum arquivo com instruções de backend será adicionado. O path informado ($BACKENDFILE) é inválido." 
            fi
        fi
        
        
        # testando a existência do arquivo config e colocando a instrução no arquivo readme
        if test -z $CONFIGFILE
        then
            echo "Nenhum arquivo com instruções para arquivos de configuração será adicionado."
        else
            if test -f $CONFIGFILE
            then
                echo "
PASSO $PASSOCOUNTER:  
No servidor web alterar os arquivos de configuração conforme descrito em InstrucoesDeConfiguracao.txt" >> $DIR/README
                PASSOCOUNTER=$((PASSOCOUNTER+1))
                echo "Copiando $CONFIGFILE"
                cp $CONFIGFILE $DIR/InstrucoesDeConfiguracao.txt
            else
                echo "Nenhum arquivo com instruções para arquivos de configuração será adicionado. O path informado ($CONFIGFILE) é inválido."
            fi
        fi

		# criando arquivo para guardar os bkps
		echo "Criando script para geração de backup";
		touch $DIR/para_bkp.txt

		# pegando arquivos do git para remover
		git diff --name-status $SHA1INI $SHA1FIN |cut -b 3- | sed 's/ /\\ /g' | sed 's/(/\(/g' | sed 's/)/\)/g' |xargs -0 echo >> $DIR/para_bkp.txt

		#gerando o arquivo com o comando de remoção
		echo "tar czf \`date +%Y-%m-%d_%H_%M\`_bkp.tar.gz " `cat $DIR/para_bkp.txt` > $DIR/$AGORA.para.backup.sh

		#removendo arquivo temporário
		rm $DIR/para_bkp.txt
		

		# criando arquivo para guardar as remoções
        echo "Criando script de remoção de arquivos removidos do projeto";
		touch $DIR/para_remover.txt

		# pegando arquivos do git para remover
		git diff --name-status $SHA1INI $SHA1FIN |grep -e "^D" |cut -b 3- | sed 's/ /\\ /g' | sed 's/(/\(/g' | sed 's/)/\)/g' |xargs -0 echo >> $DIR/para_remover.txt

		#gerando o arquivo com o comando de remoção
		echo "rm -rf " `cat $DIR/para_remover.txt` > $DIR/$AGORA.para.remover.sh

		#removendo arquivo temporário
		rm $DIR/para_remover.txt

		# pegando arquivos do git para o pacote
        echo "Criando pacote com os fontes alterados";
		git diff --name-status $SHA1INI $SHA1FIN |grep -e "^[^D]" |cut -b 3- | sed 's/ /\\ /g' | sed 's/(/\(/g' | sed 's/)/\)/g' |xargs tar cvfz $DIR/$AGORA.fontes.tar.gz

		# pegando caminho atual
		CAMINHOATUAL=`pwd`
		
		# indo para o path dos arquivos e compactando num pacote só e voltando ao dir atual
        echo "Criando pacote final";
		cd $DIR
		chmod a+x $AGORA.para.remover.sh $AGORA.para.backup.sh
		tar cvf deploy-$LABEL-$AGORA.tar $AGORA.para.remover.sh $AGORA.para.backup.sh $AGORA.fontes.tar.gz README
		rm $DIR/$AGORA.para.remover.sh
		rm $DIR/$AGORA.para.backup.sh
		rm $DIR/$AGORA.fontes.tar.gz
		rm $DIR/README
		rm $DIR/msgcommits.txt
		
		# adicionando os arquivos de conf banco e backend caso existam
		if test -z $SQLFILE
        then
            echo "-"
        else
            if test -f $SQLFILE 
            then
                tar rvf deploy-$LABEL-$AGORA.tar script_alteracoes.sql
                rm $DIR/script_alteracoes.sql
            fi
        fi
        
        if test -z $BACKENDFILE
        then
            echo "-"
        else
            if test -f $BACKENDFILE 
            then
                tar rvf deploy-$LABEL-$AGORA.tar IntrucoesDeBackend.txt
                rm $DIR/IntrucoesDeBackend.txt
            fi
        fi
        
        if test -z $CONFIGFILE
        then
            echo "-"
        else
            if test -f $CONFIGFILE
            then
                tar rvf deploy-$LABEL-$AGORA.tar InstrucoesDeConfiguracao.txt
                rm $DIR/InstrucoesDeConfiguracao.txt
            fi
        fi
        
        # compactando
        gzip deploy-$LABEL-$AGORA.tar
		
		# voltando ao path original
		cd $CAMINHOATUAL

    # nem sim nem não foi selecionado
	else
	    echo "Opção inválida, execução encerrada."
	    exit 0
	fi
fi

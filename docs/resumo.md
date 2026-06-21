# Benchmark de armazenamento sem criptografia, LUKS, VeraCrypt e gocryptfs

## Objetivo

O objetivo do trabalho e comparar o desempenho de leitura e escrita em quatro cenarios de armazenamento: um container ext4 sem criptografia, um volume LUKS, um volume VeraCrypt e um diretorio criptografado com gocryptfs. A comparacao busca evidenciar o impacto da criptografia no tempo de acesso, na vazao e no uso de CPU em niveis diferentes: sem criptografia, volume/disco e diretorio.

## Metodo utilizado

A execucao principal e feita por um script `.sh`, que usa `dd` com I/O direto para gravar e ler arquivos reais nos caminhos configurados. Os containers sem criptografia, LUKS e VeraCrypt, alem do diretorio gocryptfs, devem estar previamente montados no sistema operacional. O benchmark nao simula a criptografia internamente: ele mede o comportamento observado ao acessar os pontos de montagem reais.

Para cada cenario, o programa executa uma rodada de aquecimento e depois repeticoes de escrita e leitura de um arquivo com tamanho configuravel. Durante cada operacao sao medidos a duracao real da operacao, a vazao calculada pelos bytes processados e a CPU do sistema durante a operacao, separada entre user space e kernel space. Tambem sao registrados os tempos de CPU user/kernel do processo `dd`. Para comparar CPU entre cenarios, os graficos usam CPU-segundos por GiB, evitando distorcoes causadas por operacoes que terminam mais rapido. Os resultados sao salvos em CSV. Em seguida, Python usa matplotlib para gerar graficos comparando tempo, vazao e custo de CPU com barras de erro baseadas no desvio padrao.

Antes da medicao, todos os cenarios sao validados. Caso algum ponto de montagem esteja ausente, sem permissao de escrita ou nao aceite leitura/escrita com I/O direto, o benchmark e interrompido e o erro e registrado separadamente. Essa decisao evita desbalancear a comparacao com cenarios ausentes, modo de E/S diferente ou quantidade diferente de amostras.

## Metricas adotadas

As metricas usadas foram tempo real de escrita, tempo real de leitura, vazao em MB/s, CPU-segundos do sistema em user space e kernel space, CPU-segundos por GiB, CPU do processo `dd`, tamanho processado, modo de E/S e cenario avaliado. Para cada metrica, o resumo estatistico registra media, mediana, desvio padrao, minimo, maximo e numero de amostras por cenario e operacao.

## Principais resultados esperados

Espera-se que o container sem criptografia apresente menor tempo e maior vazao, pois nao ha custo de cifragem no caminho de E/S. Nos volumes LUKS e VeraCrypt e no diretorio gocryptfs, a criptografia tende a aumentar o uso de CPU e reduzir a vazao, principalmente em arquivos maiores ou em sistemas sem aceleracao eficiente para AES. A comparacao final deve ser feita com base no CSV e nos graficos gerados na maquina usada pela equipe.

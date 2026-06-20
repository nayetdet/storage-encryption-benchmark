# Benchmark de armazenamento sem criptografia, LUKS e VeraCrypt

## Objetivo

O objetivo do trabalho e comparar o desempenho de leitura e escrita em tres cenarios de armazenamento: um container ext4 sem criptografia, um volume LUKS e um volume VeraCrypt. A comparacao busca evidenciar o impacto da criptografia no tempo de acesso, na vazao e no uso de CPU.

## Metodo utilizado

A execucao principal e feita por um script `.sh`, que usa `dd` com I/O direto para gravar e ler arquivos reais nos caminhos configurados. Os containers sem criptografia, LUKS e VeraCrypt devem estar previamente montados no sistema operacional. O benchmark nao simula a criptografia internamente: ele mede o comportamento observado ao acessar os pontos de montagem reais.

Para cada cenario, o programa executa repeticoes de escrita e leitura de um arquivo com tamanho configuravel. Durante cada operacao sao medidos o tempo real de parede, a vazao calculada pelos bytes processados e a CPU total do sistema durante a operacao. Para comparar CPU entre cenarios, o grafico usa CPU-segundos por GiB, evitando distorcoes causadas por operacoes que terminam mais rapido. Os resultados sao salvos em CSV. Em seguida, Python usa matplotlib para gerar graficos comparando tempo, vazao e custo de CPU.

## Metricas adotadas

As metricas usadas foram tempo real de escrita, tempo real de leitura, vazao em MB/s, CPU-segundos do sistema, CPU-segundos por GiB, tamanho processado, modo de E/S e cenario avaliado.

## Principais resultados esperados

Espera-se que o container sem criptografia apresente menor tempo e maior vazao, pois nao ha custo de cifragem no caminho de E/S. Nos volumes LUKS e VeraCrypt, a criptografia tende a aumentar o uso de CPU e reduzir a vazao, principalmente em arquivos maiores ou em sistemas sem aceleracao eficiente para AES. A comparacao final deve ser feita com base no CSV e nos graficos gerados na maquina usada pela equipe.

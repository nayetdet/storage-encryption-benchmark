# Trabalho 3 - Sistemas Operacionais

Tema: Benchmark de desempenho comparando armazenamento sem criptografia, LUKS, VeraCrypt e criptografia de diretório com gocryptfs.

O projeto mede operações reais de leitura e escrita em quatro caminhos:

1. Um container ext4 comum, sem criptografia.
2. Um ponto de montagem LUKS.
3. Um ponto de montagem VeraCrypt.
4. Um diretório criptografado com gocryptfs.

O `setup.sh` cria e monta os containers e o diretório criptografado. O `benchmark.sh` mede tempo, vazão e uso de CPU ao escrever e ler arquivos reais nesses caminhos.

## Estrutura

- `scripts/setup.sh`: cria, abre e monta os containers sem criptografia, LUKS, VeraCrypt e gocryptfs.
- `scripts/benchmark.sh`: orquestra o benchmark, salva CSV e chama a geração de gráficos.
- `scripts/medir_io.py`: mede escrita/leitura com `dd` em I/O direto.
- `scripts/gerar_graficos.py`: gera os gráficos a partir do CSV.
- `scripts/down.sh`: desmonta e fecha os containers.
- `requirements.txt`: dependência Python para gerar os gráficos.
- `exemplos/config_exemplo.env`: exemplo de configuração dos caminhos.
- `exemplos/resultado_exemplo.csv`: exemplo do formato de saída.
- `docs/resumo.md`: resumo de até uma página.
- `docs/validacao_entrega.md`: checklist de conformidade.
- `docs/roteiro_video_3min.md`: roteiro sugerido para o vídeo.
- `docs/preparar_volumes.md`: orientação para preparar os volumes antes do benchmark.

## Instalar dependências

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Para o cenário de criptografia de diretório, instale também:

```bash
sudo apt install gocryptfs
```

## Executar

Prepare os volumes:

```bash
./scripts/setup.sh
```

Depois rode:

```bash
NORMAL_PATH=/mnt/plain_container \
LUKS_PATH=/mnt/luks_container \
VERACRYPT_PATH="$HOME/veracrypt_container" \
GOCRYPTFS_PATH="$HOME/gocryptfs_plain" \
FILE_SIZE_MB=512 \
ITERATIONS=5 \
./scripts/benchmark.sh
```

O script gera:

- `results/benchmark.csv`
- `results/graficos/tempo_operacao.png`
- `results/graficos/vazao_operacao.png`
- `results/graficos/cpu_operacao.png`, custo de CPU do sistema em CPU-s/GiB.
- `results/graficos/cpu_user_operacao.png`, custo de CPU em user space.
- `results/graficos/cpu_kernel_operacao.png`, custo de CPU em kernel space.
- `results/resumo_estatistico.csv`, média, mediana, desvio padrão, mínimo, máximo e amostras por métrica.
- `results/benchmark_errors.csv`, somente se algum cenário falhar na validação ou execução.

Para desmontar depois:

```bash
./scripts/down.sh
```

## Sobre Docker

Não é recomendado rodar este benchmark dentro de Docker comum. LUKS, VeraCrypt e gocryptfs dependem de montagem de volumes ou diretórios pelo sistema operacional e normalmente exigem recursos do host. Um container Docker teria que rodar com privilégios extras, o que deixa o teste menos portátil e pode distorcer os resultados de E/S. Por isso, o projeto automatiza a criação/montagem dos containers e diretórios no host.

## Métricas

- Tempo de escrita.
- Tempo de leitura.
- Vazão em MB/s.
- Duração real da operação (`wall_seconds`).
- Vazão real calculada por bytes processados / tempo real (`throughput_mb_s`).
- Uso de CPU do sistema durante a operação (`system_cpu_seconds`, `system_cpu_percent`, `system_cpu_seconds_per_gib`).
- Uso de CPU do sistema separado entre user space e kernel space (`system_user_*`, `system_kernel_*`).
- Uso de CPU do processo `dd` separado entre user space e kernel space (`process_user_cpu_seconds`, `process_kernel_cpu_seconds`).
- Estatísticas por cenário e operação: média, mediana, desvio padrão, mínimo, máximo e número de amostras.
- Modo de E/S (`io_mode=direct`).
- Tamanho processado.
- Cenário medido.

Os resultados variam de acordo com hardware, cache do sistema operacional, tamanho do arquivo, número de repetições e configuração dos volumes. O baseline sem criptografia também usa um arquivo-container para reduzir distorções causadas por comparar uma pasta comum com volumes montados.

O benchmark valida todos os cenários antes de iniciar. Se algum caminho não existir, estiver sem permissão de escrita ou não aceitar leitura/escrita com I/O direto, a execução é interrompida e o erro é registrado em `results/benchmark_errors.csv`. Isso evita comparar resultados com cenários ausentes, modo de E/S diferente ou número desigual de amostras.

No cenário gocryptfs, o `setup.sh` monta o diretório com as opções padrão da ferramenta. A comparação continua usando I/O direto porque o `benchmark.sh` testa leitura e escrita com `oflag=direct` e `iflag=direct` antes de iniciar as medições. Se o sistema não aceitar esse modo, o benchmark interrompe a execução em vez de gerar uma comparação inconsistente.

## Como as métricas são medidas

- Escrita real: `dd if=/dev/zero of=arquivo oflag=direct conv=fdatasync`.
- Leitura real: `dd if=arquivo of=/dev/null iflag=direct`.
- Tempo real: o script marca quando o `dd` começa, marca quando termina e calcula a diferença.
- Vazão real: bytes processados divididos pelo tempo real.
- CPU do sistema: diferença de uso da CPU total em `/proc/stat` durante a operação.
- CPU em user space do sistema: campos `user + nice` de `/proc/stat`.
- CPU em kernel space do sistema: campos `system + irq + softirq` de `/proc/stat`.
- CPU do processo: tempos `ru_utime` e `ru_stime` retornados por `wait4` para o processo `dd`.
- Gráfico principal de CPU: usa CPU-s/GiB, pois percentual de CPU sozinho pode enganar quando uma operação termina mais rápido.
- Desvio padrão: calculado entre as repetições de cada par cenário/operação e exibido como barra de erro nos gráficos. Cada barra também mostra o valor da média e do desvio padrão.

Use arquivos maiores, como `FILE_SIZE_MB=512` ou `FILE_SIZE_MB=1024`. O script bloqueia, por padrão, valores menores que 512 MB e menos de 5 repetições, porque execuções muito curtas tendem a gerar CPU e vazão instáveis por causa da resolução da medição e de atividade paralela do sistema.

# Trabalho 3 - Sistemas Operacionais

Tema: Benchmark de desempenho comparando armazenamento sem criptografia, LUKS e VeraCrypt.

O projeto mede operacoes reais de leitura e escrita em tres caminhos:

1. Um container ext4 comum, sem criptografia.
2. Um ponto de montagem LUKS.
3. Um ponto de montagem VeraCrypt.

O `setup.sh` cria e monta os containers. O `benchmark.sh` mede tempo, vazao e uso de CPU ao escrever e ler arquivos reais nesses caminhos.

## Estrutura

- `scripts/setup.sh`: cria, abre e monta os containers sem criptografia, LUKS e VeraCrypt.
- `scripts/benchmark.sh`: orquestra o benchmark, salva CSV e chama a geracao de graficos.
- `scripts/medir_io.py`: mede escrita/leitura com `dd` em I/O direto.
- `scripts/gerar_graficos.py`: gera os graficos a partir do CSV.
- `scripts/down.sh`: desmonta e fecha os containers.
- `requirements.txt`: dependencia Python para gerar os graficos.
- `exemplos/config_exemplo.env`: exemplo de configuracao dos caminhos.
- `exemplos/resultado_exemplo.csv`: exemplo do formato de saida.
- `docs/resumo.md`: resumo de ate uma pagina.
- `docs/validacao_entrega.md`: checklist de conformidade.
- `docs/roteiro_video_3min.md`: roteiro sugerido para o video.
- `docs/preparar_volumes.md`: orientacao para preparar os volumes antes do benchmark.

## Instalar dependencias

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
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
FILE_SIZE_MB=512 \
ITERATIONS=5 \
./scripts/benchmark.sh
```

O script gera:

- `results/benchmark.csv`
- `results/graficos/tempo_operacao.png`
- `results/graficos/vazao_operacao.png`
- `results/graficos/cpu_operacao.png`, custo de CPU do sistema em CPU-s/GiB.

Para desmontar depois:

```bash
./scripts/down.sh
```

## Sobre Docker

Nao e recomendado rodar este benchmark dentro de Docker comum. LUKS e VeraCrypt dependem de montagem de volumes pelo sistema operacional e normalmente exigem privilegios do host. Um container Docker teria que rodar com `--privileged`, o que deixa o teste menos portavel e pode distorcer os resultados de E/S. Por isso, o projeto automatiza a criacao/montagem dos containers de armazenamento no host.

## Metricas

- Tempo de escrita.
- Tempo de leitura.
- Vazao em MB/s.
- Tempo real de parede (`wall_seconds`).
- Vazao real calculada por bytes processados / tempo real (`throughput_mb_s`).
- Uso de CPU do sistema durante a operacao (`system_cpu_seconds`, `system_cpu_percent`, `system_cpu_seconds_per_gib`).
- Modo de E/S (`io_mode=direct`).
- Tamanho processado.
- Cenario medido.

Os resultados variam de acordo com hardware, cache do sistema operacional, tamanho do arquivo, numero de repeticoes e configuracao dos volumes. O baseline sem criptografia tambem usa um arquivo-container para reduzir distorcoes causadas por comparar uma pasta comum com volumes montados.

## Como as metricas sao medidas

- Escrita real: `dd if=/dev/zero of=arquivo oflag=direct conv=fdatasync`.
- Leitura real: `dd if=arquivo of=/dev/null iflag=direct`.
- Tempo real: medido com relogio de parede em torno do comando `dd`.
- Vazao real: bytes processados divididos pelo tempo real.
- CPU do sistema: diferenca de uso da CPU total em `/proc/stat` durante a operacao.
- Grafico principal de CPU: usa CPU-s/GiB, pois percentual de CPU sozinho pode enganar quando uma operacao termina mais rapido.

Use arquivos maiores, como `FILE_SIZE_MB=512` ou `FILE_SIZE_MB=1024`. Valores pequenos, como 4 MB ou 64 MB, duram pouco e podem gerar CPU instavel por causa da resolucao da medicao e de atividade paralela do sistema.

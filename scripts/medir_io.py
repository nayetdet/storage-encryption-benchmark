import argparse
import csv
import os
import subprocess
import tempfile
import time
from datetime import datetime
from pathlib import Path


CAMPOS_CSV = [
    "timestamp",
    "scenario",
    "target",
    "iteration",
    "operation",
    "io_mode",
    "bytes",
    "wall_seconds",
    "throughput_mb_s",
    "system_cpu_seconds",
    "system_user_cpu_seconds",
    "system_kernel_cpu_seconds",
    "system_cpu_percent",
    "system_user_cpu_percent",
    "system_kernel_cpu_percent",
    "system_cpu_seconds_per_gib",
    "system_user_cpu_seconds_per_gib",
    "system_kernel_cpu_seconds_per_gib",
    "process_user_cpu_seconds",
    "process_kernel_cpu_seconds",
    "process_cpu_seconds",
]


def tempos_cpu_sistema():
    with open("/proc/stat", encoding="utf-8") as arquivo:
        valores = [int(parte) for parte in arquivo.readline().split()[1:]]

    return {
        "user": valores[0],
        "nice": valores[1],
        "system": valores[2],
        "idle": valores[3],
        "iowait": valores[4],
        "irq": valores[5],
        "softirq": valores[6],
        "steal": valores[7] if len(valores) > 7 else 0,
        "total": sum(valores),
    }


def delta_cpu(fim, inicio, campos):
    return sum(fim[campo] - inicio[campo] for campo in campos)


def executar_medido(comando, tamanho_mb, bytes_total):
    sistema_inicio = tempos_cpu_sistema()
    parede_inicio = time.perf_counter()

    with tempfile.TemporaryFile() as erro_arquivo:
        processo = subprocess.Popen(comando, stdout=subprocess.DEVNULL, stderr=erro_arquivo)
        _, status, uso = os.wait4(processo.pid, 0)
        tempo_parede = time.perf_counter() - parede_inicio

        erro_arquivo.seek(0)
        erro_texto = erro_arquivo.read().decode("utf-8", errors="replace").strip()

    sistema_fim = tempos_cpu_sistema()
    codigo_saida = os.waitstatus_to_exitcode(status)

    if codigo_saida != 0:
        comando_texto = " ".join(comando)
        raise RuntimeError(f"Comando falhou ({codigo_saida}): {comando_texto}\n{erro_texto}")

    sistema_total_delta = sistema_fim["total"] - sistema_inicio["total"]
    sistema_idle_delta = delta_cpu(sistema_fim, sistema_inicio, ("idle", "iowait"))
    sistema_user_delta = delta_cpu(sistema_fim, sistema_inicio, ("user", "nice"))
    sistema_kernel_delta = delta_cpu(sistema_fim, sistema_inicio, ("system", "irq", "softirq"))
    sistema_ocupado_delta = sistema_total_delta - sistema_idle_delta

    clock_ticks = os.sysconf(os.sysconf_names["SC_CLK_TCK"])
    cpu_sistema = sistema_ocupado_delta / clock_ticks if clock_ticks > 0 else 0
    cpu_sistema_user = sistema_user_delta / clock_ticks if clock_ticks > 0 else 0
    cpu_sistema_kernel = sistema_kernel_delta / clock_ticks if clock_ticks > 0 else 0
    cpu_sistema_percentual = sistema_ocupado_delta / sistema_total_delta * 100 if sistema_total_delta > 0 else 0
    cpu_sistema_user_percentual = sistema_user_delta / sistema_total_delta * 100 if sistema_total_delta > 0 else 0
    cpu_sistema_kernel_percentual = sistema_kernel_delta / sistema_total_delta * 100 if sistema_total_delta > 0 else 0

    vazao_mb_s = tamanho_mb / tempo_parede if tempo_parede > 0 else 0
    gib = bytes_total / 1024 / 1024 / 1024
    cpu_processo_user = uso.ru_utime
    cpu_processo_kernel = uso.ru_stime

    return {
        "wall_seconds": tempo_parede,
        "throughput_mb_s": vazao_mb_s,
        "system_cpu_seconds": cpu_sistema,
        "system_user_cpu_seconds": cpu_sistema_user,
        "system_kernel_cpu_seconds": cpu_sistema_kernel,
        "system_cpu_percent": cpu_sistema_percentual,
        "system_user_cpu_percent": cpu_sistema_user_percentual,
        "system_kernel_cpu_percent": cpu_sistema_kernel_percentual,
        "system_cpu_seconds_per_gib": cpu_sistema / gib if gib > 0 else 0,
        "system_user_cpu_seconds_per_gib": cpu_sistema_user / gib if gib > 0 else 0,
        "system_kernel_cpu_seconds_per_gib": cpu_sistema_kernel / gib if gib > 0 else 0,
        "process_user_cpu_seconds": cpu_processo_user,
        "process_kernel_cpu_seconds": cpu_processo_kernel,
        "process_cpu_seconds": cpu_processo_user + cpu_processo_kernel,
    }


def adicionar_linha(caminho_saida, linha):
    caminho_saida.parent.mkdir(parents=True, exist_ok=True)
    existe = caminho_saida.exists()

    with caminho_saida.open("a", newline="", encoding="utf-8") as arquivo:
        escritor = csv.DictWriter(arquivo, fieldnames=CAMPOS_CSV)

        if not existe:
            escritor.writeheader()

        escritor.writerow(linha)


def salvar_resultado(args, iteracao, operacao, bytes_total, metricas):
    adicionar_linha(
        args.output,
        {
            "timestamp": datetime.now().isoformat(timespec="seconds"),
            "scenario": args.scenario,
            "target": str(args.target),
            "iteration": iteracao,
            "operation": operacao,
            "io_mode": "direct",
            "bytes": bytes_total,
            "wall_seconds": f"{metricas['wall_seconds']:.6f}",
            "throughput_mb_s": f"{metricas['throughput_mb_s']:.2f}",
            "system_cpu_seconds": f"{metricas['system_cpu_seconds']:.6f}",
            "system_user_cpu_seconds": f"{metricas['system_user_cpu_seconds']:.6f}",
            "system_kernel_cpu_seconds": f"{metricas['system_kernel_cpu_seconds']:.6f}",
            "system_cpu_percent": f"{metricas['system_cpu_percent']:.2f}",
            "system_user_cpu_percent": f"{metricas['system_user_cpu_percent']:.2f}",
            "system_kernel_cpu_percent": f"{metricas['system_kernel_cpu_percent']:.2f}",
            "system_cpu_seconds_per_gib": f"{metricas['system_cpu_seconds_per_gib']:.6f}",
            "system_user_cpu_seconds_per_gib": f"{metricas['system_user_cpu_seconds_per_gib']:.6f}",
            "system_kernel_cpu_seconds_per_gib": f"{metricas['system_kernel_cpu_seconds_per_gib']:.6f}",
            "process_user_cpu_seconds": f"{metricas['process_user_cpu_seconds']:.6f}",
            "process_kernel_cpu_seconds": f"{metricas['process_kernel_cpu_seconds']:.6f}",
            "process_cpu_seconds": f"{metricas['process_cpu_seconds']:.6f}",
        },
    )


def comandos_io(args, caminho_arquivo, blocos):
    comando_escrita = [
        "dd",
        "if=/dev/zero",
        f"of={caminho_arquivo}",
        f"bs={args.block_mb}M",
        f"count={blocos}",
        "oflag=direct",
        "conv=fdatasync",
        "status=none",
    ]
    comando_leitura = [
        "dd",
        f"if={caminho_arquivo}",
        "of=/dev/null",
        f"bs={args.block_mb}M",
        f"count={blocos}",
        "iflag=direct",
        "status=none",
    ]

    return comando_escrita, comando_leitura


def executar_par_io(args, iteracao, blocos, bytes_total, prefixo, registrar):
    caminho_arquivo = args.target / f"{prefixo}_{os.getpid()}_{iteracao}.bin"
    comando_escrita, comando_leitura = comandos_io(args, caminho_arquivo, blocos)

    try:
        if args.pause_seconds > 0:
            time.sleep(args.pause_seconds)

        metricas_escrita = executar_medido(comando_escrita, args.file_size_mb, bytes_total)
        if registrar:
            salvar_resultado(args, iteracao, "write", bytes_total, metricas_escrita)

        if args.pause_seconds > 0:
            time.sleep(args.pause_seconds)

        metricas_leitura = executar_medido(comando_leitura, args.file_size_mb, bytes_total)
        if registrar:
            salvar_resultado(args, iteracao, "read", bytes_total, metricas_leitura)
    finally:
        caminho_arquivo.unlink(missing_ok=True)


def executar_benchmark(args):
    blocos = args.file_size_mb // args.block_mb
    bytes_total = args.file_size_mb * 1024 * 1024

    for aquecimento in range(1, args.warmup_iterations + 1):
        executar_par_io(args, aquecimento, blocos, bytes_total, "benchmark_warmup", registrar=False)

    for iteracao in range(1, args.iterations + 1):
        executar_par_io(args, iteracao, blocos, bytes_total, "benchmark", registrar=True)


def criar_parser():
    parser = argparse.ArgumentParser(description="Mede leitura/escrita real com dd e I/O direto.")
    parser.add_argument("--scenario", required=True)
    parser.add_argument("--target", required=True, type=Path)
    parser.add_argument("--file-size-mb", required=True, type=int)
    parser.add_argument("--iterations", required=True, type=int)
    parser.add_argument("--block-mb", required=True, type=int)
    parser.add_argument("--warmup-iterations", required=True, type=int)
    parser.add_argument("--pause-seconds", required=True, type=float)
    parser.add_argument("--output", required=True, type=Path)
    return parser


def main():
    args = criar_parser().parse_args()
    executar_benchmark(args)


if __name__ == "__main__":
    main()

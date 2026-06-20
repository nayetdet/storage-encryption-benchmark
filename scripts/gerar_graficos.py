import argparse
import csv
import os
import statistics
from collections import defaultdict
from pathlib import Path

os.environ.setdefault("MPLCONFIGDIR", "results/matplotlib-cache")

import matplotlib.pyplot as plt


GRAFICOS = [
    ("wall_seconds", "Tempo médio real por operação", "Segundos", "tempo_operacao.png"),
    ("throughput_mb_s", "Vazão média real por operação", "MB/s", "vazao_operacao.png"),
    ("system_cpu_seconds_per_gib", "Custo médio de CPU do sistema por GiB", "CPU-s/GiB", "cpu_operacao.png"),
    (
        "system_user_cpu_seconds_per_gib",
        "Custo médio de CPU em user space por GiB",
        "CPU-s/GiB",
        "cpu_user_operacao.png",
    ),
    (
        "system_kernel_cpu_seconds_per_gib",
        "Custo médio de CPU em kernel space por GiB",
        "CPU-s/GiB",
        "cpu_kernel_operacao.png",
    ),
]

METRICAS_RESUMO = [
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

OPERACOES = {
    "write": "Escrita",
    "read": "Leitura",
}


def ler_resultados(caminho_csv):
    with caminho_csv.open(newline="", encoding="utf-8") as arquivo:
        return list(csv.DictReader(arquivo))


def listar_cenarios(resultados):
    return list(dict.fromkeys(linha["scenario"] for linha in resultados))


def campo_disponivel(resultados, campo):
    return all(campo in linha and linha[campo] != "" for linha in resultados)


def calcular_estatisticas(resultados, campo):
    valores = defaultdict(list)

    for linha in resultados:
        chave = (linha["scenario"], linha["operation"])
        valores[chave].append(float(linha[campo]))

    estatisticas = {}
    for chave, lista in valores.items():
        estatisticas[chave] = {
            "media": statistics.mean(lista),
            "mediana": statistics.median(lista),
            "desvio_padrao": statistics.stdev(lista) if len(lista) > 1 else 0.0,
            "minimo": min(lista),
            "maximo": max(lista),
            "amostras": len(lista),
        }

    return estatisticas


def formatar_valor(valor):
    valor_absoluto = abs(valor)

    if valor_absoluto >= 100:
        return f"{valor:.0f}"

    if valor_absoluto >= 10:
        return f"{valor:.1f}"

    return f"{valor:.2f}"


def maior_valor_plotado(estatisticas):
    maior = 0

    for dados in estatisticas.values():
        maior = max(maior, dados["media"] + dados["desvio_padrao"])

    return maior


def gerar_grafico(resultados, campo, titulo, eixo_y, caminho_saida):
    cenarios = listar_cenarios(resultados)
    estatisticas = calcular_estatisticas(resultados, campo)
    posicoes = range(len(cenarios))
    largura = 0.36

    figura, eixo = plt.subplots(figsize=(11, 6.2))
    maior_y = maior_valor_plotado(estatisticas)
    margem_rotulo = maior_y * 0.025 if maior_y > 0 else 0.05

    for indice, (operacao, rotulo) in enumerate(OPERACOES.items()):
        deslocamento = (indice - 0.5) * largura
        barras = [posicao + deslocamento for posicao in posicoes]
        alturas = [estatisticas.get((cenario, operacao), {}).get("media", 0) for cenario in cenarios]
        desvios = [estatisticas.get((cenario, operacao), {}).get("desvio_padrao", 0) for cenario in cenarios]
        eixo.bar(barras, alturas, yerr=desvios, capsize=4, width=largura, label=f"{rotulo} (média ± desvio)")

        for posicao_cenario, (barra, media, desvio) in enumerate(zip(barras, alturas, desvios)):
            dados = estatisticas.get((cenarios[posicao_cenario], operacao), {})
            mediana = dados.get("mediana", 0)
            y = media + desvio + margem_rotulo
            rotulo_valor = (
                f"média {formatar_valor(media)}\n"
                f"mediana {formatar_valor(mediana)}\n"
                f"± {formatar_valor(desvio)}"
            )
            eixo.text(barra, y, rotulo_valor, ha="center", va="bottom", fontsize=8)

    eixo.set_title(titulo, pad=18)
    eixo.set_ylabel(eixo_y)
    eixo.set_xticks(list(posicoes))
    eixo.set_xticklabels(cenarios, rotation=15, ha="right")
    eixo.legend()
    eixo.grid(axis="y", linestyle="--", alpha=0.35)
    if maior_y > 0:
        eixo.set_ylim(top=maior_y * 1.28)
    eixo.text(
        0.01,
        0.98,
        "Barras = média; traços pretos = ± desvio padrão; rótulos = média, mediana e desvio",
        transform=eixo.transAxes,
        ha="left",
        va="top",
        fontsize=8.5,
        bbox={"facecolor": "white", "alpha": 0.85, "edgecolor": "#cccccc"},
    )

    figura.tight_layout()
    figura.savefig(caminho_saida, dpi=140)
    plt.close(figura)


def gerar_resumo_estatistico(resultados, caminho_saida):
    campos = [
        "scenario",
        "operation",
        "metric",
        "samples",
        "mean",
        "median",
        "stddev",
        "min",
        "max",
    ]
    metricas = [campo for campo in METRICAS_RESUMO if campo_disponivel(resultados, campo)]

    with caminho_saida.open("w", newline="", encoding="utf-8") as arquivo:
        escritor = csv.DictWriter(arquivo, fieldnames=campos)
        escritor.writeheader()

        for metrica in metricas:
            estatisticas = calcular_estatisticas(resultados, metrica)
            for cenario in listar_cenarios(resultados):
                for operacao in OPERACOES:
                    dados = estatisticas.get((cenario, operacao))
                    if dados is None:
                        continue

                    escritor.writerow(
                        {
                            "scenario": cenario,
                            "operation": operacao,
                            "metric": metrica,
                            "samples": dados["amostras"],
                            "mean": f"{dados['media']:.6f}",
                            "median": f"{dados['mediana']:.6f}",
                            "stddev": f"{dados['desvio_padrao']:.6f}",
                            "min": f"{dados['minimo']:.6f}",
                            "max": f"{dados['maximo']:.6f}",
                        }
                    )


def gerar_graficos(caminho_csv, pasta_saida):
    resultados = ler_resultados(caminho_csv)

    if not resultados:
        raise ValueError("CSV sem resultados.")

    pasta_saida.mkdir(parents=True, exist_ok=True)

    for campo, titulo, eixo_y, arquivo in GRAFICOS:
        if not campo_disponivel(resultados, campo):
            print(f"Ignorando gráfico {arquivo}: coluna ausente no CSV ({campo}).")
            continue

        gerar_grafico(resultados, campo, titulo, eixo_y, pasta_saida / arquivo)

    gerar_resumo_estatistico(resultados, pasta_saida.parent / "resumo_estatistico.csv")


def criar_parser():
    parser = argparse.ArgumentParser(description="Gera gráficos a partir do CSV do benchmark.")
    parser.add_argument("--input", type=Path, default=Path("results/benchmark.csv"))
    parser.add_argument("--output-dir", type=Path, default=Path("results/graficos"))
    return parser


def main():
    args = criar_parser().parse_args()
    gerar_graficos(args.input, args.output_dir)
    print(f"Gráficos salvos em: {args.output_dir}")


if __name__ == "__main__":
    main()

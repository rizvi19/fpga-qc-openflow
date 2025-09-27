.PHONY: bench bench_qft bench_grover plots

bench:
	python3 experiments/run_bench.py --all

bench_qft:
	python3 experiments/run_bench.py --subset qft

bench_grover:
	python3 experiments/run_bench.py --subset grover

plots:
	python3 experiments/plot_results.py

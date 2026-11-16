JULIA ?= julia
JULIA_FLAGS ?= --startup-file=no --project=.
OUTPUT_DIR ?= plots

.DEFAULT_GOAL := figures
.PHONY: all setup instantiate figures equilibrium experiments test hooks check-public publish clean

all: figures

setup: hooks instantiate

instantiate:
	$(JULIA) $(JULIA_FLAGS) -e 'using Pkg; Pkg.instantiate()'

figures: equilibrium experiments

equilibrium: instantiate
	$(JULIA) $(JULIA_FLAGS) scripts/produce_static_plots.jl "$(OUTPUT_DIR)"

experiments: instantiate
	$(JULIA) $(JULIA_FLAGS) scripts/produce_gamma_experiments_plots.jl "$(OUTPUT_DIR)"

test: instantiate
	$(JULIA) $(JULIA_FLAGS) test/runtests.jl

hooks:
	git config --local core.hooksPath .githooks

check-public:
	sh scripts/check_public.sh HEAD

# Stage reviewed source changes with git add before publishing.
publish: hooks test figures
	sh scripts/publish_public.sh

clean:
	$(JULIA) $(JULIA_FLAGS) -e 'for name in readdir(ARGS[1]; join=true); occursin(r"^(simplepk|baseline|pqc|pqcr|pqcrdiff|firmsration)_equilibrium_panel\.(pdf|png)$$|^baseline_(gamma|s0)_(low|medium|high)_panel\.(pdf|png)$$", basename(name)) && rm(name); end' "$(OUTPUT_DIR)"

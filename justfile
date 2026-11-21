# Mesothelioma subtype classification — the pipeline, step by step.
# Requirements: uv (https://docs.astral.sh/uv) and just (https://just.systems).
# Raw slides (.ndpi) go in data/. Run `just` to list the recipes; extra arguments
# are passed through to each script (run a script with --help to see them all).

default:
    @just --list

# One-time setup: create .venv and install the dependencies.
setup:
    uv venv
    uv pip install -r requirements.txt

# Step 1 — cut tissue patches from the slides: `just patches --wsi data/slide.ndpi`.
patches *ARGS:
    uv run python create_patches.py --out-dir patches {{ARGS}}

# Step 2 — encode patches with a CNN / foundation model: `just features --model resnet50`.
features *ARGS:
    uv run python extract_fv.py --wsi_dir data --patches_dir patches {{ARGS}}

# Step 2 (alt) — UNI foundation-model features.
features-uni *ARGS:
    uv run python uni_extract_fv.py --wsi_dir data --patches_dir patches {{ARGS}}

# Step 4 — aggregate QuPath per-cell features to per-patch mean/std.
aggregate:
    uv run python avg_std.py

# Step 5 — concatenate QuPath features with ResNet50 features.
merge *ARGS:
    uv run python merge_features.py {{ARGS}}

# Step 7 — train CLAM with 4-fold CV (defaults from the report; override any flag).
train FEATURES="MLA_features_kimianet/" *ARGS:
    uv run python train_CLAM.py --csv-path dataset.csv --features-dir {{FEATURES}} --model-type clam_sb --n-classes 3 --epochs 20 --bag-weight 0.7 --opt adam --cv kfold --n-splits 4 {{ARGS}}

# Baselines on the same features (logistic regression, SVM, ...).
baselines:
    uv run python simpler_classifiers.py

# Step 8 — attention heatmap for one slide: `just heatmap --wsi-path ... --features-path ... --checkpoint ...`.
heatmap *ARGS:
    uv run python heatmap.py {{ARGS}}

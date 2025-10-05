- v0.9
    1. Amend `parallel_fastqc.sh` to keep the `FastQC` raw results and run `MultiQC`
        - `MultiQC` cannot be installed in the same `conda` env.
    2. Amend `make_study_strain_files.sh`. When resume the pipeline, it will skip the strains of which reference files has already been made.
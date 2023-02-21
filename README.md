# Pipeline

To run the whole pipeline at once:

```bash
bash pipeline.sh
```

This calls the following scripts (in order):

  1. [scripts/clean-gateway](scripts/clean-gateway).
  2. [harmonize-taxonomy.py](harmonize-taxonomy.py).
  3. [harmonize-taxonomy.R](harmonize-taxonomy.R).

Some of this steps can take some time.
To avoid re-running already completed steps, once the step is  completed succesfully an hidden (empty) file is added to the [steps](steps) folder.
Steps that have such files will not be re-ran.
You can re-run the whole pipeline from scratch specifying the option _--clean_:

```bash
bash pipeline.sh --clean
```

To see available options and usage: `bash pipeline.sh --help`.

# Pipeline

To run the whole pipeline at once:

```bash
bash pipeline.sh
```

This runs (in order):

  1. Clean v.1.0 for encoding/parsing errors: [scripts/clean-gateway](scripts/clean-gateway).
  2. Process new data to add to the database: [scripts/mulder.R](scripts/mulder.R) and [scripts/tagus.R](scripts/tagus.R).
  3. Extract species names: [scripts/extract-species-names.R](scripts/extract-species-names.R).
  4. Query the species names against GBIF: [harmonize-taxonomy.py](harmonize-taxonomy.py).
  5. Combine v.1.0 with new data: [scripts/combine.R](scripts/combine.R).
  6. Harmonize taxonomy of the database: [harmonize-taxonomy.R](harmonize-taxonomy.R).
  7. Saves the new database as _gateway-v.2.0.csv_.
  8. Create summary tables to be displayed on the website: [scripts/summarize.R](scripts/summarize.R).
  9. Display some summary statistics on the terminal.

Some of this steps can take some time.
To avoid re-running already completed steps, once the step is  completed succesfully an hidden (empty) file is added to the [steps](steps) folder.
Steps that have such files will not be re-ran.
You can re-run the whole pipeline from scratch specifying the option _--clean_:

```bash
bash pipeline.sh --clean
```

To see available options and usage: `bash pipeline.sh --help`.

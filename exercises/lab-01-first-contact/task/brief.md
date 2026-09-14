# Bounded task brief

Inspect the supplied synthetic release and produce `work/corrected-questionnaire.csv` by repairing the duplicated `(wave, item_id)` declaration in `questionnaire.csv`. Prove that the two `2019::EMP` rows are identical before removing exactly one; if they disagree, stop and ask rather than guessing which declaration is authoritative. Preserve every other row, order, questionnaire version, and numeric range. Also create `work/provenance.md` and `work/session-observations.md` as requested by the README.

# Public repository publication audit

Audit date: **23 September 2026**. Source reviewed: **StopLaris Shiny v1.1.0**, prepared for v1.2.0 publication.

**Recommendation:** the reviewed application and curated research tables can form the public research repository, with the source attribution and scientific limitations below retained. No credential or data-access blocker was identified in the reviewed candidate. Normalize incidental execution paths and remove redundant runtime outputs before the first commit. This audit does not assign a software, data, or logo license.

## Scope and checks performed now

The initial candidate contained 71 files, approximately 6.55 MB. Only this application directory was inspected. Account setup and publication are outside the scope of this content audit.

| Check | Result |
|---|---|
| Recognizable private keys, GitHub/AWS/Google/OpenAI/Slack credentials, bearer tokens, quoted credential assignments and signed-URL parameters | No matching credential values found in scanned text files |
| Email-shaped strings | Five occurrences in three files; all were R object-slot notation, not email addresses |
| Incidental absolute execution paths | One occurrence in `validation/http-qa-report.json`; twelve in `validation/browser-qa-report.json` |
| Curated data integrity | All 17 output hashes recorded in `data/provenance.json` match; no missing or changed recorded output |
| Downloaded CSV examples | Both 96-cell exports contain only keys already present in the packaged cells table; both patient-profile examples declare clinical risk unavailable |
| Public source status and NCBI guidance | Verified against official NCBI sources listed below |

The credential scan records categories, counts and paths rather than matched values. It is a targeted text inspection, not a guarantee that every possible secret encoding or image content has been exhaustively examined.

## Source attribution and included derivatives

The original investigators generated the biological data. StopLaris supplies a selected, transformed research view and its own downstream analysis outputs; it does not claim original collection of these cohorts.

| Source and linked study | Official public status | Content represented here |
|---|---|---|
| [GSE173278](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE173278), LeBlanc and colleagues; [PMID 35303420](https://pubmed.ncbi.nlm.nih.gov/35303420/) | Public since 16 February 2022 | 842 selected CAF/stromal candidate cells, 10 source patients; source labels, USP9X, archived UMAP, V5 evaluation outputs and a descriptive patient index |
| [GSE141946](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE141946), GEO contributors Zhang and Song; [PMID 31883794](https://pubmed.ncbi.nlm.nih.gov/31883794/) | Public since 26 December 2019 | 1,404 stromal candidate cells from 3 donors and 4 source sample labels; marker references and frozen-model transfer outputs |
| [GSE97930](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE97930), Lake and colleagues; [PMID 29227469](https://pubmed.ncbi.nlm.nih.gov/29227469/) | Public since 11 December 2017 | 10,253 frontal-cortex nuclei after the recorded QC; source class prefixes and USP9X measurements |

Public status, citation IDs and available processed files were obtained from indexed official GEO accession content. Direct accession-page requests encountered a browser challenge during this audit; the indexed results remained available. The study articles themselves were not republished or newly reviewed here.

**Raw sequencing is a separate access category.** The GSE173278 record directs human raw sequence data to controlled-access EGA. This repository candidate contains derived CSV/JSON tables, plots and software; it contains no FASTQ/BAM, raw EGA sequence files, original full RDS objects, or full expression matrices. Public processed GEO data must not be described as permission to redistribute controlled raw data.

Cell barcodes and coded source patient/sample identifiers are retained for reproducibility. No new patient identity mapping, contact record or clinical chart is included. This is a description of the inspected columns and provenance, not an independent re-identification assessment. Healthy sample prefixes are not represented as verified donor identities.

`data/provenance.json` and `data/sources.csv` preserve relative input paths and SHA-256 fingerprints. `scripts/prepare_data.py` describes the selections, identity checks, normalizations and joins. The application runs directly from its curated tables; the original large analysis archive is not included.

## Rights and third-party materials

Official guidance checked on the audit date:

- [NCBI Website and Data Usage Policies — Molecular Data Usage](https://www.ncbi.nlm.nih.gov/home/about/policies/): NCBI itself does not restrict use or distribution of molecular database records, but it does not transfer or guarantee submitters' intellectual-property rights.
- [GEO disclaimer](https://www.ncbi.nlm.nih.gov/geo/info/disclaimer.html): GEO encourages reuse and distribution while distinguishing NCBI's position from any rights asserted by contributors.
- [GEO frequently asked questions](https://www.ncbi.nlm.nih.gov/geo/info/faq.html): public GEO data are accessible without a user login.

These sources support the public-data provenance of the included curated derivatives. They do **not** justify labeling every data file as MIT, CC0, or unrestricted third-party property. No additional dataset-specific restriction was identified in the reviewed records; this is not a blanket rights guarantee.

The candidate has no explicit project-wide license grant. Do not invent one during upload or describe the repository as permissively licensed without an owner decision. A future software license should clearly distinguish project code from third-party source data and other assets.

`www/stoplaris-logo.png` is the supplied project logo. Its inclusion does not grant others an unrestricted logo or trademark license. Runtime R packages are installed separately by `install.R`; their implementations are not vendored in the candidate. Preserve their own terms if dependencies are bundled in a later release. No publisher article text or third-party article figure is included in this candidate.

## Scientific scope to preserve in the public repository

- This is a research-results explorer. The V5 model predicts existing marker-derived cell labels, not survival, recurrence, treatment response or clinical risk.
- Development patient-average macro-F1 and pooled-cell macro-F1 remain separate. External marker agreement is not independent clinical validation; the dataset-classifier AUC measures cohort separability.
- The 0–10 patient output is a within-cohort USP9X rank across the fixed ten-patient reference. Its endpoints are not clinical-risk probabilities. Cell support ranges from 6 to 352; the six-cell patient's high rank does not establish a reliable clinical conclusion.
- Original source UMAP coordinates are descriptive. Zero USP9X counts indicate non-detection rather than therapeutic safety or biological absence.
- New uploaded files remain session-local exploration inputs and do not inherit official project validation or patient scores.

These boundaries are already stated in `README_TR.md`, `Hasta_Degerlendirmesi_TR.md`, `data/scientific_notes.md` and the application. Retain them in any repository description or report citation.

## Repository cleanup before publication

1. Normalize the incidental absolute paths in the two validation JSON reports to repository-relative artifact names. Preserve historical test outcomes and timestamps, and state that report paths were normalized for publication.
2. Omit `validation/startup_server.log` and `validation/shiny-http-server.log` from version control. They are disposable execution logs, not required to run the application.
3. Omit redundant `validation/StopLaris_*.csv` and `validation/StopLaris_olcum_dagilimi_*.png` download examples if a compact repository is desired. Their provenance was checked; this is cleanup rather than removal of discovered private data. Preserve the current eight desktop/mobile screenshots and concise validation reports.
4. Add a version-control ignore file for regenerated logs, local R history, environment files and local dependency folders. Keep the actual source, tests, curated data, source notices and required project startup files.
5. Regenerate the repository file manifest after cleanup. Do not claim the cleaned tree is byte-identical to the original delivery ZIP. Curated data fingerprints should remain unchanged if the tables are unchanged.

These items concern presentation and traceability. No secret value was discovered that requires emergency removal, and no source table was identified as controlled-access raw sequencing.

## Historical evidence versus this audit

The included **22 September 2026** validation records report 13 R test cases / 142 assertions, 74 browser checks and 23 HTTP checks, with no recorded failures. The **21 September 2026** independent source report records 23 data checks. Those are historical run records, not new tests performed for this repository audit.

New work in this audit was limited to repository-content inspection, targeted credential-pattern scanning, verification of the 17 recorded data-output hashes, comparison of sample-export keys, scientific-scope review and focused official-source verification. The application, browser checks and model training were not rerun during this audit. Repository upload and any account creation are separate actions; this document does not claim they have occurred.

## Cleanup applied

Before packaging v1.2.0, incidental execution paths in the two JSON reports were normalized, disposable `.log` files and redundant generated download examples were removed, and source/right notices were added. The eight retained screenshots document the earlier v1.1.0 interface; they are historical evidence, not captures of the revised v1.2.0 header. New R checks, if available, are recorded separately with the 23 September date.

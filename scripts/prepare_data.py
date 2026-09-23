#!/usr/bin/env python3
"""Create the Shiny explorer's compact, traceable data bundle from StopLaris V5.

No model is trained, no label is invented and no embedding is regenerated.
Usage: python scripts/prepare_data.py --source /path/to/source_package
Requires Python >=3.10, numpy, pandas, scipy, rdata==1.1.0, xarray.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import sparse
import rdata
from rdata.parser import RObjectType as T

CLASSES = ["iCAF_like_uncertain", "myCAF_like", "pericyte_vCAF_like"]
PRIMARY_NORMALIZATION = "V5_aligned_input_gene_library"


def digest(p):
    with Path(p).open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def deref(o):
    while o is not None and o.info.type == T.REF:
        o = o.referenced_object
    return o


def string(o):
    o = deref(o)
    if o.info.type == T.SYM:
        o = deref(o.value)
    return o.value.decode("utf-8") if isinstance(o.value, bytes) else str(o.value)


def attrs(o):
    a = deref(deref(o).attributes)
    out = {}
    while a is not None and a.info.type != T.NILVALUE:
        out[string(a.tag)] = a.value[0]
        a = deref(a.value[1])
    return out


def vector(o):
    o = deref(o)
    return dict(zip([string(x) for x in deref(attrs(o)["names"]).value], o.value))


def boolcol(x):
    return x.astype(str).str.lower().eq("true")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "data")
    args = parser.parse_args()
    root, out = args.source.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    sources = {}
    outputs = []

    def path(rel, purpose):
        p = root / rel
        if not p.is_file():
            raise FileNotFoundError(p)
        sources[rel] = {"sha256": digest(p), "bytes": p.stat().st_size, "purpose": purpose}
        return p

    def read(rel, purpose):
        return pd.read_csv(path(rel, purpose), keep_default_na=True)

    def readjson(rel, purpose):
        return json.loads(path(rel, purpose).read_text())

    def writecsv(name, df):
        df.to_csv(out / name, index=False, na_rep="", float_format="%.17g", lineterminator="\n")
        outputs.append(name)

    def writejson(name, obj):
        (out / name).write_text(json.dumps(obj, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        outputs.append(name)

    stage = "01_V5_Ana_Analiz/03_V5_STAGE2/"
    bio = "02_Ek_Kontroller/provenance/"
    ext = "02_Ek_Kontroller/external/"
    report = "01_V5_Ana_Analiz/00_REPORT/"

    source_metadata = read(stage + "source_metadata.csv", "Authoritative V5 cell IDs, patient groups, labels and FibroScore1")
    oof = read(stage + "observed/oof_predictions.csv", "V5 held-out-patient predictions and raw/calibrated class probabilities")
    expr = read(bio + "caf_USP9X_cell_values.csv", "Verified raw/log-normalized USP9X counts for 842 development cells")
    assert source_metadata["cell"].is_unique and oof["cell"].is_unique and expr["cell"].is_unique
    assert set(source_metadata.cell) == set(oof.cell) == set(expr.cell)
    development = source_metadata.merge(oof, on=["cell", "patient"], how="inner", validate="one_to_one")
    assert len(development) == 842
    assert development.manual_subtype_v2.equals(development.true_label)
    development = development.merge(expr[["cell", "patient", "USP9X_raw_counts", "USP9X_log_normalized", "USP9X_positive"]],
                                    on=["cell", "patient"], how="inner", validate="one_to_one")
    assert len(development) == 842 and development.patient.nunique() == 10
    rds = path("01_V5_Ana_Analiz/04_SOURCE_INPUTS/01_ORIGINAL_SOURCES/val_caf_clean_manual_subtype_v2_reprocessed.rds",
               "Original Seurat UMAP coordinates: reductions$umap@cell.embeddings; extracted, not regenerated")
    rdsroot = attrs(rdata.parser.parse_file(rds).object)
    umap = rdata.conversion.convert(attrs(vector(rdsroot["reductions"])["umap"])["cell.embeddings"])
    umap_frame = pd.DataFrame(umap.values, columns=["umap_1", "umap_2"])
    umap_frame["cell"] = umap.coords[umap.dims[0]].values.astype(str)
    assert umap_frame.shape == (842, 3) and umap_frame.cell.is_unique
    assert set(umap_frame.cell) == set(development.cell) and np.isfinite(umap_frame[["umap_1", "umap_2"]]).all().all()
    development = development.merge(umap_frame, on="cell", how="inner", validate="one_to_one")
    dev = pd.DataFrame({
        "dataset": "GSE173278", "cell_id": development.cell, "patient_id": development.patient,
        "sample_id": development["sample"], "cell_type": development.manual_subtype_v2,
        "USP9X": development.USP9X_log_normalized, "USP9X_raw_counts": development.USP9X_raw_counts,
        "USP9X_positive": boolcol(development.USP9X_positive), "library_counts": development.nCount_RNA,
        "predicted_label": development.predicted_expanded_grid, "predicted_calibrated": development.predicted_calibrated,
        "prediction_type": "OOF_leave_one_patient_out", "annotation_type": "archived_marker_derived",
        "umap_1": development.umap_1, "umap_2": development.umap_2,
        "FibroScore1": development.FibroScore1, "n_features": development.nFeature_RNA,
        "percent_mt": development["percent.mt"], "reg_stg": development.reg_stg,
    })
    for prefix in ["p_raw_", "p_cal_"]:
        for cls in CLASSES:
            dev[prefix + cls] = development[prefix + cls]
        assert np.allclose(dev[[prefix + c for c in CLASSES]].sum(axis=1), 1, rtol=0, atol=1e-10)
    dev["max_probability"] = dev[["p_raw_" + c for c in CLASSES]].max(axis=1)

    external_source = read(ext + "results_hgnc/external_predictions.csv", "Latest HGNC-aligned external predictions; primary normalization only")
    ep = external_source.loc[external_source.normalization.eq(PRIMARY_NORMALIZATION)].copy()
    assert len(ep) == 1404 and ep.cell_id.is_unique and ep.donor.nunique() == 3
    raw = sparse.load_npz(path(ext + "prepared_hgnc/external_primary_raw_counts_aligned.npz", "External raw counts aligned to V5 input genes; USP9X extraction only"))
    genes = path(ext + "prepared_hgnc/input_genes.txt", "Gene order of aligned external raw counts").read_text().splitlines()
    cellids = path(ext + "prepared_hgnc/input_cells.txt", "Cell order of aligned external raw counts").read_text().splitlines()
    assert raw.shape == (len(cellids), len(genes)) and len(set(cellids)) == len(cellids)
    assert set(cellids) == set(ep.cell_id) and "USP9X" in genes
    ep = ep.set_index("cell_id").loc[cellids].reset_index()
    external_usp9x = np.asarray(raw[:, genes.index("USP9X")].toarray()).ravel()
    assert np.isfinite(external_usp9x).all() and (external_usp9x >= 0).all()
    external = pd.DataFrame({
        "dataset": "GSE141946", "cell_id": ep.cell_id, "patient_id": ep.donor.astype(str),
        "sample_id": ep.Patient.astype(str) + "." + ep.Timepoint.astype(str), "cell_type": ep.ref_subtype,
        "USP9X": np.log1p(external_usp9x / ep.total_counts.to_numpy() * 10000),
        "USP9X_raw_counts": external_usp9x, "USP9X_positive": external_usp9x > 0, "library_counts": ep.total_counts,
        "predicted_label": ep.predicted_label, "prediction_type": "frozen_external_transfer",
        "annotation_type": "computational_marker_reference", "n_features": ep.n_features,
        "percent_mt": ep.percent_mt, "ref_high_confidence": boolcol(ep.ref_high_confidence),
        "max_probability": ep.max_probability,
    })
    native_scores = ["stromal_perivascular_z", "stromal_fibroblast_ecm_z", "contractile_myCAF_z", "inflammatory_iCAF_z",
                     "pericyte_vCAF_like_ref_z", "myCAF_like_ref_z", "iCAF_like_uncertain_ref_z"]
    for name in native_scores:
        external[name] = ep[name]
    for cls in CLASSES:
        external["p_raw_" + cls] = ep["p_" + cls]
    assert np.allclose(external[["p_raw_" + c for c in CLASSES]].sum(axis=1), 1, rtol=0, atol=1e-10)

    healthy_source = read(bio + "healthy_cell_qc_and_marker_counts.csv", "Source-class prefixes and USP9X counts, retain documented reported-QC passing cells only")
    hp = healthy_source.loc[boolcol(healthy_source.passed_reported_qc)].copy()
    assert len(hp) == 10253 and hp.cell_id.is_unique and (hp.USP9X_counts > 0).sum() == 809
    healthy = pd.DataFrame({
        "dataset": "GSE97930", "cell_id": hp.cell_id, "patient_id": pd.NA,
        "sample_id": hp.source_sample, "cell_type": hp.source_cell_class,
        "USP9X": np.log1p(hp.USP9X_counts / hp.nCount_after_min_cells3 * 10000),
        "USP9X_raw_counts": hp.USP9X_counts, "USP9X_positive": hp.USP9X_counts > 0,
        "library_counts": hp.nCount_after_min_cells3, "prediction_type": "unavailable",
        "annotation_type": "source_barcode_class_prefix", "n_features": hp.nFeature_after_min_cells3,
    })
    cells = pd.concat([dev, external, healthy], ignore_index=True)
    assert len(cells) == 12499 and not cells.duplicated(["dataset", "cell_id"]).any()
    assert cells.USP9X.notna().all() and (cells.USP9X >= 0).all()
    writecsv("cells.csv", cells)

    summary = readjson(stage + "observed/summary.json", "Observed V5 model metrics; immutable production-time permutation flag is superseded")
    ext_summary = readjson(ext + "results_hgnc/EXTERNAL_V6_SUMMARY.json", "Authoritative latest external transfer summary")
    permutation_status = readjson(stage + "PERMUTATION_STATUS.json", "Authoritative completed 1000-permutation status")
    metric_rows = []
    for st in ["expanded_grid", "calibrated"]:
        m = summary["metrics"][st]
        for key in ["patient_mean_macro_f1", "patient_sd_ddof1", "patient_mean_log_loss", "patient_mean_multiclass_brier_sum"]:
            metric_rows.append({"stage": st, "metric": key, "aggregation": "patient_equal_weight", "value": m[key]})
        for key in ["accuracy", "macro_f1_present_true_classes", "macro_f1_fixed_three_classes"]:
            metric_rows.append({"stage": st, "metric": key, "aggregation": "pooled_cells", "value": m["pooled_classification"][key]})
    for key in ["macro_f1", "balanced_accuracy", "accuracy"]:
        metric_rows.append({"stage": "external_transfer", "metric": key, "aggregation": "pooled_marker_reference", "value": ext_summary["marker_reference_concordance_primary"][key]})
    metric_rows.append({"stage": "external_transfer", "metric": "domain_classifier_auc", "aggregation": "dataset_separability_only", "value": ext_summary["domain_classifier_auc"]})
    writecsv("metrics.csv", pd.DataFrame(metric_rows))
    patient_metrics = read(stage + "observed/patient_metrics.csv", "Observed per-patient metrics, main and calibrated stages only")
    patient_metrics = patient_metrics.loc[patient_metrics.stage.isin(["expanded_grid", "calibrated"])].rename(columns={"patient": "patient_id"})
    patient_metrics.insert(0, "dataset", "GSE173278")
    writecsv("per_patient_metrics.csv", patient_metrics)
    confusion_rows = []
    for st, df, actual, pred in [
        ("expanded_grid", development, "true_label", "predicted_expanded_grid"),
        ("calibrated", development, "true_label", "predicted_calibrated"),
        ("external_transfer", ep, "ref_subtype", "predicted_label"),
    ]:
        for true in CLASSES:
            for predicted in CLASSES:
                confusion_rows.append({"stage": st, "true_label": true, "predicted_label": predicted,
                                       "n": int((df[actual].eq(true) & df[pred].eq(predicted)).sum())})
    writecsv("confusion.csv", pd.DataFrame(confusion_rows))
    writejson("external_summary.json", ext_summary)
    writejson("permutation_status.json", permutation_status)
    per = read(stage + "permutation_scores.csv", "Completed restricted permutation null distribution")
    assert sorted(per.permutation.tolist()) == list(range(1, 1001))
    assert (per.score >= summary["metrics"]["expanded_grid"]["patient_mean_macro_f1"]).sum() == 0
    writecsv("permutation_scores.csv", per)
    for name, rel, purpose in [
        ("reliability_bins.csv", report + "reliability_bins.csv", "Descriptive pooled-cell reliability bins; source stage labels retained"),
        ("selective_thresholds.csv", report + "fixed_selective_thresholds_exploratory.csv", "Prespecified exploratory confidence thresholds; not clinical operating points"),
        ("patient_bootstrap_ci.csv", "02_Ek_Kontroller/audit/patient_block_bootstrap_ci.csv", "Descriptive patient bootstrap intervals, not new model training"),
        ("usp9x_patient_summary.csv", bio + "caf_USP9X_patient_by_label.csv", "Per-patient subtype USP9X summary"),
        ("marker_summary.csv", bio + "caf_marker_expression_by_label.csv", "Marker/label internal consistency only"),
        ("healthy_summary.csv", bio + "healthy_USP9X_by_source_cell_class.csv", "Healthy post-QC USP9X by source class prefix"),
        ("external_concordance.csv", ext + "results_hgnc/marker_reference_concordance.csv", "External primary and sensitivity marker-reference concordance"),
    ]:
        writecsv(name, read(rel, purpose))

    score_info = [
        {"name": "FibroScore1", "label": "FibroScore1", "description": "Arşiv Seurat fibroblast modül skoru. CAF alt tipi olasılığı değildir; özgün skor kontrol-gen kümesinin tam kod izi bulunmamıştır.", "datasets": ["GSE173278"]},
    ]
    score_labels = {
        "stromal_perivascular_z": "Perivasküler stromal marker z skoru",
        "stromal_fibroblast_ecm_z": "Fibroblast / ECM marker z skoru",
        "contractile_myCAF_z": "Kontraktil myCAF marker z skoru",
        "inflammatory_iCAF_z": "İnflamatuvar iCAF marker z skoru",
        "pericyte_vCAF_like_ref_z": "Perisit / vCAF referans z skoru",
        "myCAF_like_ref_z": "myCAF referans z skoru",
        "iCAF_like_uncertain_ref_z": "Belirsiz iCAF referans z skoru",
    }
    for name in native_scores:
        score_info.append({"name": name, "label": score_labels[name], "description": "Dış verinin kayıtlı gen-panel skoru. Marker referansı oluşturma bileşenidir; bağımsız biyolojik doğrulama veya model olasılığı değildir.", "datasets": ["GSE141946"]})
    metadata = {
        "title": "StopLaris • R Shiny araştırma gezgini", "schema_version": "1.0.0", "data_version": "V5_STAGE2_2026-09-20",
        "stages": {"main": "expanded_grid", "secondary": "calibrated", "external": "external_transfer"},
        "classes": CLASSES, "default_dataset": "GSE173278", "score_columns": score_info,
        "usp9x_scale": "log1p(10 000 × USP9X ham sayım / veri kümesine ait kütüphane toplamı)",
        "datasets": [
            {"id": "GSE173278", "label": "GSE173278 · geliştirme CAF/stromal", "n_cells": 842, "n_patients": 10,
             "patient_ids_verified": True, "n_samples": int(dev.sample_id.nunique()), "has_umap": True,
             "description": "842 seçilmiş CAF/stromal aday hücre; mevcut marker kökenli üç sınıf. Hasta dışarıda bırakmalı V5 tahminleri.",
             "usp9x_denominator": "Kaynak RDS içindeki 24.715 genin tam hücre toplamı (nCount_RNA).",
             "url": "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE173278"},
            {"id": "GSE141946", "label": "GSE141946 · dış stromal aktarım", "n_cells": 1404, "n_patients": 3,
             "patient_ids_verified": True, "n_samples": 4, "has_umap": False,
             "description": "Üç bağımsız donörden dört kaynak örnek; 1.404 stromal aday. Dondurulmuş model aktarımı; bağımsız uzman altın standardı yok.",
             "usp9x_denominator": "Tüm dış gen evrenindeki total_counts. Model olasılıkları ise kayıtlı birincil V5 aligned-input normalizasyonundan gelir.",
             "url": "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE141946"},
            {"id": "GSE97930", "label": "GSE97930 · sağlıklı beyin / QC sonrası", "n_cells": 10253, "n_patients": None,
             "patient_ids_verified": False, "n_samples": int(healthy.sample_id.nunique()), "has_umap": False,
             "description": "Sağlıklı beyin snRNA-seq. Kayıtlı QC koşullarını geçen 10.253 hücre; sınıflar kaynak barkod önekleri. Bu aktarımda doğrulanmış donör eşlemesi yok.",
             "usp9x_denominator": "En az üç hücrede saptanan gen filtresinden sonraki nCount_after_min_cells3.",
             "url": "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE97930"},
        ],
        "metric_definitions": {
            "patient_mean_macro_f1": "Her test hastasında gerçek etiketler arasında bulunan sınıfların makro-F1 değeri; 10 hastanın eşit ağırlıklı ortalaması.",
            "patient_sd_ddof1": "10 hasta puanının örnek standart sapması; güven aralığı değildir.",
            "patient_mean_multiclass_brier_sum": "Üç sınıfın karesel olasılık hataları toplamı (0–2 ölçeği), hasta başına ortalamaların ortalaması.",
            "macro_f1": "Dış kohort hücreleri birleştirilerek mevcut hesaplamalı marker referansına makro-F1 uyumu.",
            "domain_classifier_auc": "Geliştirme ve dış veri kümelerinin ayırt edilebilirliği; CAF alt tipi sınıflandırma başarısı değildir.",
        },
        "limitations": [
            "Araştırma amaçlı sonuç gezgini; klinik karar veya tedavi önerisi üretmez.",
            "CAF/KİF terminolojisindeki eski etiketler güncel üç sınıfa sessizce dönüştürülmedi; özgün etiketler korundu.",
            "iCAF_like_uncertain yalnız 37 hücre ve altı hastaya dayanır.",
            "FibroScore1 ve dış marker skorları farklı yöntemlerdir; veri kümeleri arasında ortak ölçek gibi karşılaştırılmaz.",
            "Sağlıklı/tümör veri kümelerinde platform, örnekleme ve normalizasyon paydaları farklıdır; doğrudan vaka-kontrol testi yapılmadı.",
            "Sıfır USP9X sayımı ölçümde saptanmamayı gösterir; biyolojik yokluk veya tedavi güvenliliği kanıtı değildir.",
            "UMAP yalnız kaynak RDS'den 842 geliştirme hücresi için çıkarılmıştır; tahmin performansının bağımsız kanıtı değildir.",
        ],
    }
    writejson("metadata.json", metadata)
    notes = """# Bilimsel yorum sınırları\n\n- Geliştirme: 842 hücre, 10 hasta. Ana metrik hasta ortalama makro-F1 = 0,8840518603780836; birleşik hücre makro-F1 = 0,9231877906547575. Bu ölçüler farklı ağırlıklandırmalarla hesaplanır.\n- Ana OOF çıktıda her hücrenin hastası eğitim dışında tutulmuştur. Kalibrasyon ikincil analizdir. Mevcut etiketlerin yeniden tahmini bağımsız CAF alt tipi doğrulaması değildir.\n- Permütasyon: 1.000 gerçek farklı koşu, aşım 0, artı-bir p = 1/1001 = 0,000999000999. Test yalnız kalibrasyonsuz geniş-grid hasta ortalama F1 istatistiğine aittir.\n- Dış aktarım: 1.404 stromal aday, üç donör, dört kaynak örnek. Marker referansına makro-F1 0,37972798540827163; bağımsız uzman altın standardı ve klinik doğrulama yok. Dataset-ayırma AUC değeri CAF başarısı değildir.\n- GSE97930 sağlıklı QC sonrası 10.253 hücrenin 809'unda USP9X > 0. Kaynak sınıf önekleri korunmuştur; donör kimliği çıkarılmamıştır.\n- Geliştirme USP9X log-normalizasyon paydası 24.715 kaynak genin toplamıdır. Dış ifade görselleştirmesinin paydası tüm dış kütüphane toplamıdır; dış model olasılıkları kayıtlı V5 aligned-input normalizasyonunu korur. Sağlıklı payda min.cells=3 filtresinden sonraki toplamdır. Veri kümeleri arasında doğrudan etki/ekspresyon farkı testi yapılmaz.\n- Güncel kaynakta emCAF/iCAF/myCAF için ortak üç program skoru yoktur. FibroScore1 ve dış marker skorları özgün adlarıyla sunulur; pericyte_vCAF_like, emCAF diye yeniden adlandırılmaz.\n- UMAP koordinatları kaynak Seurat nesnesinden hücre kimliğiyle 1:1 eşleştirilmiştir. Yeniden UMAP çalıştırılmamıştır. Dış ve sağlıklı kohort koordinatları boştur.\n- USP9X hedeflemesi, tedavi yararı, nedensellik veya normal doku güvenliliği bu uygulamada gösterilmiş sayılmaz.\n"""
    (out / "scientific_notes.md").write_text(notes, encoding="utf-8")
    outputs.append("scientific_notes.md")
    source_rows = [{"source_path": p, **v} for p, v in sorted(sources.items())]
    writecsv("sources.csv", pd.DataFrame(source_rows))
    provenance = {
        "schema_version": "1.0.0", "source_package_status": "COMPLETE_COMPUTATIONAL_PRE_FINAL_WITH_SCIENTIFIC_LIMITATIONS",
        "import_script_sha256": digest(__file__), "source_paths_are_relative_to": "source_package",
        "sources": sources,
        "transformations": [
            "Development source_metadata/oof_predictions/USP9X joined 1:1 on cell+patient, identical labels asserted; expanded OOF is primary.",
            "Original Seurat reductions$umap@cell.embeddings extracted with rdata 1.1.0, finite 842x2 matrix and cell-ID bijection asserted.",
            "External predictions filtered to normalization V5_aligned_input_gene_library to avoid counting 2,808 sensitivity rows as cells.",
            "External aligned matrix USP9X raw counts matched by unique cell IDs; visualization log1p(count/total_counts*10000), without changing model input or predictions.",
            "Healthy cells filtered by passed_reported_qc; 10253 cells and 809 USP9X-positive asserted; log1p(count/nCount_after_min_cells3*10000).",
            "No re-training, relabeling, inferred donor identifiers, synthetic rows, newly estimated embeddings, or artificial biological score mappings.",
            "Metrics copied from authoritative current summaries; confusion cell counts recomputed deterministically; per-patient metrics retain source definitions.",
        ],
        "validation": {"development_cells": 842, "development_patients": 10, "external_cells": 1404, "external_donors": 3,
                       "healthy_postqc_cells": 10253, "healthy_USP9X_positive": 809, "total_cells": 12499,
                       "unique_dataset_cell_keys": True, "umap_exact_source_cells": 842, "permutations": 1000,
                       "source_labels_preserved": True, "probability_sums_checked": True},
        "outputs_sha256": {name: digest(out / name) for name in sorted(outputs)},
    }
    writejson("provenance.json", provenance)
    print(json.dumps({"output": str(out), "n_cells": len(cells), "files": sorted(outputs), "sources": len(sources)}, ensure_ascii=False))


if __name__ == "__main__":
    main()

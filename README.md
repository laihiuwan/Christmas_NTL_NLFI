# Nighttime Light Patterns During Christmas

**GRMD 4004 - Geospatial Programming and Data Mining**

Analysing cultural vs commercial activation in US and Chinese cities using NASA Black Marble nighttime light data (December 2019).

---

## Overview

**Research Question**: Do US and Chinese cities respond differently to Christmas in nighttime light patterns?

**Approach**:
- **City-level** (10 cities): Compare holiday response patterns
- **Pixel-level** (Houston vs Shanghai): Implement NLFI to identify activity-responsive zones
- **Integration**: Correlate NLFI with Christmas effects

**Key Finding**: Houston's Christmas activates uniformly (r = 0.056), while Shanghai shows selective commercial activation (r = 0.314).

---

## Pipeline

```
GEE (Python) → ArcPy (Python) → MATLAB
     ↓              ↓               ↓
  Download      Preprocess    City + Pixel Analysis
```

**Data**: NASA Black Marble VNP46A2, 10 cities × 31 days (December 2019)

---

## File Structure

```
geoprog_submit/
├── download_NTL.py              # Step 1: GEE download
├── preprocess_NTL.py            # Step 2: ArcPy preprocessing
├── fQA.m                        # Helper: quality assurance (used by Step 3)
├── city_christmas.m             # Step 3: City-level (CSV) analysis
├── pixel_NLFI.m                 # Step 4: Pixel-level NLFI (one city)
├── city_NLFI_kmeans.m           # Step 5: All cities → NLFI + Christmas → K-means plot
│
├── cities.csv                   # Input: coordinates (for preprocess; place with ArcPy workspace)
├── all_cities_daily_mean.csv    # Output: city time series (from preprocess)
│
└── masked_tifs/                 # Output: masked GeoTIFFs (per city; under ArcPy root_path)
    ├── Shanghai/
    │   ├── Shanghai_20191201_NTL_masked.tif
    │   └── ... (31 files)
    └── Houston/
        └── ...
```

---

## How to Run

### Step 1: Download Data (Python + GEE)

```bash
python download_NTL.py
```

**Edit in `download_NTL.py`**:
- Line 5: `ee.Initialize(project='...')` — your Earth Engine project
- Lines 7–18: `cities` bounding boxes (optional changes)
- Line 20: `root` — where raw GeoTIFFs are saved (e.g. `.../black_marble`)
- Lines 24–25: `d` and `end` — date range (default: all of December 2019)

**Output**: Raw GeoTIFFs under `{root}/{city}/`.

---

### Step 2: Preprocess (Python + ArcPy)

**Prerequisites**: `cities.csv` with columns `City`, `Latitude`, `Longitude`

```bash
python preprocess_NTL.py
```

**Edit in `preprocess_NTL.py`**: Line 6 `root_path` — ArcGIS workspace (contains `cities.csv`; writes `masked_tifs/` and `all_cities_daily_mean.csv` there).

**Outputs** (under `root_path`):
- `masked_tifs/{city}/{city}_{date}_NTL_masked.tif`
- `all_cities_daily_mean.csv`

---

### Step 3: City-Level Analysis (MATLAB)

**Prerequisites**: `fQA.m` in the same folder as `city_christmas.m`.

```matlab
run('city_christmas.m')
```

**Edit in `city_christmas.m`**: Line 3 `file_path` — path to `all_cities_daily_mean.csv`.

**Outputs**: Time series plots and bar chart.

---

### Step 4: Pixel-Level NLFI (MATLAB)

```matlab
% In pixel_NLFI.m: line 3 root_path (folder containing per-city TIF subfolders);
%                  line 4 city_name (e.g. 'Houston', 'Shanghai')
run('pixel_NLFI.m')
```

**Outputs** in `masked_tifs/{city}_NLFI/` (next to each city’s TIF folder):
- `{city}_nlfi.tif` — NLFI map
- `{city}_christmas_effect.tif` — Christmas effect map
- Figures: expected variation scatter, side-by-side maps, NLFI vs Christmas correlation

---

### Step 5: All cities — NLFI vs Christmas + K-means (MATLAB)

**Prerequisites**: `masked_tifs/` populated for every city listed at the top of `city_NLFI_kmeans.m` (same layout as Step 4).

```matlab
% Edit line 3 in city_NLFI_kmeans.m: root_path = '/path/to/masked_tifs';
run('city_NLFI_kmeans.m')
```

Computes **city-mean NLFI** and **city-mean Christmas effect (%)** for each city, then **K-means** (k = 3) on z-scored `[NLFI, Christmas effect]` and plots the scatter with cluster colors.

---

## Key Methods

### City-Level
- **QA**: 3-sigma outlier removal, median filter, moving average
- **Formula**: `Holiday_Effect = ((Xmas_mean - Baseline_mean) / Baseline_mean) × 100`
- **Periods**: Baseline = Dec 1-15, Christmas = Dec 21-26

### Pixel-Level NLFI (from Tan et al., 2026)
Link to paper: https://doi.org/10.1016/j.scs.2025.107043
1. **Reshape**: `stack(row,col,31)` → `X(pixels,31)` for vectorised stats
2. **Per-pixel stats**: mean, std, CV, slope (polyfit), kurtosis
3. **Filter stable pixels**: CV ≤ 30th percentile, |slope| ≤ 0.05, kurtosis ≤ 4, radiance ≥ 0.5
4. **Fit line**: OLS on stable pixels: `std = a × mean + b`
5. **NLFI**: `|a×mean - std + b| / √(a² + 1)` (perpendicular distance)
6. **Christmas effect**: Same formula as city-level, but per pixel
7. **Correlation**: `r = corr(NLFI, Christmas_effect)` ← **original contribution**

---

## Results

| Metric | Houston | Shanghai |
|--------|---------|----------|
| City-level | +12% | -3% |
| Correlation (NLFI × Xmas) | **r = 0.056** | **r = 0.314** |
| Interpretation | Cultural (uniform) | Commercial (selective) |
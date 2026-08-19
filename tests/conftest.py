import sys
from pathlib import Path

import pandas as pd
import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

SAMPLE_DIR = REPO_ROOT / "sample_data"


@pytest.fixture
def diabetes_batch() -> pd.DataFrame:
    return pd.read_csv(SAMPLE_DIR / "diabetes_batch.csv")


@pytest.fixture
def obesity_batch() -> pd.DataFrame:
    return pd.read_csv(SAMPLE_DIR / "obesity_batch.csv")


@pytest.fixture
def patient_history() -> pd.DataFrame:
    return pd.read_csv(SAMPLE_DIR / "patient_history.csv")


@pytest.fixture
def detail(diabetes_batch, obesity_batch, patient_history) -> pd.DataFrame:
    from sob_pipeline import classify, merge

    merged = merge.merge_batches(diabetes_batch, obesity_batch)
    return classify.classify(merged, patient_history)

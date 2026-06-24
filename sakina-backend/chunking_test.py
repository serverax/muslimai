"""Unit tests for the pure chunker helpers (no transformers/model needed)."""
from chunking import preprocess, split_by_markers


def test_preprocess_removes_diacritics_and_normalizes_whitespace():
    raw = "بِسْمِ   اللَّهِ\n\n"
    out = preprocess(raw)
    # kasra / shadda / sukun stripped
    for ch in ("ِ", "ّ", "ْ"):
        assert ch not in out
    assert "  " not in out
    assert out.split() == ["بسم", "الله"]


def test_split_by_islamic_markers():
    text = "intro باب one فصل two مسألة three"
    assert split_by_markers(text) == ["intro", "one", "two", "three"]


def test_split_by_paragraphs():
    assert split_by_markers("a\n\nb\n\nc") == ["a", "b", "c"]


def test_split_ignores_empty_sections():
    assert split_by_markers("باب\n\n   باب x") == ["x"]

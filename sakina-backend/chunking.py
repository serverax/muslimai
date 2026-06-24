"""Arabic semantic chunker for Project Sakina ingestion (Phase 2, Step 6).

`preprocess` and `split_by_markers` are pure functions (no heavy deps) so they
can be unit-tested without `transformers`. `ArabicSemanticChunker.chunk` needs a
tokenizer, so `transformers` is imported lazily inside `__init__`.
"""
from __future__ import annotations

import re
from typing import List

# Arabic harakat (U+064B..U+065F) plus superscript alef (U+0670), built from
# explicit code points so the Arabic-Indic DIGIT block (U+0660..U+0669) is
# never included in the strip set.
_DIACRITIC_CODEPOINTS = list(range(0x064B, 0x0660)) + [0x0670]
_DIACRITICS = re.compile("[" + "".join(chr(c) for c in _DIACRITIC_CODEPOINTS) + "]")
_MARKERS = ["باب", "فصل", "مسألة", "\n\n"]


def preprocess(text: str) -> str:
    """Remove Arabic diacritics and normalize whitespace."""
    text = _DIACRITICS.sub("", text)
    return " ".join(text.split())


def split_by_markers(text: str) -> List[str]:
    """Split by Islamic text-structure markers (bab / fasl / mas'ala / paragraph)."""
    sections = [text]
    for marker in _MARKERS:
        nxt: List[str] = []
        for s in sections:
            nxt.extend(s.split(marker))
        sections = nxt
    return [s.strip() for s in sections if s.strip()]


class ArabicSemanticChunker:
    def __init__(
        self,
        model_name: str = "GATE-AraBERT-v1",
        max_chunk_size: int = 512,
        overlap_size: int = 75,
    ):
        from transformers import AutoTokenizer  # lazy: heavy dependency

        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.max_chunk_size = max_chunk_size
        self.overlap_size = overlap_size

    def chunk(self, text: str) -> List[str]:
        """Preprocess, split on markers, then build overlapping token windows."""
        text = preprocess(text)
        sections = split_by_markers(text)
        step = self.max_chunk_size - self.overlap_size
        chunks: List[str] = []
        for section in sections:
            tokens = self.tokenizer.tokenize(section)
            for i in range(0, len(tokens), step):
                window = tokens[i : i + self.max_chunk_size]
                piece = self.tokenizer.convert_tokens_to_string(window)
                if piece.strip():
                    chunks.append(piece)
        return chunks


__all__ = ["ArabicSemanticChunker", "preprocess", "split_by_markers"]

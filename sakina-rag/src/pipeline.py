from dataclasses import dataclass


@dataclass
class RagSettings:
    chunk_size: int = 700
    chunk_overlap: int = 120
    retrieval_top_k: int = 6


def validate_settings(settings: RagSettings) -> bool:
    return settings.chunk_size > settings.chunk_overlap > 0

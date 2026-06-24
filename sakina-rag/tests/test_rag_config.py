from pathlib import Path


def test_rag_config_files_exist():
    assert Path('sakina-rag/config/indexing.yaml').exists()
    assert Path('sakina-rag/config/retrieval.yaml').exists()

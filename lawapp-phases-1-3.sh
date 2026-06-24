#!/bin/bash
cd /mnt/f/lawapp
mkdir -p reports

# Phase 1
git status --short > reports/gemini-git-status.txt
git branch --show-current > reports/gemini-git-branch.txt
git rev-parse HEAD > reports/gemini-git-head.txt
find . -maxdepth 3 -type d | sort > reports/gemini-dirs.txt
find . -maxdepth 5 -type f | grep -Ev 'node_modules|target|build|\.dart_tool|\.git|Pods|DerivedData' | sort > reports/sakina-full-file-inventory.txt

# Phase 2
find . -type f | sort > reports/gemini-all-files.txt
find backend -type f | sort > reports/gemini-backend-files.txt || true
find client -type f | sort > reports/gemini-client-files.txt || true
find db -type f | sort > reports/gemini-db-files.txt || true
find ingestion -type f | sort > reports/gemini-ingestion-files.txt || true
find infra -type f | sort > reports/gemini-infra-files.txt || true
find tests -type f | sort > reports/gemini-tests-files.txt || true
find scripts -type f | sort > reports/gemini-scripts-files.txt || true
find .github -type f | sort > reports/gemini-github-actions-files.txt || true
find . -type f -empty | sort > reports/gemini-empty-files.txt
find . -type f -size +1M | sort > reports/gemini-huge-files.txt
grep -R -i -E "RightsNow|IterLaw|Hermes|Sakina|AIA|Agentire|OpenClaw" . -n --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.venv > reports/gemini-project-contamination.txt || true

# Phase 3
grep -R -i -E "TODO|FIXME|stub|Mock|fake|placeholder|simulator|dummy|not implemented|NotImplemented|pass #|return \{\}|return \[\]|coming soon|demo only|hardcoded|unwrap|panic|0\.92|mock_embeddings|FakeModuleApiClient|User handler stub|TODO: Insert into database|Stub implementation" . -n --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=dist --exclude-dir=build > reports/gemini-stub-fake-register.txt || true

echo "Phases 1-3 extraction complete"
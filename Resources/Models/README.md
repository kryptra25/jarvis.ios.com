# Models folder

This folder is empty in source control on purpose — the model file is ~400MB
and gets downloaded fresh by `scripts/download_model.sh` (or automatically by
the GitHub Actions build workflow) right before the app is built.

After running the download script, this folder should contain:

    qwen2.5-0.5b-instruct-q4_k_m.gguf

That exact filename matters — it must match `LocalLLMService.modelFileName`
in Sources/Services/LocalLLMService.swift. If you swap in a different model,
update both the download script and that constant together.

# models — Binary models and trained artifacts

Purpose
- Store binary model artifacts used by runtime services (wake-word models, custom classifiers, etc.).

Current contents
- `hey-sage-wake-up-train.ppn` — Porcupine wake-word model for "Hey Sage" (binary).

Notes
- `.ppn` files are produced by Picovoice/Porcupine tooling and are subject to Picovoice licensing. Do not publish licensed model binaries in public repositories unless permitted.
- To regenerate a custom wake-word, use Picovoice Console and follow Picovoice instructions. Replace the file and update `wake_word_service.py` if the path differs.

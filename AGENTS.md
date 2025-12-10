***

### 2. AGENTS.md
This file details the specific AI configuration used in the unified script, explaining *why* we strip images for the AI even though we have the full database.

```markdown
# AI Agent Configuration (Unified)

## The "Guide" Persona

In this unified deployment, the AI operates as a **Retrieval Augmented Generation (RAG)** agent. It does not rely on its own training data for facts; instead, it "reads" the local Wikipedia database and synthesizes the information.

* **Role:** Galactic Encyclopedia Editor.
* **Tone:** Cynical, humorous, dry, slightly absurd (Douglas Adams style).
* **Constraint:** Must keep answers under 100 words.

## Model Selection

We utilize **Qwen2-0.5B-Instruct**, quantized to **Q4_K_M**.

| Metric | Specification | Reason |
| :--- | :--- | :--- |
| **Model Size** | ~350 MB | Fits entirely in RAM on a 512MB Pi Zero 2 W (leaving room for OS). |
| **Context Window** | 2048 Tokens | Sufficient to read a standard Wikipedia introduction. |
| **Format** | GGUF | Native support in `llama.cpp`. |

## The Data Pipeline

Since we are using the **Maxi (Full Graphics)** database, the AI agent requires a specific pipeline to function without "choking" on HTML tags or image data.

1.  **Retrieval:**
    The Flask middleware fetches the full article from the local Kiwix server (`http://localhost:9095`).

2.  **Sanitization (Crucial):**
    Before the text reaches the AI, a `BeautifulSoup` script aggressively strips:
    * `<img>` and `<figure>` tags (The AI is text-only).
    * `<table>` data (Confuses small models).
    * `<script>` and `<style>` elements.
    * Citations `[1]` and Edit markers.

3.  **Truncation:**
    The cleaned text is truncated to the first **2,500 characters**. This ensures we stay within the model's 2,048-token context window, preventing memory overflows.

4.  **Generation:**
    The sanitized text is wrapped in the system prompt.

## System Prompt

The specific prompt engineering used in `app.py` and `console_guide.py` is:

```text
<|im_start|>user
Based on this text: {CLEAN_WIKI_CONTEXT}

Write a cynical, funny, Hitchhiker's Guide entry for '{USER_QUERY}'. 
Keep it under 100 words.
<|im_end|>
<|im_start|>assistant

---
name: pdf-summarizer
description: Manages notebooks, attaches PDF/documents, generates AI summaries via Open Notebook, and sends status/summary updates to Buzz channels.
---

# Open Notebook & Buzz Integration Skill

This skill integrates Hermes with an Open Notebook instance (`lfnovo/open-notebook`) via REST/MCP API and broadcasts processing results directly to Buzz chat channels.

## Features
- **List & Create Notebooks**: Manage knowledge base collections in Open Notebook.
- **Add Sources**: Upload PDFs, local files, or web URLs directly to a notebook.
- **Summarize**: Trigger LLM summary pipelines in Open Notebook.
- **Buzz Notifications**: Automatically post upload confirmations and generated summaries to the configured Buzz channel.

## Remote Open Notebook Setup Checklist
When connecting to a remote Open Notebook instance:
1. **Bind Address**: Ensure Open Notebook listens on `0.0.0.0` rather than `127.0.0.1`.
2. **Authentication**: Set `OPEN_NOTEBOOK_PASSWORD` / bearer token for security.
3. **Firewall**: Allow incoming traffic on port 5055 from Hermes Agent IP (`sudo ufw allow from <HERMES_IP> to any port 5055`).
4. **SSL / VPN**: Use HTTPS or a private overlay network (Tailscale/WireGuard) for encrypted transport.

## Required Environment Variables
Ensure these environment variables are set in your `.env` or container environment:
- `OPEN_NOTEBOOK_URL`: Base URL for Open Notebook (e.g., `http://localhost:5055` or `http://192.168.1.100:5055`)
- `OPEN_NOTEBOOK_PASSWORD`: Authentication token for Open Notebook API
- `BUZZ_WEBHOOK_URL`: Webhook URL for posting messages/summaries back to the Buzz channel (optional)

## CLI Usage Examples

```bash
# List all notebooks
python3 storage_helper.py --action list_notebooks

# Create a new notebook
python3 storage_helper.py --action create_notebook --title "Research Papers"

# Add a PDF source and automatically notify Buzz
python3 storage_helper.py --action add_source --notebook-id <NOTEBOOK_ID> --file-path /path/to/document.pdf --notify-buzz

# Trigger summarization and post summary to Buzz channel
python3 storage_helper.py --action summarize --notebook-id <NOTEBOOK_ID> --source-id <SOURCE_ID> --notify-buzz

# Get source details or summary
python3 storage_helper.py --action get_summary --source-id <SOURCE_ID>
```

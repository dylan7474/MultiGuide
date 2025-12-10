# The Hitchhiker's Guide (Unified "Maxi" Edition)

> *"Space is big. You just won't believe how vastly, hugely, mind-bogglingly big it is."*

This project transforms a Raspberry Pi Zero 2 W (or any Debian Linux host) into a fully offline, self-contained encyclopedic assistant. 

It combines the best of both worlds: a **full graphical Wikipedia mirror** for serious research, and a **retro AI-powered "Guide" interface** for Douglas Adams-style interactions.

## 🚀 Capabilities

**1. The "Maxi" Archive (Offline)**
* Hosts the full English Wikipedia (~100GB) including images, sidebars, and tables.
* **Zero Internet Required:** Once installed, the device works comfortably in deep space (or a subway tunnel).

**2. Three Distinct Interfaces**
* **🌐 Wiki Reader (Web):** A clean, modern, responsive interface for browsing Wikipedia with full graphics.
* **📟 The Guide (Retro Web):** A CRT-styled, green-on-black interface that uses AI to summarize articles in the voice of *The Guide*.
* **💻 Console Client:** A text-only terminal interface designed to drive hardware displays (like OLED screens or Histplats).

**3. "Deep Thought" AI Core**
* Uses a locally hosted Small Language Model (SLM) to read articles and generate concise, cynical summaries.
* Optimized for the 512MB RAM limit of the Raspberry Pi Zero 2 W.

## 🛠️ Hardware Requirements

* **Computer:** Raspberry Pi Zero 2 W (Recommended) OR any x86_64/ARM64 Linux machine.
* **Storage:** 128GB+ microSD card (High Endurance recommended).
* **Power:** 5V 2.5A Power Supply.

## 💿 Installation

1.  **Prepare your Pi/Host:**
    Install Raspberry Pi OS Lite (64-bit) or Debian 13.

2.  **Download the Deployment Script:**
    Copy `deploy_unified_maxi.sh` to your home folder.

3.  **Run the Installer:**
    ```bash
    chmod +x deploy_unified_maxi.sh
    ./deploy_unified_maxi.sh
    ```

4.  **Data Setup (Interactive):**
    The script will ask you to provide the Wikipedia Database (`wikipedia_en_all_maxi.zim`). You can:
    * **Download:** The script will fetch the latest ~100GB file (Takes hours/days).
    * **Upload:** The script will pause and give you an `scp` command to transfer the file from your PC (Recommended).

## 📖 Usage

Once deployment is complete, the device hosts a local web server on **Port 80**.

### 1. The Wiki Reader (Standard Mode)
* **URL:** `http://<device-ip>/`
* **Description:** Access the raw, unadulterated Wikipedia with images. Fast and accurate.

### 2. The Guide (AI Mode)
* **URL:** `http://<device-ip>/retro`
* **Description:** "Don't Panic." A stylized interface.
    * **Search:** Type a query (e.g., "Earth").
    * **Result:** The AI reads the underlying Wiki entry and rewrites it as a "Guide Entry."

### 3. Console Client (Hardware Mode)
For running on a physical screen attached to the device (SSH or UART):
```bash
python3 ~/theguide/console_guide.py
Controls: Type query, press Enter. Type exit to quit.

Function: Fetches text, strips HTML/Images, and pipes it to the AI for summarization.

🔧 Architecture
Backend:

kiwix-serve: Hosts the .zim file on port 9095.

llama.cpp: Hosts the AI model (Qwen 2 0.5B) on port 8080.

Flask (Python): Middleware on port 80. Bridges the user, the database, and the AI.

Storage:

Requires a 4GB Swap file (created automatically) to handle compilation and heavy I/O operations on low-RAM devices.

❓ Troubleshooting
If the Guide isn't behaving as expected, check these common issues:

1. "Deep Thought" (AI) Returns No Data
If the retro interface says "The brain provided no data" or simply hangs:

Check Memory (Swap): The Pi Zero 2 W must have an active swap file to run the AI model.

Bash

free -h
Look for the Swap: line. If it shows 0B, re-run the setup script or enable dphys-swapfile.

Check the AI Service:

Bash

sudo systemctl status guide-ai
If it's not "active (running)", try restarting it: sudo systemctl restart guide-ai

Patience on Boot: On a cold boot, the AI model takes about 30-60 seconds to load from the SD card into RAM. During this time, queries may fail.

2. Wikipedia Images Not Loading
Check the ZIM File: Ensure you are using the Maxi version (wikipedia_en_all_maxi.zim) and not the nopic version.

Check Kiwix Service:

Bash

sudo systemctl status guide-kiwix
3. Web Interface Not Accessible
Check IP Address: Run hostname -I to confirm the device's IP.

Check Flask Service:

Bash

sudo systemctl status guide-web
4. System Sluggishness
First Run: The system builds search indices and caches during the first few queries. Performance improves after 5-10 minutes of uptime.

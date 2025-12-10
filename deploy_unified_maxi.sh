#!/bin/bash
# deploy_unified_maxi.sh
# -----------------------------------------------------------------------------
# THE GRAND UNIFIED HITCHHIKER'S GUIDE (MAXI EDITION)
# -----------------------------------------------------------------------------
# TARGET: Raspberry Pi Zero 2 W / Intel Debian
# DATA SOURCE: "Maxi" Wikipedia (Full Graphics)
# INTERFACES:
#   1. Web: Retro Guide (Text/AI)
#   2. Web: Wikipedia Mirror (Full Graphics)
#   3. Console: Terminal Client (Text/AI) - For hardware displays
# -----------------------------------------------------------------------------

set -e

# --- CONFIGURATION ---
INSTALL_DIR="$HOME/theguide"
DATA_DIR="$INSTALL_DIR/data"
BIN_DIR="$INSTALL_DIR/bin"
VENV_DIR="$INSTALL_DIR/venv"
TEMPLATE_DIR="$INSTALL_DIR/templates"

# Ports
PORT_KIWIX=9095
PORT_WEB=80
PORT_AI=8080

# --- ASSETS (UPDATED FOR MAXI) ---
# We use a generic link name so the code always finds it
ZIM_LINK_NAME="wikipedia_maxi.zim"
ZIM_PATH="$DATA_DIR/$ZIM_LINK_NAME"

# Target: The Full "Maxi" Version (~100GB)
ZIM_PATTERN="wikipedia_en_all_maxi" 
ZIM_BASE_URL="https://download.kiwix.org/zim/wikipedia/"

# AI Model (Qwen 0.5B - Optimized for 512MB RAM)
MODEL_URL="https://huggingface.co/Qwen/Qwen2-0.5B-Instruct-GGUF/resolve/main/qwen2-0_5b-instruct-q4_k_m.gguf"
MODEL_PATH="$DATA_DIR/model.gguf"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${YELLOW}[GUIDE]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; }
info() { echo -e "${CYAN}$1${NC}"; }

# --- 1. PRELIMINARY CHECKS ---
ARCH=$(uname -m)
log "Detected Architecture: $ARCH"

if [[ "$ARCH" == "x86_64" ]]; then
    KIWIX_URL="https://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-x86_64-3.7.0.tar.gz"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    KIWIX_URL="https://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-aarch64-3.7.0.tar.gz"
else
    error "Unsupported architecture: $ARCH"
    exit 1
fi

mkdir -p "$INSTALL_DIR" "$DATA_DIR" "$BIN_DIR" "$TEMPLATE_DIR"

# --- 2. SWAP CONFIGURATION (CRITICAL FOR PI) ---
log "Checking Swap Configuration..."
TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
if [ "$TOTAL_MEM" -lt 2000000 ]; then
    log "Low RAM detected. Ensuring 4GB Swap exists..."
    if [ ! -f /swapfile_guide ]; then
        sudo fallocate -l 4G /swapfile_guide
        sudo chmod 600 /swapfile_guide
        sudo mkswap /swapfile_guide
        sudo swapon /swapfile_guide
        echo "/swapfile_guide none swap sw 0 0" | sudo tee -a /etc/fstab
        success "Swap created."
    else
        log "Swap already exists."
    fi
fi

# --- 3. DEPENDENCIES ---
log "Installing System Dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq git build-essential python3-pip python3-venv libzim-dev curl wget libcurl4-openssl-dev zsync cmake net-tools

# --- 4. INSTALL KIWIX ---
if [ ! -f "$BIN_DIR/kiwix-serve" ]; then
    log "Installing Kiwix Tools..."
    curl -L -k -o kiwix.tar.gz "$KIWIX_URL"
    tar -xzf kiwix.tar.gz -C "$BIN_DIR" --strip-components=1
    rm kiwix.tar.gz
    success "Kiwix Installed."
fi

# --- 5. COMPILE AI ENGINE (LLAMA.CPP) ---
if [ ! -f "$BIN_DIR/llama-server" ]; then
    log "Compiling AI Engine (This takes time)..."
    if [ ! -d "$INSTALL_DIR/llama.cpp" ]; then
        git clone https://github.com/ggerganov/llama.cpp "$INSTALL_DIR/llama.cpp"
    fi
    cd "$INSTALL_DIR/llama.cpp"
    mkdir -p build && cd build
    cmake .. -DGGML_NATIVE=OFF
    cmake --build . --config Release -j$(nproc)
    find . -name "llama-server" -type f -exec cp {} "$BIN_DIR/" \; -quit
    cd "$INSTALL_DIR"
    success "AI Engine Compiled."
else
    log "AI Engine already exists."
fi

# --- 6. ASSET MANAGEMENT (INTERACTIVE) ---

# 6a. AI Model
if [ ! -f "$MODEL_PATH" ]; then
    log "Downloading AI Brain (Qwen 0.5B)..."
    curl -L -o "$MODEL_PATH" "$MODEL_URL"
fi

# 6b. Wikipedia ZIM File (MAXI VERSION)
echo ""
echo "------------------------------------------------------------------"
echo "   MAXI DATABASE SETUP (IMAGES + TEXT)"
echo "------------------------------------------------------------------"
if [ -f "$ZIM_PATH" ]; then
    success "Database found: $ZIM_PATH"
else
    info "The Wikipedia database is missing."
    echo "1) Download MAXI version from Internet (Warning: ~100GB)"
    echo "2) I have the file locally (Upload via SCP/SFTP)"
    read -p "Select option [1/2]: " choice

    if [ "$choice" == "1" ]; then
        log "Resolving latest ZIM URL for $ZIM_PATTERN..."
        LATEST_ZIM=$(curl -s -k "$ZIM_BASE_URL" | grep -o "${ZIM_PATTERN}_[0-9]\{4\}-[0-9]\{2\}\.zim" | sort | tail -n 1)
        if [ -z "$LATEST_ZIM" ]; then
            error "Could not resolve ZIM URL. Check internet connection."
            exit 1
        fi
        FULL_URL="${ZIM_BASE_URL}${LATEST_ZIM}"
        
        log "Downloading: $LATEST_ZIM"
        if command -v zsync >/dev/null; then
            zsync -o "$ZIM_PATH" "${FULL_URL}.zsync" || curl -L -C - -o "$ZIM_PATH" "$FULL_URL"
        else
            curl -L -C - -o "$ZIM_PATH" "$FULL_URL"
        fi

    elif [ "$choice" == "2" ]; then
        HOST_IP=$(hostname -I | awk '{print $1}')
        USER_NAME=$(whoami)
        
        echo ""
        info "PAUSED FOR UPLOAD"
        echo "Please upload your 'wikipedia_maxi.zim' file to this machine."
        echo "Target Path: $ZIM_PATH"
        echo ""
        echo "--- Command to run on your PC/Mac ---"
        echo "scp /path/to/your/wikipedia_maxi.zim $USER_NAME@$HOST_IP:$ZIM_PATH"
        echo "-------------------------------------"
        echo ""
        
        while [ ! -f "$ZIM_PATH" ]; do
            read -p "Press [Enter] once the upload is complete..."
            if [ -f "$ZIM_PATH" ]; then
                success "File detected!"
                break
            else
                error "File not found at $ZIM_PATH. Please try again."
            fi
        done
    else
        error "Invalid selection. Exiting."
        exit 1
    fi
fi

# --- 7. SOFTWARE GENERATION ---

log "Generating Software Stack..."

# 7a. Python Web App (Flask)
# Handles the Browser Interface
cat <<EOF > "$INSTALL_DIR/app.py"
import requests
from flask import Flask, render_template, request, jsonify
from bs4 import BeautifulSoup

app = Flask(__name__)

KIWIX_URL = "http://localhost:$PORT_KIWIX"
AI_URL = "http://localhost:$PORT_AI"

# --- HELPER: STRIP GRAPHICS FOR AI ---
def clean_wiki_text(html_content):
    soup = BeautifulSoup(html_content, 'html.parser')
    # Aggressively strip images, tables, scripts for the AI/Text context
    for s in soup(['script', 'style', 'table', 'sup', 'img', 'figure']): s.extract()
    text = soup.get_text(separator=' ', strip=True)
    return text[:2500] 

@app.route('/')
def index():
    # The 'Maxi' Reader Interface (Graphics Enabled)
    return render_template('maxi_index.html')

@app.route('/retro')
def retro_guide():
    # The 'Guide' Interface (Text Only)
    return render_template('retro_guide.html')

@app.route('/api/search')
def api_search():
    query = request.args.get('pattern', '')
    try:
        resp = requests.get(f"{KIWIX_URL}/search?pattern={query}", timeout=5)
        soup = BeautifulSoup(resp.content, 'html.parser')
        results = []
        for a in soup.find_all('a', href=True):
            if '/A/' in a['href'] or '/content/' in a['href']:
                results.append({'title': a.get_text().strip(), 'path': a['href']})
                if len(results) > 10: break
        return jsonify(results)
    except Exception as e:
        return jsonify({'error': str(e)})

@app.route('/api/ai_guide', methods=['POST'])
def api_ai_guide():
    data = request.json
    path = data.get('path')
    query = data.get('query')
    try:
        wiki_resp = requests.get(f"{KIWIX_URL}{path}")
        # Clean text for AI processing
        context = clean_wiki_text(wiki_resp.content)
    except:
        return jsonify({'text': 'Error accessing internal archive.'})

    prompt = f"<|im_start|>user\\nBased on this text: {context}\\n\\nWrite a cynical, funny, Hitchhiker's Guide entry for '{query}'. Keep it under 100 words.<|im_end|>\\n<|im_start|>assistant\\n"

    try:
        ai_payload = {"prompt": prompt, "n_predict": 128, "temperature": 0.8, "stream": False}
        ai_resp = requests.post(f"{AI_URL}/completion", json=ai_payload, timeout=60)
        return jsonify({'text': ai_resp.json().get('content', 'No Data.')})
    except:
        return jsonify({'text': 'Deep Thought is offline.'})

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=$PORT_WEB)
EOF

# 7b. Console Client (Python)
# Handles the "Histplat" / Hardware Display Interface
cat <<EOF > "$INSTALL_DIR/console_guide.py"
import requests
import sys
import textwrap
import shutil
import json
from bs4 import BeautifulSoup

KIWIX_URL = "http://localhost:$PORT_KIWIX"
AI_URL = "http://localhost:$PORT_AI"

def clean_and_wrap(html_content):
    soup = BeautifulSoup(html_content, 'html.parser')
    for s in soup(['script', 'style', 'table', 'sup', 'img', 'figure', 'nav', 'footer']): 
        s.extract()
    text = soup.get_text(" ", strip=True)
    
    # Format for Console
    term_width = shutil.get_terminal_size((80, 20)).columns
    wrapper = textwrap.TextWrapper(width=min(term_width, 100))
    return wrapper.fill(text[:3000]) # Return first 3000 chars

def ask_ai(context, query):
    prompt = f"<|im_start|>user\\nBased on this text: {context[:2000]}\\n\\nSummarize '{query}' for a traveler (Hitchhiker style).<|im_end|>\\n<|im_start|>assistant\\n"
    data = {"prompt": prompt, "n_predict": 128, "stream": False}
    try:
        resp = requests.post(f"{AI_URL}/completion", json=data, timeout=60)
        return resp.json().get('content', '').strip()
    except:
        return "[AI Offline]"

def main():
    print("-" * 40)
    print(" THE GUIDE (CONSOLE LINK) ")
    print("-" * 40)
    
    while True:
        try:
            q = input("\nQuery > ")
            if not q: continue
            if q.lower() in ['exit', 'quit']: break
            
            # 1. Search
            print("Searching...")
            s_resp = requests.get(f"{KIWIX_URL}/search?pattern={q}")
            soup = BeautifulSoup(s_resp.content, 'html.parser')
            results = []
            for a in soup.find_all('a', href=True):
                if '/A/' in a['href'] or '/content/' in a['href']:
                    results.append({'title': a.get_text().strip(), 'href': a['href']})
                    if len(results) >= 1: break # Take top result for console simplicity
            
            if not results:
                print("Probability Zero.")
                continue
                
            target = results[0]
            print(f"Accessing: {target['title']}")
            
            # 2. Fetch & Clean
            c_resp = requests.get(f"{KIWIX_URL}{target['href']}")
            clean_text = clean_and_wrap(c_resp.content)
            
            # 3. AI Summary
            print("\nConsulting Deep Thought...")
            summary = ask_ai(clean_text, q)
            
            print("\n" + "="*40)
            print(summary)
            print("="*40 + "\n")
            
            # Optional: Print raw text if AI fails or user wants it
            # print(clean_text)

        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    main()
EOF

# 7c. Web Templates
# Retro Guide (Text Only)
cat << 'EOF' > "$TEMPLATE_DIR/retro_guide.html"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>The Guide</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Share+Tech+Mono&display=swap');
body{background:#111;color:#33ff33;font-family:'Share Tech Mono',monospace;margin:0;height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;overflow:hidden}
.case{width:95%;max-width:800px;height:80vh;border:2px solid #444;border-radius:20px;background:#222;padding:20px;display:flex;flex-direction:column;box-shadow:0 0 20px rgba(0,0,0,0.8)}
.screen{background:#000;border:4px solid #333;flex-grow:1;border-radius:10px;padding:20px;overflow-y:auto;text-transform:uppercase;text-shadow:0 0 5px #33ff33}
.input-area{margin-top:20px;display:flex;gap:10px}
input{background:#000;color:#33ff33;border:1px solid #444;padding:10px;flex-grow:1;font-size:1.2rem;text-transform:uppercase}
button{background:#440000;color:white;border:1px solid #ff0000;padding:10px 20px;cursor:pointer;font-weight:bold}
.dont-panic{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);font-size:4rem;color:#ffb000;transition:opacity 0.5s}
.hidden{opacity:0;pointer-events:none}
</style>
</head>
<body>
<div class="case">
<div class="screen" id="display"><div id="boot" class="dont-panic">DON'T PANIC</div><div id="content" style="white-space:pre-wrap;"></div></div>
<div class="input-area"><input type="text" id="query" placeholder="SEARCH..." autofocus><button onclick="runSearch()">SEARCH</button></div>
</div>
<script>
const display=document.getElementById('content');const boot=document.getElementById('boot');
async function runSearch(){
const q=document.getElementById('query').value;if(!q)return;
boot.classList.add('hidden');display.innerText="SEARCHING SUB-ETHA...";
try{
const s=await fetch(`/api/search?pattern=${q}`);const r=await s.json();
if(r.length===0){display.innerText="PROBABILITY ZERO.";return;}
display.innerText="ENTRY FOUND. CONSULTING DEEP THOUGHT...";
const a=await fetch('/api/ai_guide',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({path:r[0].path,query:q})});
const d=await a.json();
display.innerText="";let t=d.text;let i=0;function type(){if(i<t.length){display.innerText+=t.charAt(i);i++;setTimeout(type,30);}}type();
}catch(e){display.innerText="ERROR: "+e;}
}
document.getElementById('query').addEventListener('keypress',e=>{if(e.key==='Enter')runSearch()});
</script></body></html>
EOF

# Maxi Reader (Full Graphics)
cat <<EOF > "$TEMPLATE_DIR/maxi_index.html"
<!DOCTYPE html>
<html><head><title>Wiki Reader (Maxi)</title><meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font-family:sans-serif;padding:20px;background:#f0f0f0}.container{max-width:800px;margin:0 auto;background:white;padding:20px;border-radius:8px}input{width:70%;padding:10px}button{padding:10px 20px;background:#007bff;color:white;border:none}.res-item{padding:10px;border-bottom:1px solid #eee}</style>
</head><body><div class="container"><h1>Offline Wiki Archive (Graphics Enabled)</h1>
<p><a href="/retro">>> Switch to Guide Mode (Text Only)</a></p>
<div><input type="text" id="s" placeholder="Search..."><button onclick="doSearch()">Go</button></div><div id="results"></div></div>
<script>async function doSearch(){const q=document.getElementById('s').value;const r=await fetch(\`/api/search?pattern=\${q}\`);const d=await r.json();const v=document.getElementById('results');v.innerHTML='';d.forEach(i=>{v.innerHTML+=\`<div class="res-item"><a href="http://\${window.location.hostname}:$PORT_KIWIX\${i.path}" target="_blank">\${i.title}</a></div>\`});}</script></body></html>
EOF

# --- 8. VENV & SERVICES ---
log "Configuring Python Venv..."
if [ ! -d "$VENV_DIR" ]; then python3 -m venv "$VENV_DIR"; fi
source "$VENV_DIR/bin/activate"
pip install -q flask requests beautifulsoup4

log "Creating System Services..."

# 1. Kiwix Service (Serves Full Maxi ZIM)
cat <<EOF | sudo tee /etc/systemd/system/guide-kiwix.service > /dev/null
[Unit]
Description=Kiwix Wikipedia Server
After=network.target
[Service]
User=$USER
ExecStart=$BIN_DIR/kiwix-serve --port=$PORT_KIWIX --library "$DATA_DIR/library.xml"
Restart=always
[Install]
WantedBy=multi-user.target
EOF

"$BIN_DIR/kiwix-manage" "$DATA_DIR/library.xml" add "$ZIM_PATH"

# 2. AI Service
cat <<EOF | sudo tee /etc/systemd/system/guide-ai.service > /dev/null
[Unit]
Description=Guide AI Brain
After=network.target
[Service]
User=$USER
WorkingDirectory=$BIN_DIR
ExecStart=$BIN_DIR/llama-server -m "$MODEL_PATH" -c 2048 --port $PORT_AI --host 0.0.0.0
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# 3. Web Service
cat <<EOF | sudo tee /etc/systemd/system/guide-web.service > /dev/null
[Unit]
Description=Guide Web Interface
After=guide-kiwix.service guide-ai.service
[Service]
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$VENV_DIR/bin/python app.py
Restart=always
Environment="PYTHONUNBUFFERED=1"
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable guide-kiwix guide-ai guide-web
sudo systemctl restart guide-kiwix guide-ai guide-web

IP=$(hostname -I | awk '{print $1}')
echo ""
echo "------------------------------------------------------------------"
echo "   DEPLOYMENT COMPLETE"
echo "------------------------------------------------------------------"
echo "1. Wiki Reader (Images):  http://$IP"
echo "2. Retro Guide (Text):    http://$IP/retro"
echo "3. Console Client:        python3 $INSTALL_DIR/console_guide.py"
echo "------------------------------------------------------------------"

# LibreTranslate Hosting Guide for S.A.G.E

**Setup Instructions for Team Member**

This guide helps you host LibreTranslate translation service on your laptop to support the S.A.G.E smartglass backend.

---

## System Requirements

- **RAM**: 4 GB minimum, 8 GB recommended
- **Storage**: 3-5 GB free space
- **OS**: Windows 10/11, macOS, or Linux
- **Internet**: Required for initial setup and Docker image download

---

## Step 1: Install Docker Desktop

### Windows

1. Download Docker Desktop: https://www.docker.com/products/docker-desktop
2. Run the installer
3. Restart your computer when prompted
4. Open Docker Desktop and wait for it to start
5. Verify installation:
   ```powershell
   docker --version
   docker-compose --version
   ```

### macOS

1. Download Docker Desktop for Mac: https://www.docker.com/products/docker-desktop
2. Drag Docker.app to Applications folder
3. Open Docker from Applications
4. Wait for Docker to start (whale icon in menu bar)
5. Verify installation:
   ```bash
   docker --version
   docker-compose --version
   ```

### Linux (Ubuntu/Debian)

```bash
# Update package manager
sudo apt update

# Install Docker
sudo apt install docker.io docker-compose -y

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group (avoid using sudo)
sudo usermod -aG docker $USER

# Log out and log back in, then verify
docker --version
docker-compose --version
```

---

## Step 2: Create LibreTranslate Configuration

1. Create a new folder for LibreTranslate:

   ```bash
   # Windows (PowerShell)
   mkdir C:\libretranslate
   cd C:\libretranslate

   # macOS/Linux
   mkdir ~/libretranslate
   cd ~/libretranslate
   ```

2. Create a file named `docker-compose.yml` with this content:

```yaml
version: "3"
services:
  libretranslate:
    image: libretranslate/libretranslate:latest
    container_name: libretranslate
    restart: unless-stopped
    ports:
      - "5001:5000"
    environment:
      - LT_THREADS=4 # Use 4 CPU threads
      - LT_DEBUG=false # Disable debug mode for performance
      - LT_SUGGESTIONS=false # Disable suggestions to save RAM
      - LT_UPDATE_MODELS=true # Auto-update language models
    volumes:
      - libretranslate-data:/app/db # Persistent storage for models
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  libretranslate-data:
```

---

## Step 3: Start LibreTranslate Service

```bash
# From the libretranslate folder
docker-compose up -d
```

**Expected Output:**

```
Creating network "libretranslate_default" with the default driver
Creating volume "libretranslate-data" with default driver
Pulling libretranslate (libretranslate/libretranslate:latest)...
Creating libretranslate ... done
```

**First run takes 5-10 minutes** (downloading ~2GB Docker image and language models)

---

## Step 4: Verify Service is Running

### Check Docker Container Status

```bash
docker-compose ps
```

**Should show:**

```
Name                 State    Ports
------------------------------------------------
libretranslate       Up       0.0.0.0:5001->5000/tcp
```

### Test Translation API

```bash
# Windows (PowerShell)
Invoke-RestMethod -Uri "http://localhost:5001/translate" -Method POST -ContentType "application/json" -Body '{"q":"hello","source":"en","target":"es"}'

# macOS/Linux
curl -X POST http://localhost:5001/translate \
  -H "Content-Type: application/json" \
  -d '{"q":"hello","source":"en","target":"es"}'
```

**Expected Response:**

```json
{ "translatedText": "hola" }
```

### Check Available Languages

```bash
# Windows
Invoke-RestMethod -Uri "http://localhost:5001/languages"

# macOS/Linux
curl http://localhost:5001/languages
```

---

## Step 5: Make Service Accessible to Your Teammate

### Option A: Local Network Access (Same WiFi)

**1. Find Your IP Address:**

```bash
# Windows
ipconfig
# Look for "IPv4 Address" under your WiFi adapter
# Example: 192.168.1.100

# macOS
ifconfig | grep "inet "
# Example: inet 192.168.1.100

# Linux
ip addr show
# Example: inet 192.168.1.100/24
```

**2. Configure Firewall:**

```powershell
# Windows - Allow port 5001 through firewall
New-NetFirewallRule -DisplayName "LibreTranslate" -Direction Inbound -Protocol TCP -LocalPort 5001 -Action Allow
```

```bash
# Linux (Ubuntu/Debian)
sudo ufw allow 5001/tcp
sudo ufw reload
```

macOS: System Preferences → Security & Privacy → Firewall → Firewall Options → Add port 5001

**3. Provide URL to Teammate:**

```
http://YOUR_IP_ADDRESS:5001
Example: http://192.168.1.100:5001
```

---

### Option B: Internet Access via ngrok (Recommended for Remote Access)

**1. Install ngrok:**

- Download: https://ngrok.com/download
- Extract and place `ngrok` executable in your PATH

**2. Create ngrok Account (Free):**

- Sign up: https://dashboard.ngrok.com/signup
- Get your auth token from: https://dashboard.ngrok.com/get-started/your-authtoken

**3. Configure ngrok:**

```bash
ngrok config add-authtoken YOUR_AUTH_TOKEN
```

**4. Start ngrok Tunnel:**

```bash
ngrok http 5001
```

**Expected Output:**

```
Session Status                online
Account                       your@email.com
Forwarding                    https://abc123.ngrok.io -> http://localhost:5001
```

**5. Provide URL to Teammate:**

```
https://abc123.ngrok.io
```

⚠️ **Important**: Keep the ngrok terminal window open! Closing it stops the tunnel.

---

## Step 6: Provide Connection Details to Teammate

**Send this to your S.A.G.E developer:**

```
LibreTranslate Service is Ready! 🚀

URL: http://YOUR_IP:5001  (or https://abc123.ngrok.io)

Test it with:
curl -X POST YOUR_URL/translate \
  -H "Content-Type: application/json" \
  -d '{"q":"hello world","source":"en","target":"es"}'

Expected response: {"translatedText": "hola mundo"}
```

---

## Managing the Service

### View Logs

```bash
docker-compose logs -f
```

### Stop Service

```bash
docker-compose stop
```

### Start Service Again

```bash
docker-compose start
```

### Restart Service

```bash
docker-compose restart
```

### Stop and Remove Service

```bash
docker-compose down
```

### Update to Latest Version

```bash
docker-compose pull
docker-compose up -d
```

---

## Troubleshooting

### Port Already in Use

If port 5001 is already taken, edit `docker-compose.yml`:

```yaml
ports:
  - "5002:5000" # Change 5001 to 5002 or any free port
```

### High RAM Usage

If RAM usage is too high, reduce threads in `docker-compose.yml`:

```yaml
environment:
  - LT_THREADS=2 # Reduce from 4 to 2
```

### Service Won't Start

```bash
# Check Docker is running
docker ps

# View detailed logs
docker-compose logs

# Restart Docker Desktop (Windows/Mac)
# Or restart Docker service (Linux)
sudo systemctl restart docker
```

### Translation is Slow

- Close other applications to free RAM
- Increase Docker memory limit (Docker Desktop → Settings → Resources)
- Recommended: 4 GB RAM allocated to Docker

---

## Performance Tips

1. **Keep Docker Running**: Don't shut down Docker Desktop
2. **Auto-Start**: Enable "Start Docker Desktop on login" in settings
3. **Monitor Resources**: Use `docker stats libretranslate` to check CPU/RAM
4. **Persistent Data**: Models are cached in volume, subsequent restarts are fast

---

## Supported Languages (200+)

LibreTranslate supports translation between these languages:

### Major Languages

- **English** (en)
- **Spanish** (es)
- **French** (fr)
- **German** (de)
- **Italian** (it)
- **Portuguese** (pt)
- **Russian** (ru)
- **Chinese** (zh)
- **Japanese** (ja)
- **Korean** (ko)
- **Arabic** (ar)
- **Hindi** (hi)

### European Languages

- Dutch (nl)
- Polish (pl)
- Swedish (sv)
- Danish (da)
- Finnish (fi)
- Norwegian (no)
- Czech (cs)
- Greek (el)
- Hungarian (hu)
- Romanian (ro)
- Turkish (tr)
- Ukrainian (uk)

### Asian Languages

- Bengali (bn)
- Indonesian (id)
- Malay (ms)
- Thai (th)
- Vietnamese (vi)
- Filipino (fil)
- Tamil (ta)
- Telugu (te)
- Urdu (ur)

### Other Languages

- Hebrew (he)
- Persian (fa)
- Swahili (sw)
- Afrikaans (af)
- Catalan (ca)
- Croatian (hr)
- Serbian (sr)
- Slovak (sk)
- Slovenian (sl)
- Bulgarian (bg)
- Lithuanian (lt)
- Latvian (lv)
- Estonian (et)

**Full list of 200+ languages available via API:**

```bash
curl http://localhost:5001/languages
```

---

## Security Notes

- **ngrok Free Tier**: URL changes each restart, share new URL with teammate
- **ngrok Paid**: Get permanent URL ($8/month)
- **Local Network**: More secure, works only on same WiFi
- **No Authentication**: Current setup has no password (consider adding API key for production)

---

## Questions or Issues?

Contact your S.A.G.E teammate if:

- Service won't start
- URL is not accessible
- Translation returns errors
- Need help with Docker setup

---

**Setup Complete! 🎉**

Your LibreTranslate service is now running and ready to support S.A.G.E's translation features!

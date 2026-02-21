# Nellie's System Monitor

Lightweight system monitoring for the OpenClaw Raspberry Pi.

## How It Works

1. **Data Collection** (`collect.sh`): Runs every 5 minutes via cron
   - Collects: temp, memory, load, chromium processes, gateway status
   - Writes to `data.json` and `history.json`

2. **Dashboard** (`dashboard.html`): Static HTML page
   - Fetches data.json via JavaScript
   - Shows current stats + history table
   - Auto-refreshes every 30 seconds
   - Uses localStorage for history persistence

## Files

```
system-monitor/
├── collect.sh       # Data collector (cron job)
├── data.json        # Current stats
├── history.json     # Last 20 readings
├── dashboard.html   # The dashboard
├── README.md       # This file
└── encrypted/       # staticrypt output (after encryption)
```

## Quick Start

### 1. Test the collector
```bash
cd ~/Nellie/system-monitor
./collect.sh
cat data.json
```

### 2. Set up cron (already done)
```bash
crontab -l  # Should show: */5 * * * * /home/nellie/Nellie/system-monitor/collect.sh
```

## Deploying to GitHub Pages (Encrypted)

### 1. Create a private repo on GitHub
```bash
gh repo create system-monitor --private --no-clone
cd ~/Nellie/system-monitor
git init
git add .
git commit -m "Initial system monitor"
git remote add origin https://github.com/nelliebot/system-monitor.git
git push -u origin main
```

### 2. Encrypt with staticrypt
```bash
# Get the password from Annie (NEVER put it in the repo!)
# Install if needed: npm install -g staticrypt

# Encrypt the dashboard
npx staticrypt dashboard.html <PASSWORD> --output encrypted/dashboard.html

# The encrypted/ folder now contains password-protected HTML
```

### 3. Push encrypted version
```bash
git add encrypted/
git commit -m "Add encrypted dashboard"
git push
```

### 4. Enable GitHub Pages
1. Go to: https://github.com/nelliebot/system-monitor/settings/pages
2. Source: Deploy from a branch
3. Branch: main, folder: /
4. Save

### 5. Share with Annie
Send her: `https://nelliebot.github.io/system-monitor/encrypted/dashboard.html`

She enters the password (`nellie123`), and it decrypts in-browser.

### 6. Auto-Decrypt URL (Optional)
To create a URL that auto-decrypts without entering the password:

**Option A: Remember Me (Recommended)**
1. Open the dashboard
2. Enter password and check "Remember Me"
3. Future visits auto-decrypt from localStorage

**Option B: URL Fragment**
Append the password as a URL fragment (hash):
```
https://nelliebot.github.io/system-monitor/encrypted/dashboard.html#staticrypt_pwd=nellie123
```
⚠️ **Warning:** This exposes the password in the URL. Only use for personal/testing. The fragment (#...) doesn't send to the server, but it's visible in browser history.

**Option C: Generate Secure Auto-Decrypt URL**
For a production-ready auto-decrypt link, use staticrypt's `--remember` option:
```bash
npx staticrypt dashboard.html nellie123 --remember --output encrypted/dashboard.html
```
This enables auto-decrypt from localStorage on first successful login.

## Security Notes

- **NEVER commit the password** to git
- The encrypted HTML contains a bcrypt hash of the password
- Password verification happens entirely in the browser
- Even if someone gets the repo, they can't see the dashboard without the password

## Resource Usage

- **Collector**: ~0.1 CPU, runs 288x/day (negligible)
- **Dashboard**: Vanilla JS, no external dependencies, ~50KB
- **History**: Last 20 readings stored in localStorage

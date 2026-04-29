import os
import json
import requests
import threading
import datetime
from flask import Flask, request, jsonify
import discord
from discord.ext import commands

app = Flask(__name__)

# ── Environment Variables ──────────────────────────────────────────────────
GITHUB_TOKEN  = os.environ.get("GITHUB_TOKEN", "")
GIST_ID       = os.environ.get("GIST_ID", "")
ADMIN_KEY     = os.environ.get("ADMIN_KEY", "LS_ADMIN_7f8a2b9c4e1d6f3a")
CLIENT_KEY    = os.environ.get("CLIENT_KEY", "LS_CLIENT_3b5d7e9a1c4f8b2e")
DISCORD_TOKEN = os.environ.get("DISCORD_TOKEN", "")
GUILD_ID      = int(os.environ.get("GUILD_ID", "0"))
ALERT_WEBHOOK = os.environ.get("ALERT_WEBHOOK", "") # For staff notifications
# ───────────────────────────────────────────────────────────────────────────

# ── GitHub Gist helpers ────────────────────────────────────────────────────
GH_HEADERS = lambda: {"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"}

def get_file(filename):
    resp = requests.get(f"https://api.github.com/gists/{GIST_ID}", headers=GH_HEADERS(), timeout=10)
    if resp.status_code == 200:
        files = resp.json().get("files", {})
        if filename in files:
            return json.loads(files[filename]["content"])
    return {}

def save_files(file_dict):
    """file_dict = {'filename.json': content_obj, ...}"""
    gist_files = {}
    for name, content in file_dict.items():
        gist_files[name] = {"content": json.dumps(content, indent=4)}
    
    requests.patch(
        f"https://api.github.com/gists/{GIST_ID}",
        headers=GH_HEADERS(),
        json={"files": gist_files},
        timeout=10
    )

def send_alert(msg):
    if ALERT_WEBHOOK:
        try: requests.post(ALERT_WEBHOOK, json={"content": f"🚨 **LOCKSYSTEM ALERT**\n{msg}"})
        except: pass

# ── Auth helpers ───────────────────────────────────────────────────────────
def require_admin(req): return req.args.get("key") == ADMIN_KEY
def require_client(req): return req.args.get("key") in [CLIENT_KEY, ADMIN_KEY]

# ══════════════════════════════════════════════════════════════════════════
# REST API ENDPOINTS
# ══════════════════════════════════════════════════════════════════════════

@app.route("/api/status", methods=["GET"])
def get_status():
    if not require_client(request): return jsonify({"error": "Unauthorized"}), 403
    hwid = request.args.get("hwid", "")
    db = get_file("database.json")
    user = db.get(hwid, {})
    
    # Check Expiry
    status = user.get("status", "active")
    expiry = user.get("expiry_date") # ISO string or None
    if expiry and status == "active":
        exp_date = datetime.datetime.fromisoformat(expiry)
        if datetime.datetime.utcnow() > exp_date:
            status = "expired"

    return jsonify({
        "status":         status,
        "uses_remaining": user.get("uses_remaining", -1),
        "username":       user.get("username", "Unknown"),
        "expiry_date":    expiry
    })

@app.route("/api/use", methods=["POST"])
def record_use():
    if not require_client(request): return jsonify({"error": "Unauthorized"}), 403
    hwid = request.args.get("hwid", "")
    db = get_file("database.json")
    user = db.get(hwid)
    if not user: return jsonify({"error": "User not found"}), 404
    
    uses = user.get("uses_remaining", -1)
    if uses == 0:
        user["status"] = "suspended"
        save_files({"database.json": db})
        return jsonify({"status": "suspended", "uses_remaining": 0})
    
    if uses > 0:
        uses -= 1
        user["uses_remaining"] = uses
        if uses == 0: user["status"] = "suspended"
        save_files({"database.json": db})
        if uses == 0: send_alert(f"User **{user['username']}** exhausted all uses.")
    
    return jsonify({"status": "ok", "uses_remaining": uses})

@app.route("/api/report_leak", methods=["POST"])
def report_leak():
    if not require_client(request): return jsonify({"error": "Unauthorized"}), 403
    sender_hwid = request.args.get("sender_hwid", "")
    db = get_file("database.json")
    if sender_hwid in db:
        user = db[sender_hwid]
        user["status"] = "suspended_leak"
        save_files({"database.json": db})
        send_alert(f"🛑 **LEAK DETECTED!** Sender **{user['username']}** has been auto-suspended.")
    return jsonify({"status": "ok"})

# ── v3.0 Updates ──────────────────────────────────────────────────────────

@app.route("/api/check_update", methods=["GET"])
def check_update():
    if not require_client(request): return jsonify({"error": "Unauthorized"}), 403
    slot_id = request.args.get("slot_id", "default")
    current_ver = int(request.args.get("version", "0"))
    
    updates = get_file("updates.json")
    slot_info = updates.get(slot_id, {})
    latest_ver = slot_info.get("version", 0)
    
    if latest_ver > current_ver:
        return jsonify({
            "update_available": True,
            "version": latest_ver,
            "url": slot_info.get("url"),
            "key": slot_info.get("key") # Decryption key for update zip
        })
    return jsonify({"update_available": False})

@app.route("/api/push_update", methods=["POST"])
def push_update():
    if not require_admin(request): return jsonify({"error": "Unauthorized"}), 403
    data = request.json or {}
    slot_id = data.get("slot_id")
    
    updates = get_file("updates.json")
    updates[slot_id] = {
        "version": data.get("version"),
        "url":     data.get("url"),
        "key":     data.get("key"),
        "timestamp": datetime.datetime.utcnow().isoformat()
    }
    save_files({"updates.json": updates})
    send_alert(f"🔄 **Update Pushed!** Slot **{slot_id}** is now at version **{data.get('version')}**.")
    return jsonify({"status": "ok"})

@app.route("/api/list", methods=["GET"])
def list_users():
    if not require_admin(request): return jsonify({"error": "Unauthorized"}), 403
    return jsonify(get_file("database.json"))

@app.route("/api/update_user", methods=["POST"])
def update_user_api():
    if not require_admin(request): return jsonify({"error": "Unauthorized"}), 403
    data = request.json or {}
    hwid = data.get("hwid")
    db = get_file("database.json")
    if hwid not in db: return jsonify({"error": "User not found"}), 404
    
    if "status" in data: db[hwid]["status"] = data["status"]
    if "uses_remaining" in data: db[hwid]["uses_remaining"] = data["uses_remaining"]
    if "expiry_date" in data: db[hwid]["expiry_date"] = data["expiry_date"]
    
    save_files({"database.json": db})
    return jsonify({"status": "ok"})

@app.route("/api/add_user", methods=["POST"])
def add_user():
    if not require_admin(request): return jsonify({"error": "Unauthorized"}), 403
    data = request.json or {}
    db = get_file("database.json")
    db[data["hwid"]] = {
        "username":       data["username"],
        "status":         "active",
        "uses_remaining": data.get("uses_remaining", -1),
        "expiry_date":    data.get("expiry_date", None)
    }
    save_files({"database.json": db})
    return jsonify({"status": "ok"})

@app.route("/api/time", methods=["GET"])
def get_time():
    return jsonify({"utc_time": datetime.datetime.utcnow().isoformat()})

@app.route("/", methods=["GET"])
def health(): return jsonify({"status": "LockSystem Pro Server Online"})

# ══════════════════════════════════════════════════════════════════════════
# DISCORD BOT
# ══════════════════════════════════════════════════════════════════════════

intents = discord.Intents.default()
intents.members = True
bot = commands.Bot(command_prefix="!", intents=intents)

@bot.event
async def on_ready():
    guild = discord.Object(id=GUILD_ID)
    bot.tree.copy_global_to(guild=guild)
    await bot.tree.sync(guild=guild)
    print(f"✅ Bot ready as {bot.user}")

def find_user(db, username):
    for hwid, data in db.items():
        if data.get("username", "").lower() == username.lower(): return hwid, data
    return None, None

@bot.tree.command(name="info", description="Get info about a user")
async def slash_info(interaction: discord.Interaction, username: str):
    db = get_file("database.json")
    hwid, data = find_user(db, username)
    if not hwid:
        await interaction.response.send_message(f"❌ User `{username}` not found.")
        return
    
    expiry = data.get("expiry_date", "Never")
    if expiry and expiry != "Never":
        expiry = datetime.datetime.fromisoformat(expiry).strftime("%Y-%m-%d %H:%M")

    embed = discord.Embed(title=f"👤 User Info: {username}", color=0x00FF00)
    embed.add_field(name="HWID", value=f"`{hwid}`", inline=False)
    embed.add_field(name="Status", value=data.get("status", "active").upper(), inline=True)
    embed.add_field(name="Uses Left", value=data.get("uses_remaining", -1), inline=True)
    embed.add_field(name="Expires", value=expiry, inline=True)
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="expire", description="Set or extend user license expiration")
async def slash_expire(interaction: discord.Interaction, username: str, days: int):
    db = get_file("database.json")
    hwid, data = find_user(db, username)
    if not hwid:
        await interaction.response.send_message(f"❌ User `{username}` not found.")
        return
    
    new_date = datetime.datetime.utcnow() + datetime.timedelta(days=days)
    db[hwid]["expiry_date"] = new_date.isoformat()
    db[hwid]["status"] = "active"
    save_files({"database.json": db})
    
    await interaction.response.send_message(f"✅ **{username}** license set to expire on **{new_date.strftime('%Y-%m-%d')}** ({days} days from now).")

# ── Start Server ───────────────────────────────────────────────────────────
def run_bot():
    import asyncio
    try: asyncio.run(bot.start(DISCORD_TOKEN))
    except: pass

if __name__ == "__main__":
    threading.Thread(target=run_bot, daemon=True).start()
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)

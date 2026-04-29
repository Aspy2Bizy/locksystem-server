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
ALERT_WEBHOOK = os.environ.get("ALERT_WEBHOOK", "")
# ───────────────────────────────────────────────────────────────────────────

GH_HEADERS = lambda: {"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"}

def get_file(filename):
    resp = requests.get(f"https://api.github.com/gists/{GIST_ID}", headers=GH_HEADERS(), timeout=10)
    if resp.status_code == 200:
        files = resp.json().get("files", {})
        if filename in files: return json.loads(files[filename]["content"])
    return {}

def save_files(file_dict):
    gist_files = {name: {"content": json.dumps(content, indent=4)} for name, content in file_dict.items()}
    requests.patch(f"https://api.github.com/gists/{GIST_ID}", headers=GH_HEADERS(), json={"files": gist_files}, timeout=10)

def send_alert(msg):
    if ALERT_WEBHOOK:
        try: requests.post(ALERT_WEBHOOK, json={"content": f"🚨 **LOCKSYSTEM ALERT**\n{msg}"})
        except: pass

def require_admin(req): return req.args.get("key") == ADMIN_KEY
def require_client(req): return req.args.get("key") in [CLIENT_KEY, ADMIN_KEY]

# ══════════════════════════════════════════════════════════════════════════
# REST API (for Apps)
# ══════════════════════════════════════════════════════════════════════════

@app.route("/api/status", methods=["GET"])
def get_status():
    if not require_client(request): return jsonify({"error": "Unauthorized"}), 403
    hwid = request.args.get("hwid", "")
    db = get_file("database.json")
    user = db.get(hwid, {})
    status = user.get("status", "active")
    expiry = user.get("expiry_date")
    if expiry and status == "active":
        if datetime.datetime.utcnow() > datetime.datetime.fromisoformat(expiry): status = "expired"
    return jsonify({"status": status, "uses_remaining": user.get("uses_remaining", -1), "username": user.get("username", "Unknown"), "expiry_date": expiry})

@app.route("/api/use", methods=["POST"])
def record_use():
    if not require_client(request): return jsonify({"error": "Unauthorized"}), 403
    hwid = request.args.get("hwid", ""); db = get_file("database.json"); user = db.get(hwid)
    if not user: return jsonify({"error": "Not found"}), 404
    uses = user.get("uses_remaining", -1)
    if uses > 0:
        uses -= 1; user["uses_remaining"] = uses
        if uses == 0: user["status"] = "suspended"; send_alert(f"User **{user['username']}** out of uses.")
        save_files({"database.json": db})
    return jsonify({"status": "ok", "uses_remaining": uses})

@app.route("/api/report_leak", methods=["POST"])
def report_leak():
    if not require_client(request): return jsonify({"error": "Unauthorized"}), 403
    sender_hwid = request.args.get("sender_hwid", "")
    db = get_file("database.json")
    if sender_hwid in db:
        db[sender_hwid]["status"] = "suspended_leak"
        save_files({"database.json": db})
        send_alert(f"🛑 **LEAK!** Sender **{db[sender_hwid]['username']}** auto-suspended.")
    return jsonify({"status": "ok"})

@app.route("/api/check_update", methods=["GET"])
def check_update():
    if not require_client(request): return jsonify({"error": "Unauthorized"}), 403
    slot_id = request.args.get("slot_id", "default"); current_ver = int(request.args.get("version", "0"))
    updates = get_file("updates.json"); slot_info = updates.get(slot_id, {})
    if slot_info.get("version", 0) > current_ver:
        return jsonify({"update_available": True, "version": slot_info["version"], "url": slot_info["url"], "key": slot_info["key"]})
    return jsonify({"update_available": False})

@app.route("/api/push_update", methods=["POST"])
def push_update():
    if not require_admin(request): return jsonify({"error": "Unauthorized"}), 403
    data = request.json or {}; updates = get_file("updates.json")
    updates[data["slot_id"]] = {"version": data["version"], "url": data["url"], "key": data["key"], "timestamp": datetime.datetime.utcnow().isoformat()}
    save_files({"updates.json": updates}); send_alert(f"🔄 **Update!** Slot **{data['slot_id']}** v{data['version']}.")
    return jsonify({"status": "ok"})

@app.route("/api/list", methods=["GET"])
def list_users_api():
    if not require_admin(request): return jsonify({"error": "Unauthorized"}), 403
    return jsonify(get_file("database.json"))

@app.route("/api/update_user", methods=["POST"])
def update_user_api():
    if not require_admin(request): return jsonify({"error": "Unauthorized"}), 403
    data = request.json or {}; hwid = data.get("hwid"); db = get_file("database.json")
    if hwid in db:
        for k in ["status", "uses_remaining", "expiry_date"]:
            if k in data: db[hwid][k] = data[k]
        save_files({"database.json": db})
    return jsonify({"status": "ok"})

@app.route("/api/add_user", methods=["POST"])
def add_user():
    if not require_admin(request): return jsonify({"error": "Unauthorized"}), 403
    data = request.json or {}; db = get_file("database.json")
    db[data["hwid"]] = {"username": data["username"], "status": "active", "uses_remaining": data.get("uses_remaining", -1), "expiry_date": data.get("expiry_date", None)}
    save_files({"database.json": db})
    return jsonify({"status": "ok"})

@app.route("/", methods=["GET"])
def health(): return jsonify({"status": "LockSystem Pro Online"})

# ══════════════════════════════════════════════════════════════════════════
# DISCORD BOT
# ══════════════════════════════════════════════════════════════════════════

intents = discord.Intents.default(); intents.members = True
bot = commands.Bot(command_prefix="!", intents=intents)

@bot.event
async def on_ready():
    if GUILD_ID > 0:
        guild = discord.Object(id=GUILD_ID)
        bot.tree.copy_global_to(guild=guild)
        await bot.tree.sync(guild=guild)
    print(f"✅ Bot ready as {bot.user}")

def find_user(db, username):
    for hwid, data in db.items():
        if data.get("username", "").lower() == username.lower(): return hwid, data
    return None, None

@bot.tree.command(name="list", description="List all licensed users")
async def slash_list(interaction: discord.Interaction):
    db = get_file("database.json")
    embed = discord.Embed(title="📋 User Database", color=0x00FF00)
    for hwid, d in db.items():
        u = d.get("uses_remaining", -1); u_str = "∞" if u == -1 else str(u)
        embed.add_field(name=d.get("username", "???"), value=f"Status: {d.get('status','active')}\nUses: {u_str}", inline=True)
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="info", description="Detailed user info")
async def slash_info(interaction: discord.Interaction, username: str):
    db = get_file("database.json"); hwid, data = find_user(db, username)
    if not hwid: return await interaction.response.send_message(f"❌ User `{username}` not found.")
    expiry = data.get("expiry_date", "Never")
    if expiry != "Never": expiry = datetime.datetime.fromisoformat(expiry).strftime("%Y-%m-%d")
    embed = discord.Embed(title=f"👤 {username}", color=0x00FF00)
    embed.add_field(name="HWID", value=f"`{hwid}`", inline=False)
    embed.add_field(name="Status", value=data.get("status","active").upper(), inline=True)
    embed.add_field(name="Expires", value=expiry, inline=True)
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="ban", description="Ban a user (Self-destruct)")
async def slash_ban(interaction: discord.Interaction, username: str):
    db = get_file("database.json"); hwid, data = find_user(db, username)
    if hwid: 
        db[hwid]["status"] = "banned"; save_files({"database.json": db})
        await interaction.response.send_message(f"🔴 **{username}** BANNED.")
    else: await interaction.response.send_message("User not found.")

@bot.tree.command(name="suspend", description="Suspend a user")
async def slash_suspend(interaction: discord.Interaction, username: str):
    db = get_file("database.json"); hwid, data = find_user(db, username)
    if hwid:
        db[hwid]["status"] = "suspended"; save_files({"database.json": db})
        await interaction.response.send_message(f"🟠 **{username}** SUSPENDED.")
    else: await interaction.response.send_message("User not found.")

@bot.tree.command(name="activate", description="Activate a user")
async def slash_activate(interaction: discord.Interaction, username: str):
    db = get_file("database.json"); hwid, data = find_user(db, username)
    if hwid:
        db[hwid]["status"] = "active"; save_files({"database.json": db})
        await interaction.response.send_message(f"🟢 **{username}** ACTIVATED.")
    else: await interaction.response.send_message("User not found.")

@bot.tree.command(name="expire", description="Set expiry (in days)")
async def slash_expire(interaction: discord.Interaction, username: str, days: int):
    db = get_file("database.json"); hwid, data = find_user(db, username)
    if hwid:
        new_date = datetime.datetime.utcnow() + datetime.timedelta(days=days)
        db[hwid]["expiry_date"] = new_date.isoformat(); db[hwid]["status"] = "active"
        save_files({"database.json": db})
        await interaction.response.send_message(f"📅 **{username}** set to expire: {new_date.strftime('%Y-%m-%d')}")
    else: await interaction.response.send_message("User not found.")

def run_bot():
    import asyncio
    try: asyncio.run(bot.start(DISCORD_TOKEN))
    except: pass

if __name__ == "__main__":
    threading.Thread(target=run_bot, daemon=True).start()
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))

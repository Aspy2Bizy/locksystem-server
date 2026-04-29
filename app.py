import os
import json
import requests
import threading
from flask import Flask, request, jsonify
import discord
from discord.ext import commands

app = Flask(__name__)

# ── Environment Variables (set these in Render dashboard) ──────────────────
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")
GIST_ID      = os.environ.get("GIST_ID", "")
ADMIN_KEY    = os.environ.get("ADMIN_KEY", "LS_ADMIN_7f8a2b9c4e1d6f3a")
CLIENT_KEY   = os.environ.get("CLIENT_KEY", "LS_CLIENT_3b5d7e9a1c4f8b2e")
DISCORD_TOKEN = os.environ.get("DISCORD_TOKEN", "")
GUILD_ID     = int(os.environ.get("GUILD_ID", "1497175637734199417"))
# ───────────────────────────────────────────────────────────────────────────

# ── GitHub Gist helpers ────────────────────────────────────────────────────
GH_HEADERS = lambda: {"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"}

def get_db():
    resp = requests.get(f"https://api.github.com/gists/{GIST_ID}", headers=GH_HEADERS(), timeout=10)
    if resp.status_code == 200:
        files = resp.json().get("files", {})
        if "database.json" in files:
            return json.loads(files["database.json"]["content"])
    return {}

def save_db(db):
    requests.patch(
        f"https://api.github.com/gists/{GIST_ID}",
        headers=GH_HEADERS(),
        json={"files": {"database.json": {"content": json.dumps(db, indent=4)}}},
        timeout=10
    )

# ── Auth helpers ───────────────────────────────────────────────────────────
def require_admin(req):
    return req.args.get("key") == ADMIN_KEY

def require_client(req):
    return req.args.get("key") in [CLIENT_KEY, ADMIN_KEY]

# ══════════════════════════════════════════════════════════════════════════
# REST API ENDPOINTS
# ══════════════════════════════════════════════════════════════════════════

@app.route("/api/status", methods=["GET"])
def get_status():
    if not require_client(request):
        return jsonify({"error": "Unauthorized"}), 403
    hwid = request.args.get("hwid", "")
    db = get_db()
    user = db.get(hwid, {})
    return jsonify({
        "status":         user.get("status", "active"),
        "uses_remaining": user.get("uses_remaining", -1),  # -1 = infinite
        "username":       user.get("username", "Unknown")
    })

@app.route("/api/use", methods=["POST"])
def record_use():
    """Called by customer program when START button is pressed."""
    if not require_client(request):
        return jsonify({"error": "Unauthorized"}), 403
    hwid = request.args.get("hwid", "")
    db = get_db()
    user = db.get(hwid)
    if not user:
        return jsonify({"error": "User not found"}), 404
    uses = user.get("uses_remaining", -1)
    if uses == -1:          # Infinite
        return jsonify({"status": "ok", "uses_remaining": -1})
    if uses <= 0:           # Already exhausted
        user["status"] = "suspended"
        db[hwid] = user
        save_db(db)
        return jsonify({"status": "suspended", "uses_remaining": 0})
    # Decrement
    uses -= 1
    user["uses_remaining"] = uses
    if uses == 0:
        user["status"] = "suspended"
    db[hwid] = user
    save_db(db)
    return jsonify({"status": "ok", "uses_remaining": uses})

@app.route("/api/report_leak", methods=["POST"])
def report_leak():
    """Auto-suspends the sender when a leak is detected on an unauthorized machine."""
    if not require_client(request):
        return jsonify({"error": "Unauthorized"}), 403
    sender_hwid = request.args.get("sender_hwid", "")
    db = get_db()
    if sender_hwid in db:
        db[sender_hwid]["status"] = "suspended_leak"
        save_db(db)
    return jsonify({"status": "ok"})

@app.route("/api/list", methods=["GET"])
def list_users():
    if not require_admin(request):
        return jsonify({"error": "Unauthorized"}), 403
    return jsonify(get_db())

@app.route("/api/update", methods=["POST"])
def update_user():
    if not require_admin(request):
        return jsonify({"error": "Unauthorized"}), 403
    data = request.json or {}
    hwid = data.get("hwid")
    db = get_db()
    if hwid not in db:
        return jsonify({"error": "User not found"}), 404
    if "status" in data:
        db[hwid]["status"] = data["status"]
    if "uses_remaining" in data:
        db[hwid]["uses_remaining"] = data["uses_remaining"]
        if data["uses_remaining"] != 0 and db[hwid].get("status") == "suspended":
            db[hwid]["status"] = "active"
    save_db(db)
    return jsonify({"status": "ok"})

@app.route("/api/add_user", methods=["POST"])
def add_user():
    if not require_admin(request):
        return jsonify({"error": "Unauthorized"}), 403
    data = request.json or {}
    db = get_db()
    db[data["hwid"]] = {
        "username":       data["username"],
        "status":         "active",
        "uses_remaining": data.get("uses_remaining", -1)
    }
    save_db(db)
    return jsonify({"status": "ok"})

@app.route("/", methods=["GET"])
def health():
    return jsonify({"status": "LockSystem Server Online"})

# ══════════════════════════════════════════════════════════════════════════
# DISCORD BOT
# ══════════════════════════════════════════════════════════════════════════

intents = discord.Intents.default()
bot = commands.Bot(command_prefix="!", intents=intents)

def fmt_user(username, status, uses):
    icon = "🟢" if status == "active" else ("🟠" if "suspend" in status else "🔴")
    uses_str = "∞" if uses == -1 else str(uses)
    reason = " (leaked)" if status == "suspended_leak" else ""
    return f"{icon} **{username}** — {status.upper()}{reason} | Uses: {uses_str}"

def find_user(db, username):
    for hwid, data in db.items():
        if data.get("username", "").lower() == username.lower():
            return hwid, data
    return None, None

@bot.event
async def on_ready():
    guild = discord.Object(id=GUILD_ID)
    bot.tree.copy_global_to(guild=guild)
    await bot.tree.sync(guild=guild)
    print(f"✅ Bot ready as {bot.user}")

@bot.tree.command(name="list", description="List all licensed users")
async def slash_list(interaction: discord.Interaction):
    db = get_db()
    if not db:
        await interaction.response.send_message("No users in database.")
        return
    embed = discord.Embed(title="📋 User Database", color=0x00FF00)
    for hwid, data in list(db.items()):
        uses = data.get("uses_remaining", -1)
        status = data.get("status", "active")
        embed.add_field(name=data.get("username", "Unknown"), value=f"Status: {status}\nUses: {'∞' if uses == -1 else uses}", inline=True)
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="search", description="Search for a user by username")
async def slash_search(interaction: discord.Interaction, username: str):
    db = get_db()
    matches = [(hwid, d) for hwid, d in db.items() if username.lower() in d.get("username", "").lower()]
    if not matches:
        await interaction.response.send_message(f"❌ No users matching `{username}`.")
        return
    embed = discord.Embed(title=f"🔍 Search: {username}", color=0x00FFFF)
    for hwid, data in matches:
        uses = data.get("uses_remaining", -1)
        embed.add_field(name=data.get("username"), value=f"Status: {data.get('status','active')}\nUses: {'∞' if uses == -1 else uses}", inline=True)
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="ban", description="Ban a user (their file will self-destruct)")
async def slash_ban(interaction: discord.Interaction, username: str):
    db = get_db()
    hwid, data = find_user(db, username)
    if not hwid:
        await interaction.response.send_message(f"❌ User `{username}` not found.")
        return
    db[hwid]["status"] = "banned"
    save_db(db)
    await interaction.response.send_message(f"🔴 **{username}** BANNED. File self-destructs on next open.")

@bot.tree.command(name="suspend", description="Suspend a user (file locked, not deleted)")
async def slash_suspend(interaction: discord.Interaction, username: str):
    db = get_db()
    hwid, data = find_user(db, username)
    if not hwid:
        await interaction.response.send_message(f"❌ User `{username}` not found.")
        return
    db[hwid]["status"] = "suspended"
    save_db(db)
    await interaction.response.send_message(f"🟠 **{username}** SUSPENDED.")

@bot.tree.command(name="activate", description="Activate/unban a user")
async def slash_activate(interaction: discord.Interaction, username: str):
    db = get_db()
    hwid, data = find_user(db, username)
    if not hwid:
        await interaction.response.send_message(f"❌ User `{username}` not found.")
        return
    db[hwid]["status"] = "active"
    save_db(db)
    await interaction.response.send_message(f"🟢 **{username}** ACTIVATED.")

@bot.tree.command(name="uses", description="Set the number of uses for a user (-1 = infinite)")
async def slash_uses(interaction: discord.Interaction, username: str, amount: int):
    db = get_db()
    hwid, data = find_user(db, username)
    if not hwid:
        await interaction.response.send_message(f"❌ User `{username}` not found.")
        return
    db[hwid]["uses_remaining"] = amount
    if amount != 0 and db[hwid].get("status") in ["suspended"]:
        db[hwid]["status"] = "active"
    save_db(db)
    uses_str = "∞" if amount == -1 else str(amount)
    await interaction.response.send_message(f"✅ **{username}** uses set to **{uses_str}**.")

# ── Start both Flask and Discord bot ──────────────────────────────────────
def run_bot():
    import asyncio
    asyncio.run(bot.start(DISCORD_TOKEN))

if __name__ == "__main__":
    bot_thread = threading.Thread(target=run_bot, daemon=True)
    bot_thread.start()
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)

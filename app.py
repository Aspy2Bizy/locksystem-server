import os
import json
import requests
import threading
import datetime
from flask import Flask, request, jsonify
from dotenv import load_dotenv
import discord
from discord.ext import commands
from discord import ui

load_dotenv()
app = Flask(__name__)

GITHUB_TOKEN  = os.environ.get("GITHUB_TOKEN", "")
GIST_ID       = os.environ.get("GIST_ID", "")
DISCORD_TOKEN = os.environ.get("DISCORD_TOKEN", "")
GUILD_ID      = int(os.environ.get("GUILD_ID", "0"))
ALERT_WEBHOOK = os.environ.get("ALERT_WEBHOOK", "")

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

@app.route("/api/status", methods=["GET"])
def get_status():
    hwid = request.args.get("hwid", ""); db = get_file("database.json"); user = db.get(hwid, {})
    if not user: return jsonify({"status": "unauthorized"}), 404
    return jsonify({"status": user.get("status", "active"), "username": user.get("username", "Unknown"), "uses": user.get("uses_remaining", -1)})

@app.route("/api/report_unauthorized", methods=["POST"])
def report_unauthorized():
    hwid = request.args.get("hwid", ""); warnings = get_file("warnings.json")
    if hwid not in warnings:
        warnings[hwid] = {"timestamp": datetime.datetime.utcnow().isoformat(), "ip": request.remote_addr}
        save_files({"warnings.json": warnings})
        send_alert(f"⚠️ **INTRUDER DETECTED!** HWID: {hwid} attempted access.")
    return jsonify({"status": "reported"})

@app.route("/api/use", methods=["POST"])
def record_use():
    hwid = request.args.get("hwid", ""); db = get_file("database.json"); user = db.get(hwid)
    if not user: return jsonify({"error": "Not found"}), 404
    uses = user.get("uses_remaining", -1)
    if uses > 0:
        uses -= 1; user["uses_remaining"] = uses
        if uses == 0: user["status"] = "suspended"; send_alert(f"User **{user['username']}** out of uses.")
        save_files({"database.json": db})
    return jsonify({"status": "ok", "uses_remaining": uses})

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
    print("✅ Bot ready")

@bot.tree.command(name="warnings", description="⚠️ List unauthorized access attempts")
async def slash_warnings(interaction: discord.Interaction):
    w = get_file("warnings.json"); embed = discord.Embed(title="⚠️ Warning List", color=0xFF0000)
    for hwid, d in w.items(): embed.add_field(name=f"HWID: {hwid[:15]}...", value=f"Time: {d['timestamp']}", inline=False)
    await interaction.response.send_message(embed=embed)

# ... (All other commands remain the same) ...
# (Including /search_user, /mass_ban, etc.)
# ...
def find_user(db, username):
    for hwid, data in db.items():
        if data.get("username", "").lower() == username.lower(): return hwid, data
    return None, None

@bot.tree.command(name="search_user", description="🔍 Search by username")
async def slash_suser(interaction: discord.Interaction, username: str):
    db = get_file("database.json"); h, d = find_user(db, username)
    if not h: return await interaction.response.send_message("❌ Not found.")
    u = "∞" if d.get('uses_remaining', -1) == -1 else str(d['uses_remaining'])
    await interaction.response.send_message(f"👤 **User:** {username}\n🆔 **HWID:** {h}\n🏷️ **Status:** {d['status']}\n🔢 **Uses:** {u}")

@bot.tree.command(name="mass_ban", description="☢️ NUCLEAR: Ban ALL")
async def slash_mban(interaction: discord.Interaction, password: str):
    if password != "AleRub08": return await interaction.response.send_message("❌ Denied.", ephemeral=True)
    async def do_ban(it):
        db = get_file("database.json")
        for h in db:
            if "pre_mass" not in db[h]: db[h]["pre_mass"] = db[h]["status"]
            db[h]["status"] = "banned"
        save_files({"database.json": db}); await it.response.edit_message(content="☢️ **MASS BAN COMPLETE.**", view=None)
    await interaction.response.send_message("⚠️ **CONFIRM MASS BAN?**", view=ConfirmAction(do_ban), ephemeral=True)

class ConfirmAction(ui.View):
    def __init__(self, callback_func):
        super().__init__(timeout=30)
        self.callback_func = callback_func
    @ui.button(label="⚠️ CONFIRM ACTION ⚠️", style=discord.ButtonStyle.danger)
    async def confirm(self, interaction: discord.Interaction, button: ui.Button):
        await self.callback_func(interaction); self.stop()

def run_bot():
    import asyncio
    try: asyncio.run(bot.start(DISCORD_TOKEN))
    except: pass

if __name__ == "__main__":
    threading.Thread(target=run_bot, daemon=True).start()
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
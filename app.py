import os
import json
import requests
import threading
import datetime
from flask import Flask, request, jsonify
from dotenv import load_dotenv
import discord
from discord.ext import commands

load_dotenv()
app = Flask(__name__)

GITHUB_TOKEN  = os.environ.get("GITHUB_TOKEN", "")
GIST_ID       = os.environ.get("GIST_ID", "")
ADMIN_KEY     = os.environ.get("ADMIN_KEY", "LS_ADMIN_7f8a2b9c4e1d6f3a")
CLIENT_KEY    = os.environ.get("CLIENT_KEY", "LS_CLIENT_3b5d7e9a1c4f8b2e")
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
    status = user.get("status", "active")
    return jsonify({"status": status, "username": user.get("username", "Unknown")})

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

@bot.tree.command(name="search_hwid", description="🔍 Search user by HWID")
async def slash_search(interaction: discord.Interaction, hwid: str):
    db = get_file("database.json"); user = db.get(hwid)
    if not user: return await interaction.response.send_message("❌ HWID not found.")
    await interaction.response.send_message(f"👤 **User:** {user['username']}\n🏷️ **Status:** {user['status']}")

@bot.tree.command(name="mass_ban", description="☢️ NUCLEAR: Ban ALL users")
async def slash_mass_ban(interaction: discord.Interaction, password: str):
    if password != "AleRub08": return await interaction.response.send_message("❌ Forbidden.", ephemeral=True)
    db = get_file("database.json")
    for h in db:
        if "pre_mass" not in db[h]: db[h]["pre_mass"] = db[h]["status"]
        db[h]["status"] = "banned"
    save_files({"database.json": db}); send_alert("☢️ **MASS BAN** executed."); await interaction.response.send_message("☢️ All users restricted.")

@bot.tree.command(name="mass_unban", description="🔓 Restore users from mass ban")
async def slash_mass_unban(interaction: discord.Interaction, password: str):
    if password != "AleRub08": return await interaction.response.send_message("❌ Forbidden.", ephemeral=True)
    db = get_file("database.json")
    for h in db:
        if db[h].get("pre_mass") == "active": db[h]["status"] = "active"
        if "pre_mass" in db[h]: del db[h]["pre_mass"]
    save_files({"database.json": db}); await interaction.response.send_message("🔓 Restored active users.")

@bot.tree.command(name="mass_suspend", description="🟠 Suspend ALL users")
async def slash_mass_suspend(interaction: discord.Interaction):
    db = get_file("database.json")
    for h in db:
        if "pre_mass" not in db[h]: db[h]["pre_mass"] = db[h]["status"]
        db[h]["status"] = "suspended"
    save_files({"database.json": db}); await interaction.response.send_message("🟠 All users suspended.")

@bot.tree.command(name="mass_unsuspend", description="🟢 Unsuspend users")
async def slash_mass_unsuspend(interaction: discord.Interaction):
    db = get_file("database.json")
    for h in db:
        if db[h].get("pre_mass") == "active": db[h]["status"] = "active"
        if "pre_mass" in db[h]: del db[h]["pre_mass"]
    save_files({"database.json": db}); await interaction.response.send_message("🟢 Restored active users.")

def run_bot():
    import asyncio
    try: asyncio.run(bot.start(DISCORD_TOKEN))
    except: pass

if __name__ == "__main__":
    threading.Thread(target=run_bot, daemon=True).start()
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
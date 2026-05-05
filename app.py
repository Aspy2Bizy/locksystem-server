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

@app.route("/", methods=["GET"])
def health(): return jsonify({"status": "LockSystem Pro Online"})

@app.route("/api/status", methods=["GET"])
def get_status():
    hwid = request.args.get("hwid", ""); db = get_file("database.json"); user = db.get(hwid, {})
    return jsonify({"status": user.get("status", "active"), "username": user.get("username", "Unknown")})

# ══════════════════════════════════════════════════════════════════════════
# DISCORD BOT
# ══════════════════════════════════════════════════════════════════════════

intents = discord.Intents.default(); intents.members = True
bot = commands.Bot(command_prefix="!", intents=intents)

class ConfirmAction(ui.View):
    def __init__(self, callback_func):
        super().__init__(timeout=30)
        self.callback_func = callback_func
    @ui.button(label="⚠️ CONFIRM ACTION ⚠️", style=discord.ButtonStyle.danger)
    async def confirm(self, interaction: discord.Interaction, button: ui.Button):
        await self.callback_func(interaction); self.stop()

@bot.event
async def on_ready():
    if GUILD_ID > 0:
        guild = discord.Object(id=GUILD_ID)
        bot.tree.copy_global_to(guild=guild)
        await bot.tree.sync(guild=guild)
    print("✅ Bot ready")

def find_user(db, username):
    for hwid, data in db.items():
        if data.get("username", "").lower() == username.lower(): return hwid, data
    return None, None

# --- BASIC COMMANDS ---
@bot.tree.command(name="list", description="List users")
async def slash_list(interaction: discord.Interaction):
    db = get_file("database.json"); embed = discord.Embed(title="📋 Database", color=0x00FF00)
    for h, d in db.items(): embed.add_field(name=d['username'], value=f"Status: {d['status']}", inline=True)
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="activate", description="Activate user")
async def slash_act(interaction: discord.Interaction, username: str):
    db = get_file("database.json"); h, d = find_user(db, username)
    if h: db[h]["status"] = "active"; save_files({"database.json": db}); await interaction.response.send_message(f"🟢 {username} activated.")
    else: await interaction.response.send_message("❌ User not found.")

@bot.tree.command(name="ban", description="Ban user")
async def slash_ban(interaction: discord.Interaction, username: str):
    db = get_file("database.json"); h, d = find_user(db, username)
    if h: db[h]["status"] = "banned"; save_files({"database.json": db}); await interaction.response.send_message(f"🔴 {username} banned.")
    else: await interaction.response.send_message("❌ User not found.")

@bot.tree.command(name="search_user", description="🔍 Search by username")
async def slash_suser(interaction: discord.Interaction, username: str):
    db = get_file("database.json"); h, d = find_user(db, username)
    if not h: return await interaction.response.send_message("❌ User not found.")
    await interaction.response.send_message(f"👤 **User:** {username}\n🆔 **HWID:** {h}\n🏷️ **Status:** {d['status']}")

@bot.tree.command(name="search_hwid", description="🔍 Search by HWID")
async def slash_shwid(interaction: discord.Interaction, hwid: str):
    db = get_file("database.json"); u = db.get(hwid)
    if not u: return await interaction.response.send_message("❌ HWID not found.")
    await interaction.response.send_message(f"👤 **User:** {u['username']} | **Status:** {u['status']}")

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

@bot.tree.command(name="mass_unban", description="🔓 Restore active")
async def slash_munban(interaction: discord.Interaction, password: str):
    if password != "AleRub08": return await interaction.response.send_message("❌ Denied.", ephemeral=True)
    async def do_un(it):
        db = get_file("database.json")
        for h in db:
            if db[h].get("pre_mass") == "active": db[h]["status"] = "active"
            if "pre_mass" in db[h]: del db[h]["pre_mass"]
        save_files({"database.json": db}); await it.response.edit_message(content="🔓 Restored active users.", view=None)
    await interaction.response.send_message("❓ **RESTORE ALL USERS?**", view=ConfirmAction(do_un), ephemeral=True)

def run_bot():
    import asyncio
    try: asyncio.run(bot.start(DISCORD_TOKEN))
    except: pass

if __name__ == "__main__":
    threading.Thread(target=run_bot, daemon=True).start()
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
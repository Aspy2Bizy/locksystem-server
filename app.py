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

# ══════════════════════════════════════════════════════════════════════════
# CONFIRMATION VIEWS
# ══════════════════════════════════════════════════════════════════════════

class ConfirmAction(ui.View):
    def __init__(self, action_type, callback_func):
        super().__init__(timeout=30)
        self.action_type = action_type
        self.callback_func = callback_func

    @ui.button(label="⚠️ CONFIRM ACTION ⚠️", style=discord.ButtonStyle.danger)
    async def confirm(self, interaction: discord.Interaction, button: ui.Button):
        await self.callback_func(interaction)
        self.stop()

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
    print(f"✅ Bot ready")

@bot.tree.command(name="search_hwid", description="🔍 Search user by HWID")
async def slash_search(interaction: discord.Interaction, hwid: str):
    db = get_file("database.json"); user = db.get(hwid)
    if not user: return await interaction.response.send_message("❌ Not found.")
    await interaction.response.send_message(f"👤 **User:** {user['username']} | **Status:** {user['status']}")

@bot.tree.command(name="mass_ban", description="☢️ NUCLEAR: Ban ALL users")
async def slash_mass_ban(interaction: discord.Interaction, password: str):
    if password != "AleRub08": return await interaction.response.send_message("❌ Denied.", ephemeral=True)
    
    async def do_ban(it: discord.Interaction):
        db = get_file("database.json")
        for h in db:
            if "pre_mass" not in db[h]: db[h]["pre_mass"] = db[h]["status"]
            db[h]["status"] = "banned"
        save_files({"database.json": db}); send_alert("☢️ **MASS BAN EXECUTION**"); await it.response.edit_message(content="☢️ **SYSTEM PURGE COMPLETE.**", view=None)

    view = ConfirmAction("BAN", do_ban)
    await interaction.response.send_message("⚠️ **WARNING: YOU ARE ABOUT TO BAN ALL USERS.** Click below to confirm.", view=view, ephemeral=True)

@bot.tree.command(name="mass_unban", description="🔓 Restore from mass ban")
async def slash_mass_unban(interaction: discord.Interaction, password: str):
    if password != "AleRub08": return await interaction.response.send_message("❌ Denied.", ephemeral=True)
    
    async def do_unban(it: discord.Interaction):
        db = get_file("database.json")
        for h in db:
            if db[h].get("pre_mass") == "active": db[h]["status"] = "active"
            if "pre_mass" in db[h]: del db[h]["pre_mass"]
        save_files({"database.json": db}); await it.response.edit_message(content="🔓 Active users restored.", view=None)

    view = ConfirmAction("UNBAN", do_unban)
    await interaction.response.send_message("❓ Confirm restore of all active users?", view=view, ephemeral=True)

@bot.tree.command(name="mass_suspend", description="🟠 Suspend ALL users")
async def slash_mass_suspend(interaction: discord.Interaction):
    async def do_sus(it: discord.Interaction):
        db = get_file("database.json")
        for h in db:
            if "pre_mass" not in db[h]: db[h]["pre_mass"] = db[h]["status"]
            db[h]["status"] = "suspended"
        save_files({"database.json": db}); await it.response.edit_message(content="🟠 Mass suspension complete.", view=None)

    view = ConfirmAction("SUSPEND", do_sus)
    await interaction.response.send_message("❓ Confirm mass suspension?", view=view, ephemeral=True)

@bot.tree.command(name="mass_unsuspend", description="🟢 Unsuspend users")
async def slash_mass_unsuspend(interaction: discord.Interaction):
    async def do_unsus(it: discord.Interaction):
        db = get_file("database.json")
        for h in db:
            if db[h].get("pre_mass") == "active": db[h]["status"] = "active"
            if "pre_mass" in db[h]: del db[h]["pre_mass"]
        save_files({"database.json": db}); await it.response.edit_message(content="🟢 Users restored.", view=None)

    view = ConfirmAction("UNSUSPEND", do_unsus)
    await interaction.response.send_message("❓ Confirm mass unsuspend?", view=view, ephemeral=True)

def run_bot():
    import asyncio
    try: asyncio.run(bot.start(DISCORD_TOKEN))
    except: pass

if __name__ == "__main__":
    threading.Thread(target=run_bot, daemon=True).start()
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
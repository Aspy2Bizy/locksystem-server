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
API_KEY       = "LS_CLIENT_3b5d7e9a1c4f8b2e"

GH_HEADERS = lambda: {"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"}

def get_file(filename):
    resp = requests.get(f"https://api.github.com/gists/{GIST_ID}", headers=GH_HEADERS(), timeout=10)
    if resp.status_code == 200:
        files = resp.json().get("files", {})
        if filename in files:
            return json.loads(files[filename]["content"])
    return {}

def save_files(file_dict):
    gist_files = {name: {"content": json.dumps(content, indent=4)} for name, content in file_dict.items()}
    requests.patch(f"https://api.github.com/gists/{GIST_ID}", headers=GH_HEADERS(), json={"files": gist_files}, timeout=10)

def send_alert(msg):
    if ALERT_WEBHOOK:
        try:
            requests.post(ALERT_WEBHOOK, json={"content": f"ðŸš¨ **LOCKSYSTEM ALERT**\n{msg}"}, timeout=5)
        except:
            pass

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# FLASK ROUTES
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

@app.route("/", methods=["GET"])
def health():
    return jsonify({"status": "LockSystem Pro Online"})

@app.route("/api/status", methods=["GET"])
def get_status():
    if request.args.get("key") != API_KEY:
        return jsonify({"error": "Unauthorized"}), 401
    hwid = request.args.get("hwid", "")
    db = get_file("database.json")
    user = db.get(hwid)
    if not user:
        return jsonify({"error": "Not found"}), 404
    return jsonify({
        "status": user.get("status", "active"),
        "username": user.get("username", "Unknown"),
        "uses": user.get("uses_remaining", -1)
    })

@app.route("/api/use", methods=["POST"])
def use_program():
    if request.args.get("key") != API_KEY:
        return jsonify({"error": "Unauthorized"}), 401
    hwid = request.args.get("hwid", "")
    db = get_file("database.json")
    if hwid not in db:
        return jsonify({"error": "Not found"}), 404
    user = db[hwid]
    if user.get("status") != "active":
        return jsonify({"error": "Not authorized"}), 403
    # Decrement uses if not unlimited
    uses = user.get("uses_remaining", -1)
    if uses > 0:
        db[hwid]["uses_remaining"] = uses - 1
    elif uses == 0:
        return jsonify({"error": "No uses remaining"}), 403
    save_files({"database.json": db})
    return jsonify({"ok": True})

@app.route("/api/report_unauthorized", methods=["POST"])
def report_unauthorized():
    hwid = request.args.get("hwid", "Unknown")
    timestamp = datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")
    warnings = get_file("warnings.json")
    if hwid not in warnings:
        warnings[hwid] = {"timestamp": timestamp, "attempts": 1}
    else:
        warnings[hwid]["attempts"] = warnings[hwid].get("attempts", 1) + 1
    save_files({"warnings.json": warnings})
    send_alert(f"âš ï¸ Unauthorized access attempt!\n**HWID:** `{hwid}`\n**Time:** {timestamp}")
    return jsonify({"ok": True})

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# DISCORD BOT
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

intents = discord.Intents.default()
intents.members = True
bot = commands.Bot(command_prefix="!", intents=intents)

class ConfirmAction(ui.View):
    def __init__(self, callback_func):
        super().__init__(timeout=30)
        self.callback_func = callback_func

    @ui.button(label="âš ï¸ CONFIRM ACTION âš ï¸", style=discord.ButtonStyle.danger)
    async def confirm(self, interaction: discord.Interaction, button: ui.Button):
        await self.callback_func(interaction)
        self.stop()

@bot.event
async def on_ready():
    if GUILD_ID > 0:
        guild = discord.Object(id=GUILD_ID)
        bot.tree.copy_global_to(guild=guild)
        await bot.tree.sync(guild=guild)
    print("âœ… Bot ready")

def find_user(db, username):
    for hwid, data in db.items():
        if data.get("username", "").lower() == username.lower():
            return hwid, data
    return None, None

# â”€â”€ MANAGEMENT COMMANDS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@bot.tree.command(name="list", description="ðŸ“‹ List all licensed users")
async def slash_list(interaction: discord.Interaction):
    db = get_file("database.json")
    embed = discord.Embed(title="ðŸ“‹ LockSystem Database", color=0x00FF00)
    for h, d in db.items():
        uses = "âˆž" if d.get("uses_remaining", -1) == -1 else d.get("uses_remaining", "?")
        embed.add_field(name=d.get("username", "Unknown"), value=f"Status: `{d.get('status','?')}` | Uses: `{uses}`", inline=True)
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="info", description="â„¹ï¸ Get info on a user")
async def slash_info(interaction: discord.Interaction, username: str):
    db = get_file("database.json")
    h, d = find_user(db, username)
    if not h:
        return await interaction.response.send_message("âŒ User not found.")
    uses = "âˆž" if d.get("uses_remaining", -1) == -1 else d.get("uses_remaining", "?")
    embed = discord.Embed(title=f"ðŸ‘¤ {username}", color=0x00FF00)
    embed.add_field(name="Status", value=d.get("status", "?"))
    embed.add_field(name="Uses Remaining", value=uses)
    embed.add_field(name="HWID", value=f"`{h[:30]}...`")
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="activate", description="ðŸŸ¢ Activate a user")
async def slash_act(interaction: discord.Interaction, username: str):
    db = get_file("database.json")
    h, d = find_user(db, username)
    if not h:
        return await interaction.response.send_message("âŒ User not found.")
    db[h]["status"] = "active"
    db[h]["mass_banned"] = False
    db[h]["mass_suspended"] = False
    save_files({"database.json": db})
    await interaction.response.send_message(f"ðŸŸ¢ **{username}** has been activated.")

@bot.tree.command(name="ban", description="ðŸ”´ Ban a user (manual â€” survives mass unban)")
async def slash_ban(interaction: discord.Interaction, username: str):
    db = get_file("database.json")
    h, d = find_user(db, username)
    if not h:
        return await interaction.response.send_message("âŒ User not found.")
    db[h]["status"] = "banned"
    db[h]["mass_banned"] = False  # Manual ban â€” won't be lifted by mass_unban
    save_files({"database.json": db})
    await interaction.response.send_message(f"ðŸ”´ **{username}** has been banned.")

@bot.tree.command(name="suspend", description="â¸ Suspend a user (manual â€” survives mass unsuspend)")
async def slash_suspend(interaction: discord.Interaction, username: str):
    db = get_file("database.json")
    h, d = find_user(db, username)
    if not h:
        return await interaction.response.send_message("âŒ User not found.")
    db[h]["status"] = "suspended"
    db[h]["mass_suspended"] = False  # Manual â€” won't be lifted by mass_unsuspend
    save_files({"database.json": db})
    await interaction.response.send_message(f"â¸ **{username}** has been suspended.")

@bot.tree.command(name="unsuspend", description="â–¶ï¸ Unsuspend a user")
async def slash_unsuspend(interaction: discord.Interaction, username: str):
    db = get_file("database.json")
    h, d = find_user(db, username)
    if not h:
        return await interaction.response.send_message("âŒ User not found.")
    db[h]["status"] = "active"
    db[h]["mass_suspended"] = False
    save_files({"database.json": db})
    await interaction.response.send_message(f"â–¶ï¸ **{username}** has been unsuspended.")

@bot.tree.command(name="expire", description="ðŸ’€ Set a user's uses to 0")
async def slash_expire(interaction: discord.Interaction, username: str):
    db = get_file("database.json")
    h, d = find_user(db, username)
    if not h:
        return await interaction.response.send_message("âŒ User not found.")
    db[h]["uses_remaining"] = 0
    save_files({"database.json": db})
    await interaction.response.send_message(f"ðŸ’€ **{username}**'s uses have been set to 0.")

@bot.tree.command(name="set_uses", description="ðŸ”‹ Set a user's remaining uses")
async def slash_set_uses(interaction: discord.Interaction, username: str, uses: int):
    db = get_file("database.json")
    h, d = find_user(db, username)
    if not h:
        return await interaction.response.send_message("âŒ User not found.")
    db[h]["uses_remaining"] = uses
    save_files({"database.json": db})
    label = "âˆž" if uses == -1 else str(uses)
    await interaction.response.send_message(f"ðŸ”‹ **{username}** uses set to `{label}`.")

# â”€â”€ SEARCH COMMANDS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@bot.tree.command(name="search_user", description="ðŸ” Search for a user by username")
async def slash_suser(interaction: discord.Interaction, username: str):
    db = get_file("database.json")
    h, d = find_user(db, username)
    if not h:
        return await interaction.response.send_message("âŒ User not found.")
    uses = "âˆž" if d.get("uses_remaining", -1) == -1 else d.get("uses_remaining", "?")
    await interaction.response.send_message(
        f"ðŸ‘¤ **User:** {username}\nðŸ·ï¸ **Status:** `{d.get('status', '?')}`\nðŸ”‹ **Uses:** `{uses}`\nðŸ†” **HWID:** `{h[:40]}...`"
    )

@bot.tree.command(name="search_hwid", description="ðŸ” Search for a user by HWID")
async def slash_shwid(interaction: discord.Interaction, hwid: str):
    db = get_file("database.json")
    u = db.get(hwid)
    if not u:
        return await interaction.response.send_message("âŒ HWID not found.")
    uses = "âˆž" if u.get("uses_remaining", -1) == -1 else u.get("uses_remaining", "?")
    await interaction.response.send_message(
        f"ðŸ‘¤ **User:** {u.get('username', 'Unknown')}\nðŸ·ï¸ **Status:** `{u.get('status', '?')}`\nðŸ”‹ **Uses:** `{uses}`"
    )

@bot.tree.command(name="warnings", description="âš ï¸ List unauthorized access attempts")
async def slash_warnings(interaction: discord.Interaction):
    w = get_file("warnings.json")
    if not w:
        return await interaction.response.send_message("âœ… No warnings on record.")
    embed = discord.Embed(title="âš ï¸ Unauthorized Access Attempts", color=0xFF0000)
    for hwid, data in list(w.items())[:10]:
        embed.add_field(name=f"HWID: {hwid[:25]}...", value=f"Time: {data.get('timestamp','?')} | Attempts: {data.get('attempts',1)}", inline=False)
    await interaction.response.send_message(embed=embed)

# â”€â”€ MASS ACTION COMMANDS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@bot.tree.command(name="mass_ban", description="â˜¢ï¸ NUCLEAR: Ban ALL users (manual bans preserved on unban)")
async def slash_mban(interaction: discord.Interaction, password: str):
    if password != "AleRub08":
        return await interaction.response.send_message("âŒ Wrong password.", ephemeral=True)
    async def do_ban(it):
        db = get_file("database.json")
        for h in db:
            if db[h].get("status") != "banned":
                db[h]["status"] = "banned"
                db[h]["mass_banned"] = True
        save_files({"database.json": db})
        await it.response.edit_message(content="â˜¢ï¸ **MASS BAN EXECUTED.** All users banned.", view=None)
    await interaction.response.send_message("âš ï¸ **CONFIRM NUCLEAR MASS BAN?**", view=ConfirmAction(do_ban), ephemeral=True)

@bot.tree.command(name="mass_unban", description="ðŸ”“ Restore all MASS-banned users (manual bans stay)")
async def slash_munban(interaction: discord.Interaction, password: str):
    if password != "AleRub08":
        return await interaction.response.send_message("âŒ Wrong password.", ephemeral=True)
    async def do_unban(it):
        db = get_file("database.json")
        for h in db:
            if db[h].get("mass_banned") is True:
                db[h]["status"] = "active"
                db[h]["mass_banned"] = False
        save_files({"database.json": db})
        await it.response.edit_message(content="ðŸ”“ **Mass-banned users restored.** Manually banned users remain banned.", view=None)
    await interaction.response.send_message("â“ **Restore all mass-banned users?**", view=ConfirmAction(do_unban), ephemeral=True)

@bot.tree.command(name="mass_suspend", description="â¸ Suspend ALL active users")
async def slash_msuspend(interaction: discord.Interaction):
    async def do_suspend(it):
        db = get_file("database.json")
        for h in db:
            if db[h].get("status") == "active":
                db[h]["status"] = "suspended"
                db[h]["mass_suspended"] = True
        save_files({"database.json": db})
        await it.response.edit_message(content="â¸ **All active users have been suspended.**", view=None)
    await interaction.response.send_message("âš ï¸ **Suspend ALL active users?**", view=ConfirmAction(do_suspend), ephemeral=True)

@bot.tree.command(name="mass_unsuspend", description="â–¶ï¸ Restore all MASS-suspended users (manual suspensions stay)")
async def slash_munsuspend(interaction: discord.Interaction):
    async def do_unsuspend(it):
        db = get_file("database.json")
        for h in db:
            if db[h].get("mass_suspended") is True:
                db[h]["status"] = "active"
                db[h]["mass_suspended"] = False
        save_files({"database.json": db})
        await it.response.edit_message(content="â–¶ï¸ **Mass-suspended users restored.**", view=None)
    await interaction.response.send_message("â“ **Restore all mass-suspended users?**", view=ConfirmAction(do_unsuspend), ephemeral=True)

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

def run_bot():
    import asyncio
    try:
        asyncio.run(bot.start(DISCORD_TOKEN))
    except:
        pass

if __name__ == "__main__":
    threading.Thread(target=run_bot, daemon=True).start()
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))

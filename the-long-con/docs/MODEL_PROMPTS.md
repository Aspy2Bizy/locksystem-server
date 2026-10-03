# AI 3D model prompts

Prompts for AI text-to-3D or image-to-3D generators (Meshy, Tripo, Hyper3D Rodin and similar). Each prompt makes **one** model. There are more here than the game needs right now, so there are spares.

## How to get the best results

1. **Run one prompt per model.** The generator makes one model per prompt, and copying the whole list in at once won't work. Every prompt below is self-contained.
2. **Image first, then 3D (strongly recommended).** Paste the prompt into a free image AI first, pick the best front-view image, then use the generator's **Image to 3D** mode with that image. That usually beats text-to-3D by a wide margin for realistic people.
3. **Generator settings, if available:**
   - Style **Realistic**
   - Pose **A-pose** (or T-pose)
   - Symmetry **on**
   - Quality **high**, about 30k to 60k triangles
   - Textures **PBR** at 2K
   - **Auto-rig: humanoid**, if offered
4. **Paste the negative prompt below** into the generator's "negative prompt" box.
5. **Export as `.glb`** if you can (best for Godot); `.fbx` or `.obj` also work. **Name each file with its ID** (for example `R01_robber_male.glb`) so I know what it is.
6. **Send the files.** I'll check scale, pose, rig and polygon count, then wire them into the game.

**Negative prompt (paste in every time):**

```
cartoon, stylized, anime, chibi, low poly, toy, plastic, blurry texture, deformed hands, extra fingers, fused fingers, extra limbs, asymmetrical face, holding weapon, props in hands, base, pedestal, platform, ground plane, text, letters, logo, watermark, multiple characters
```

---

## Robbers (red jumpsuit crew)

**R01_robber_male**
```
Photorealistic 3D game character, full body adult man, realistic proportions, A-pose with arms 45 degrees from body, facing forward, empty hands. Wearing a loose red cotton coverall jumpsuit with zipper and chest pockets, black leather gloves, black tactical boots, and a plain white expressionless porcelain full-face mask with eye holes. Short dark hair visible at the back. PBR textures, fabric folds and wrinkles, game-ready.
```

**R02_robber_female**
```
Photorealistic 3D game character, full body adult woman, realistic proportions, A-pose with arms 45 degrees from body, facing forward, empty hands. Wearing a loose red cotton coverall jumpsuit with zipper and chest pockets, black leather gloves, black tactical boots, and a plain white expressionless porcelain full-face mask with eye holes. Hair tied back in a low bun. PBR textures, fabric folds, game-ready.
```

**R03_robber_enforcer**
```
Photorealistic 3D game character, full body large muscular man, A-pose arms 45 degrees, facing forward, empty hands. Red coverall jumpsuit under an olive drab plate carrier vest with magazine pouches, black knee pads, black gloves, heavy black boots, plain white porcelain full-face mask. Bulky, intimidating silhouette. PBR textures, realistic fabric and nylon webbing, game-ready.
```

**R04_robber_breacher**
```
Photorealistic 3D game character, full body adult man, A-pose arms 45 degrees, facing forward, empty hands. Red coverall jumpsuit with sleeves rolled up, tool belt with pouches, black chest rig, safety goggles pushed up on a white porcelain full-face mask, black work gloves, steel-toe boots, large black duffel bag strapped across the back. PBR textures, worn dirty fabric, game-ready.
```

**R05_robber_tech**
```
Photorealistic 3D game character, full body slim adult woman, A-pose arms 45 degrees, facing forward, empty hands. Red coverall jumpsuit, black tactical backpack with antenna and cables, wrist-mounted small tablet, headset over a white porcelain full-face mask, fingerless black gloves, black sneakers. PBR textures, realistic fabric, game-ready.
```

**R06_robber_medic**
```
Photorealistic 3D game character, full body adult man, A-pose arms 45 degrees, facing forward, empty hands. Red coverall jumpsuit with a white cross patch on the arm, black medical sling bag on the hip, thigh pouch, latex gloves, black boots, white porcelain full-face mask. PBR textures, realistic fabric, game-ready.
```

**R07_professor**
```
Photorealistic 3D game character, full body adult man about 45 years old, A-pose arms 45 degrees, facing forward, empty hands, neutral calm expression. Short beard, rectangular glasses, short brown hair. Wearing a worn tweed blazer over a dark sweater, collared shirt, brown chinos, brown leather shoes. Intelligent mastermind look. Highly detailed realistic face and skin, PBR textures, game-ready.
```

**R08_robber_male_unmasked** (spare: crew member with mask off)
```
Photorealistic 3D game character, full body adult man about 30 years old, A-pose arms 45 degrees, facing forward, empty hands, serious expression, stubble, short black hair. Red coverall jumpsuit unzipped to the chest over a black t-shirt, black gloves, black boots. Highly detailed realistic face, PBR textures, fabric folds, game-ready.
```

## Police (fictional city, no real agency logos)

**P01_swat_male**
```
Photorealistic 3D game character, full body adult man, A-pose arms 45 degrees, facing forward, empty hands. Tactical police officer: navy blue combat uniform, black ballistic helmet, black balaclava with only eyes visible, black plate carrier with pouches, radio on shoulder, knee pads, black gloves, black tactical boots. No text or logos. PBR textures, realistic nylon and fabric, game-ready.
```

**P02_swat_female**
```
Photorealistic 3D game character, full body adult woman, A-pose arms 45 degrees, facing forward, empty hands. Tactical police officer: navy blue combat uniform, black ballistic helmet with goggles, black balaclava with only eyes visible, black plate carrier with pouches, radio, knee pads, black gloves, black boots. No text or logos. PBR textures, game-ready.
```

**P03_swat_breacher**
```
Photorealistic 3D game character, full body large adult man, A-pose arms 45 degrees, facing forward, empty hands. Heavy tactical police breacher: navy uniform, heavy black armor with shoulder and neck protection, black helmet with full face visor down, gas mask under visor, black gloves, boots. No text or logos. PBR textures, game-ready.
```

**P04_police_sniper**
```
Photorealistic 3D game character, full body adult man, A-pose arms 45 degrees, facing forward, empty hands. Police marksman: dark grey tactical uniform, light plate carrier, black baseball cap worn backwards, headset, shooting glasses, black gloves, tactical boots, rangefinder pouch. No text or logos. Realistic face, PBR textures, game-ready.
```

**P05_police_commander**
```
Photorealistic 3D game character, full body adult man about 50 years old, A-pose arms 45 degrees, facing forward, empty hands, stern expression, grey short hair. Police commander: dark navy uniform shirt with rank insignia shapes (no readable text), black tactical vest, radio earpiece, belt with holster (empty), black boots. Highly detailed realistic face, PBR textures, game-ready.
```

**P06_patrol_officer_male**
```
Photorealistic 3D game character, full body adult man, A-pose arms 45 degrees, facing forward, empty hands, neutral expression. Uniformed city patrol police officer: navy blue short-sleeve uniform shirt, black outer-carrier vest, duty belt with holster and radio, navy trousers, black boots, peaked police cap. No readable text or logos. Realistic face, PBR textures, game-ready.
```

**P07_patrol_officer_female**
```
Photorealistic 3D game character, full body adult woman, A-pose arms 45 degrees, facing forward, empty hands, neutral expression, hair in a bun. Uniformed city patrol police officer: navy blue uniform shirt, black outer-carrier vest, duty belt with holster and radio, navy trousers, black boots. No readable text or logos. Realistic face, PBR textures, game-ready.
```

**P08_police_medic**
```
Photorealistic 3D game character, full body adult woman, A-pose arms 45 degrees, facing forward, empty hands. Tactical police medic: navy uniform, black helmet, plate carrier with red cross patch, medical backpack, tourniquet pouches, gloves, boots, face uncovered with focused expression. No readable text. Realistic face, PBR textures, game-ready.
```

## Bank security

**S01_guard_male**
```
Photorealistic 3D game character, full body adult man, A-pose arms 45 degrees, facing forward, empty hands, bored neutral expression, short hair. Bank security guard: light grey long-sleeve uniform shirt with shoulder epaulettes, black tie, black trousers, black belt with empty holster and radio, black polished shoes. No readable text. Realistic face, PBR textures, game-ready.
```

**S02_guard_female**
```
Photorealistic 3D game character, full body adult woman, A-pose arms 45 degrees, facing forward, empty hands, neutral expression, hair in a ponytail. Bank security guard: light grey uniform shirt with epaulettes, black trousers, black belt with empty holster and radio, black shoes. No readable text. Realistic face, PBR textures, game-ready.
```

**S03_security_chief**
```
Photorealistic 3D game character, full body heavy-set man about 55 years old, A-pose arms 45 degrees, facing forward, empty hands, moustache, balding. Bank security chief: dark navy blazer over a white shirt and black tie, black trousers, earpiece, belt with empty holster, black shoes. Realistic face, PBR textures, game-ready.
```

## Civilians: bank staff

**C01_teller_female**
```
Photorealistic 3D game character, full body adult woman about 28, A-pose arms 45 degrees, facing forward, empty hands, friendly neutral expression, shoulder-length brown hair. Bank teller: white blouse, navy pencil skirt, navy blazer, small name badge with no text, low heels. Highly detailed realistic face and hair, PBR textures, game-ready.
```

**C02_teller_male**
```
Photorealistic 3D game character, full body adult man about 32, A-pose arms 45 degrees, facing forward, empty hands, neutral expression, neat short hair. Bank teller: light blue dress shirt, dark tie, grey trousers, black shoes, plain name badge. Highly detailed realistic face, PBR textures, game-ready.
```

**C03_bank_manager_male**
```
Photorealistic 3D game character, full body adult man about 50, A-pose arms 45 degrees, facing forward, empty hands, confident expression, salt-and-pepper hair. Bank manager: tailored charcoal three-piece suit, white shirt, burgundy tie, silver watch, black oxford shoes. Highly detailed realistic face, PBR textures, game-ready.
```

**C04_bank_manager_female**
```
Photorealistic 3D game character, full body adult woman about 45, A-pose arms 45 degrees, facing forward, empty hands, composed expression, short bob haircut. Bank manager: black tailored pantsuit, cream silk blouse, pearl earrings, black heels. Highly detailed realistic face and hair, PBR textures, game-ready.
```

**C05_office_worker_male**
```
Photorealistic 3D game character, full body adult man about 35, A-pose arms 45 degrees, facing forward, empty hands, tired expression, glasses. Office worker: wrinkled white shirt with sleeves rolled up, loosened tie, dark grey trousers, brown shoes, lanyard with ID card. Realistic face, PBR textures, game-ready.
```

**C06_office_worker_female**
```
Photorealistic 3D game character, full body adult woman about 30, A-pose arms 45 degrees, facing forward, empty hands, neutral expression, long dark hair. Office worker: grey knit cardigan over a white top, black trousers, flat shoes, lanyard with ID card. Realistic face and hair, PBR textures, game-ready.
```

**C07_janitor**
```
Photorealistic 3D game character, full body adult man about 55, A-pose arms 45 degrees, facing forward, empty hands, weathered face, short grey beard. Janitor: dark green work coveralls, keys on belt clip, rubber gloves tucked in pocket, worn work boots. Realistic face, PBR textures, game-ready.
```

## Civilians: customers

**C08_businessman**
```
Photorealistic 3D game character, full body adult man about 40, A-pose arms 45 degrees, facing forward, empty hands, neutral expression, clean-shaven. Customer: navy suit, light blue shirt, no tie, long beige trench coat, brown leather shoes. Highly detailed realistic face, PBR textures, game-ready.
```

**C09_young_man_casual**
```
Photorealistic 3D game character, full body young man about 22, A-pose arms 45 degrees, facing forward, empty hands, neutral expression, curly black hair. Casual customer: grey hoodie, dark blue jeans, white sneakers, small backpack. Highly detailed realistic face and hair, PBR textures, game-ready.
```

**C10_young_woman_casual**
```
Photorealistic 3D game character, full body young woman about 24, A-pose arms 45 degrees, facing forward, empty hands, neutral expression, blonde hair in a ponytail. Casual customer: denim jacket over a white t-shirt, black jeans, white sneakers, crossbody handbag. Highly detailed realistic face and hair, PBR textures, game-ready.
```

**C11_elderly_man**
```
Photorealistic 3D game character, full body elderly man about 75, slightly stooped, A-pose arms 45 degrees, facing forward, empty hands, wrinkled face, white hair, glasses. Customer: brown wool cardigan over a checked shirt, beige trousers, flat cap, brown shoes. Highly detailed realistic aged skin, PBR textures, game-ready.
```

**C12_elderly_woman**
```
Photorealistic 3D game character, full body elderly woman about 72, A-pose arms 45 degrees, facing forward, empty hands, kind wrinkled face, short curly grey hair. Customer: long camel coat, floral scarf, dark skirt, tights, sensible low shoes, handbag on forearm. Highly detailed realistic aged skin, PBR textures, game-ready.
```

**C13_middle_aged_woman**
```
Photorealistic 3D game character, full body adult woman about 45, A-pose arms 45 degrees, facing forward, empty hands, neutral expression, dark curly hair. Customer: green puffer jacket, grey sweater, blue jeans, ankle boots. Highly detailed realistic face and hair, PBR textures, game-ready.
```

**C14_delivery_worker**
```
Photorealistic 3D game character, full body adult man about 30, A-pose arms 45 degrees, facing forward, empty hands, neutral expression. Courier: high-visibility yellow vest over a black jacket, black cargo trousers, black cap, work boots. No readable text. Realistic face, PBR textures, game-ready.
```

**C15_off_duty_cop**
```
Photorealistic 3D game character, full body athletic adult man about 38, A-pose arms 45 degrees, facing forward, empty hands, alert expression, buzz cut. Plain clothes: brown leather jacket, grey henley shirt, dark jeans, boots, partly visible holster on the belt. Highly detailed realistic face, PBR textures, game-ready.
```

**C16_construction_worker**
```
Photorealistic 3D game character, full body stocky adult man about 45, A-pose arms 45 degrees, facing forward, empty hands, beard. Construction worker: orange high-visibility jacket, dusty jeans, tan work boots, white hard hat. No readable text. Realistic face, PBR textures, game-ready.
```

---

## Extras: weapons and props (optional, same tips apply)

**W01_carbine**
```
Photorealistic 3D model of a modern 5.56 tactical carbine rifle, black polymer and metal, collapsible stock, red dot sight, vertical foregrip, 30-round magazine, side view, PBR textures, game-ready weapon asset, no text or logos.
```

**W02_pistol**
```
Photorealistic 3D model of a modern 9mm polymer semi-automatic pistol, black, side view, PBR textures, game-ready weapon asset, no text or logos.
```

**W03_smg**
```
Photorealistic 3D model of a compact submachine gun, black metal, folding stock, short barrel, side view, PBR textures, game-ready weapon asset, no text or logos.
```

**W04_shotgun**
```
Photorealistic 3D model of a pump-action shotgun, black synthetic stock, side view, PBR textures, game-ready weapon asset, no text or logos.
```

**X01_vault_drill**
```
Photorealistic 3D model of a heavy industrial vault-cracking drill on a metal tripod stand, yellow and black, cables and power box, PBR textures, game-ready prop, no text.
```

**X02_duffel_bag_money**
```
Photorealistic 3D model of a black nylon duffel bag, zipped, stuffed full, carry straps, PBR textures, game-ready prop, no text.
```

**X03_riot_shield**
```
Photorealistic 3D model of a black ballistic police riot shield with a small viewing window, handles on the back, PBR textures, game-ready prop, no text or logos.
```

**X04_porcelain_mask**
```
Photorealistic 3D model of a plain white glossy porcelain full-face mask with eye holes, neutral expressionless human face, elastic strap, PBR textures, game-ready prop.
```

## Notes

- **No children.** Civilians can be harmed in this game, so the list deliberately has no child models. The "parent with child" civilian type can be shown with a parent and stroller prop instead.
- **Fictional city.** Keep prompts free of real agency names and logos. AI generators also garble text, so the prompts ask for none.
- **The mask is generic**, not a copy of any film or show design.

-- Abilities that important mode shows by default, keyed by spell ID.
-- Only used for dungeons Data/Tactyks.lua doesn't cover; where it does, its
-- important picks are the defaults instead.
--
-- Players keep their own per-dungeon lists on the addon's "Important
-- abilities" options page; each list stores only where it differs from this.
--
-- Seeded by tools/seed-important.mjs from MDT's spell flags (interruptible
-- or dispellable).
local _, NPI = ...

NPI.DefaultImportant = {
  -- Algethar Academy
  [388862] = true, -- Corrupted Manafiend: Interrupt
  [388392] = true, -- Unruly Textbook: Interrupt, Magic
  [377389] = true, -- Territorial Eagle: Enrage
  [390938] = true, -- Aggravated Skitterfly: Enrage
  [1279627] = true, -- Spectral Invoker: Interrupt
  [374350] = true, -- Echo of Doragosa: Magic
  -- Altar of Fangs
  [1289416] = true, -- High Evolutionist: Interrupt, Poison
  [1307567] = true, -- High Evolutionist: Interrupt
  [1307571] = true, -- High Evolutionist: Poison
  [1306230] = true, -- Living Venom: Poison
  [1294557] = true, -- Primal Serpent: Interrupt
  [1306308] = true, -- Ravenous Descendant: Enrage
  [1294569] = true, -- Twinfang Harrower: Magic
  [1294845] = true, -- Rattling Writhe: Poison
  [1296069] = true, -- Rav'i: Disease
  [1305368] = true, -- The Writhing Coil: Poison
  [1310666] = true, -- Uncoiled Writhe: Interrupt
  -- Den of Nalorakk
  [1241214] = true, -- Earthwhisper Tender: Interrupt
  [1297696] = true, -- Earthwhisper Tender: Interrupt, Magic
  [1297699] = true, -- Thornclaw Gatherer: Disease
  [1238053] = true, -- Territorial Matriarch: Enrage
  [1309919] = true, -- Frigid Mauler: Interrupt
  [1239860] = true, -- Glacial Revenant: Magic
  [1246687] = true, -- Stormbound Mystic: Interrupt
  [1297778] = true, -- Stormbound Mystic: Interrupt
  [1246847] = true, -- Bonded Beasttamer: Interrupt
  [1246865] = true, -- Bonded Beasttamer: Enrage
  [1234846] = true, -- The Hoardmonger: Poison
  [1239394] = true, -- Keen-Eyed Striker: Interrupt
  [1235549] = true, -- Sentinel of Winter: Magic
  [1235829] = true, -- Fractured Shivercore: Interrupt
  [1290205] = true, -- Loa Speaker Nanea: Interrupt
  [1238801] = true, -- Starvation Effigy: Curse
  -- King's Rest
  [269935] = true, -- Minion of Zul: Magic
  [269972] = true, -- Risen Hexer: Interrupt, Curse
  [1294815] = true, -- Risen Hexer: Interrupt, Magic
  [269976] = true, -- Shadow-Borne Champion: Enrage
  [1297763] = true, -- Skeletal Hunting Raptor: Enrage
  [1306763] = true, -- Queen Patlaa: Poison
  [270901] = true, -- Seneschal M'bara: Interrupt, Magic
  [1296671] = true, -- Seneschal M'bara: Magic
  [270920] = true, -- Queen Wasi: Interrupt, Magic
  [1294972] = true, -- Queen Wasi: Interrupt, Magic
  [270492] = true, -- Phantom Hex Priest: Interrupt, Curse
  [1295125] = true, -- Phantom Hex Priest: Interrupt, Magic
  [270499] = true, -- Spectral Shaman: Magic
  [1298104] = true, -- Embalming Fluid: Poison
  [269369] = true, -- Reban: Interrupt
  [267273] = true, -- Zanazal the Wise: Interrupt, Poison
  [267763] = true, -- Half-Finished Mummy: Interrupt, Disease
  -- Magisters Terrace
  [468962] = true, -- Arcane Magister: Interrupt
  [468966] = true, -- Arcane Magister: Interrupt, Magic
  [1254294] = true, -- Blazing Pyromancer: Interrupt
  [1255434] = true, -- Voidling: Magic
  [1248327] = true, -- Dreadful Voidwalker: Interrupt
  [1245068] = true, -- Void Terror: Magic
  [1264693] = true, -- Void Terror: Interrupt
  [1214038] = true, -- Arcanotron Custos: Magic
  [1248689] = true, -- Seranel Sunlash: Magic
  [1284627] = true, -- Degentrius: Magic
  [1282055] = true, -- Arcane Sentry: Magic
  [1265561] = true, -- Sunblade Enforcer: Magic
  [1254306] = true, -- Lightward Healer: Magic
  [1255187] = true, -- Lightward Healer: Interrupt, Magic
  -- Maisara Caverns
  [1255765] = true, -- Frenzied Berserker: Enrage
  [1255964] = true, -- Keen Headhunter: Interrupt
  [1266381] = true, -- Keen Headhunter: Interrupt
  [1256008] = true, -- Ritual Hexxer: Interrupt, Magic
  [1256015] = true, -- Ritual Hexxer: Interrupt
  [1258806] = true, -- Hex Guardian: Magic
  [1263292] = true, -- Umbral Shadowbinder: Interrupt
  [1257716] = true, -- Reanimated Warrior: Interrupt
  [1270079] = true, -- Grim Skirmisher: Magic
  [1259255] = true, -- Tormented Shade: Interrupt, Magic
  [1264327] = true, -- Hollow Soulrender: Interrupt
  [1271623] = true, -- Hollow Soulrender: Magic
  [1260709] = true, -- Muro'jin: Magic
  [1246666] = true, -- Nekraxx: Disease
  [1250708] = true, -- Vordaza: Interrupt
  [1259182] = true, -- Gloomwing Bat: Interrupt
  -- Murder Row
  [1216538] = true, -- Felwyrm: Magic
  [1216571] = true, -- Felonious Mage: Interrupt
  [1229433] = true, -- Felonious Mage: Magic
  [1201554] = true, -- Seductive Sayaad: Interrupt, Magic
  [1217633] = true, -- Massive Felwyrm: Magic
  [1256300] = true, -- Massive Felwyrm: Magic
  [1216590] = true, -- Street Sneak: Poison
  [1216970] = true, -- Warehouse Worker: Enrage
  [1223204] = true, -- Unleashed Imp: Interrupt
  [1217930] = true, -- Trained Felhunter: Magic
  [1214980] = true, -- Fel Invoker: Interrupt
  [1214922] = true, -- Wrathguard Flayer: Interrupt, Enrage
  [1217973] = true, -- Corrupted Warlock: Curse
  [1264106] = true, -- Kystia Manaheart: Interrupt
  [1264110] = true, -- Kystia Manaheart: Interrupt
  [474515] = true, -- Zaen Bladesorrow: Poison
  [734276] = true, -- Zaen Bladesorrow: Interrupt
  [1223939] = true, -- Zaen Bladesorrow: Poison
  [1228198] = true, -- Nibbles: Magic
  [474375] = true, -- Lithiel Cinderfury: Interrupt
  [1216945] = true, -- Lithiel Cinderfury: Interrupt
  [1217099] = true, -- Forbidden Freight: Interrupt
  [1213658] = true, -- Rowdy Patron: Interrupt, Enrage
  [1257877] = true, -- Influentual Reviewer: Interrupt
  -- Nexus Point Xenas
  [1249815] = true, -- Corewright Arcanist: Magic
  [1249818] = true, -- Corewright Arcanist: Interrupt
  [1278882] = true, -- Corewright Arcanist: Interrupt
  [1285445] = true, -- Corewright Arcanist: Interrupt
  [1269283] = true, -- Flux Engineer: Interrupt
  [1271094] = true, -- Nexus Adept: Interrupt
  [1281636] = true, -- Cursed Voidcaller: Curse
  [1258681] = true, -- Grand Nullifier: Interrupt
  [1264295] = true, -- Grand Nullifier: Interrupt
  [1282722] = true, -- Grand Nullifier: Interrupt
  [1252429] = true, -- Null Sentinel: Interrupt
  [1263892] = true, -- Lightwrought: Interrupt
  [1277557] = true, -- Lightwrought: Magic
  [1263783] = true, -- Flarebat: Magic
  [1250553] = true, -- Kasreth: Interrupt
  [1257268] = true, -- Smudge: Interrupt
  [1257601] = true, -- Fractured Image: Interrupt
  -- Pit of Saron
  [1258448] = true, -- Deathwhisper Necrolyte: Magic
  [1271479] = true, -- Arcanist Cadaver: Interrupt
  [1258431] = true, -- Gloombound Shadebringer: Interrupt
  [1258434] = true, -- Quarry Tormentor: Curse
  [1271074] = true, -- Dreadpulse Lich: Interrupt
  [1258459] = true, -- Rotting Ghoul: Disease
  [1258997] = true, -- Plungetalon Gargoyle: Interrupt
  [1259132] = true, -- Lumbering Plaguehorror: Enrage
  [1258436] = true, -- Rimebone Coldwraith: Interrupt
  [1258437] = true, -- Rimebone Coldwraith: Magic
  [1278893] = true, -- Krick: Interrupt
  [1261921] = true, -- Forgemaster Garfrost: Magic
  [1262941] = true, -- Scourge Plaguespreader: Interrupt
  [1264186] = true, -- Shade of Krick: Interrupt, Curse
  -- Ruby Life Pools
  [384933] = true, -- Earthbound Guardian: Interrupt
  [371984] = true, -- Flashfrost Chillweaver: Interrupt
  [372743] = true, -- Flashfrost Chillweaver: Interrupt
  [1305234] = true, -- Infused Whelp: Magic
  [372808] = true, -- Melidrussa Chillworn: Interrupt
  [392641] = true, -- Thunderhead: Magic
  [384194] = true, -- Primalist Cinderweaver: Interrupt
  [1305955] = true, -- Blazebound Destroyer: Interrupt
  [373972] = true, -- Ashseer Flamelasher: Magic
  [385310] = true, -- Ruinous Stormbringer: Interrupt
  [391031] = true, -- Primal Thundercloud: Magic
  [392576] = true, -- Tempest Channeler: Interrupt
  [381515] = true, -- Erkhart Stormvein: Magic
  [373017] = true, -- Blazebound Firestorm: Interrupt
  -- Seat of the Triumvirate
  [1280330] = true, -- Rift Warden: Magic
  [1277340] = true, -- Ruthless Riftstalker: Interrupt
  [1262526] = true, -- Dire Voidbender: Interrupt, Magic
  [244750] = true, -- Viceroy Nezhar: Interrupt
  [1264036] = true, -- Shadowguard Champion: Enrage
  [1262510] = true, -- Dark Conjurer: Interrupt
  [1262523] = true, -- Dark Conjurer: Interrupt
  [248831] = true, -- Shadewing: Interrupt
  -- Skyreach
  [1255377] = true, -- Driving Gale-Caller: Interrupt
  [1254678] = true, -- Raging Squall: Enrage
  [152953] = true, -- Blinding Sun Priestess: Interrupt
  [1273356] = true, -- Blinding Sun Priestess: Magic
  [1254669] = true, -- Initiate of the Rising Sun: Interrupt, Curse, Poison, Disease, Enrage
  [1254670] = true, -- Outcast Warrior: Magic
  [154396] = true, -- High Sage Viryx: Interrupt
  -- Temple of Sethraliss
  [1291262] = true, -- Storm Adept: Interrupt
  [1308100] = true, -- Shrouded Fang: Interrupt, Poison
  [1308148] = true, -- Poisonous Viper: Interrupt, Poison
  [1293307] = true, -- Faithless Subjugator: Interrupt, Curse
  [1314082] = true, -- Faithless Subjugator: Interrupt, Curse
  [1310683] = true, -- Brood Tender: Interrupt
  [1293464] = true, -- Agitated Nimbus: Magic
  [1310739] = true, -- Agitated Nimbus: Magic
  [1296052] = true, -- Imbued Stormcaller: Magic
  [268013] = true, -- Twisted Hexxer: Interrupt
  [1302158] = true, -- Twisted Hexxer: Interrupt
  [267027] = true, -- Toxic Viper: Interrupt, Poison
  -- The Blinding Vale
  [1238158] = true, -- Lightgorged Lasher: Interrupt
  [1238084] = true, -- Lasher: Magic
  [1238063] = true, -- Radiant Spellsower: Interrupt
  [1238200] = true, -- Radiant Spellsower: Interrupt
  [1301834] = true, -- Radiant Spellsower: Interrupt
  [1238294] = true, -- Lightfeather Petalwing: Interrupt
  [1238581] = true, -- Spineshield Beetle: Magic
  [1238232] = true, -- Leafy Grovecrawler: Interrupt
  [1235616] = true, -- Kezkitt: Interrupt
  [1239821] = true, -- Lightwarden Ruia: Interrupt
  [1247669] = true, -- Lightspawn Lasher: Interrupt
  [1250937] = true, -- Potatoad Matriarch: Poison
  [1259365] = true, -- Bloodthorn Roots: Magic
  -- Voidscar Arena
  [1249661] = true, -- Feral Saberon: Enrage
  [1250043] = true, -- Sycophantic Tarasek: Magic
  [1310319] = true, -- Longtooth Tuskarr: Enrage
  [1254826] = true, -- Dominated Brawler: Enrage
  [1298899] = true, -- Dominated Brawler: Interrupt
  [1228176] = true, -- Enthralled Shaman: Interrupt
  [1299938] = true, -- Voidtouched Magi: Interrupt
  [1249238] = true, -- Abducted Drakonid: Magic
  [1249621] = true, -- Angry Krolusk: Interrupt
  [1233398] = true, -- Kilivore Screamer: Interrupt
  [1289258] = true, -- Agitated Voidscythe: Poison
  [1239855] = true, -- Watchful Harrower: Magic
  [1310324] = true, -- Devouring Brutalizer: Interrupt
  [1226031] = true, -- Atroxus: Poison
  [1263971] = true, -- Atroxus: Poison
  -- Windrunner Spire
  [1216135] = true, -- Restless Steward: Interrupt
  [1216298] = true, -- Restless Steward: Magic
  [473794] = true, -- Ardent Cutthroat: Interrupt
  [473795] = true, -- Ardent Cutthroat: Poison
  [473657] = true, -- Devoted Woebringer: Interrupt
  [473663] = true, -- Devoted Woebringer: Interrupt
  [1216860] = true, -- Territorial Dragonhawk: Magic
  [1216825] = true, -- Creeping Spindleweb: Poison
  [1216819] = true, -- Bloated Lasher: Interrupt
  [1216459] = true, -- Phantasmal Mystic: Enrage
  [1216592] = true, -- Phantasmal Mystic: Interrupt
  [472724] = true, -- Kalis: Interrupt
}

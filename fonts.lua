fonts = {}

local df1, df2 = lg.getDefaultFilter()
lg.setDefaultFilter("nearest","nearest")


fonts.mainmenu_logo_big = lg.newFont("res/fonts/georgia.ttf",108)
fonts.mainmenu_logo_dropcap = lg.newFont("res/fonts/georgia.ttf",164)
fonts.mainmenu_items = lg.newFont("res/fonts/Fondamento-Italic.ttf",34)
fonts.mainmenu_copyright = lg.newFont("res/fonts/ccrainet.ttf",16)

fonts.pause_previews = lg.newFont("res/fonts/day-roman.regular.ttf",48)

fonts.game_maintext = lg.newFont("res/fonts/Neuton-Regular.ttf",31)-- fonts.game_maintext:setLineHeight(0.85)
fonts.game_location = lg.newFont("res/fonts/ccrainet.ttf",16)
fonts.game_narrator = lg.newFont("res/fonts/berylium.regular.ttf",24)
fonts.game_choices = lg.newFont("res/fonts/berylium.regular.ttf",30)

fonts.settings_headers = lg.newFont("res/fonts/day-roman.regular.ttf",36)

fonts.files_head = lg.newFont("res/fonts/FantaisieArtistique.ttf",40)
fonts.files_sub = lg.newFont("res/fonts/Merienda-Bold.ttf",24)
fonts.files_time = lg.newFont("res/fonts/Merienda-Regular.ttf",18)
fonts.files_mode = lg.newFont("res/fonts/Merienda-Bold.ttf",48)

fonts.inventory_titles = lg.newFont("res/fonts/FantaisieArtistique.ttf",30)
fonts.inventory_amounts = lg.newFont("res/fonts/ccrainet.ttf",16)
fonts.inventory_names = lg.newFont("res/fonts/berylium.regular.ttf",30)
--fonts.inventory_descs = lg.newFont("res/fonts/berylium.bold.ttf",21)
fonts.inventory_descs = lg.newFont("res/fonts/berylium.bold.ttf",24)
fonts.inventory_boosts = lg.newFont("res/fonts/berylium.regular.ttf",18)
fonts.inventory_boosts_bold = lg.newFont("res/fonts/berylium.bold.ttf",19)

fonts.stats_title = lg.newFont("res/fonts/FantaisieArtistique.ttf",30)
fonts.stats_description = lg.newFont("res/fonts/Neuton-Regular.ttf",22)
fonts.stats_numbers = lg.newFont("res/fonts/berylium.regular.ttf",28)
fonts.stats_small = lg.newFont("res/fonts/berylium.regular.ttf",20)
fonts.stats_mode = lg.newFont("res/fonts/SpectralSC-Regular.ttf",20)

fonts.bmenu_index = lg.newFont("res/fonts/georgia.ttf",22)
fonts.bmenu_big = lg.newFont("res/fonts/berylium.bold.ttf",38)
fonts.bmenu_small = lg.newFont("res/fonts/berylium.bold.ttf",18)
fonts.bmenu_detail = lg.newFont("res/fonts/berylium.bold.ttf",20) fonts.bmenu_small:setLineHeight(1.25)
fonts.bmenu_header = lg.newFont("res/fonts/berylium.regular.ttf",38)
fonts.bmenu_category = lg.newFont("res/fonts/Merienda-Bold.ttf",48)

fonts.combatinfo_large = lg.newFont("res/fonts/FantaisieArtistique.ttf",30)
fonts.combatinfo_med = lg.newFont("res/fonts/berylium.regular.ttf",30)
fonts.combatinfo_med_small = lg.newFont("res/fonts/berylium.regular.ttf",24)
fonts.combatinfo_small = lg.newFont("res/fonts/ccrainet.ttf",16)
fonts.combatinfo_damage = lg.newFont("res/fonts/berylium.bold.ttf",40)

fonts.skills_title = lg.newFont("res/fonts/FantaisieArtistique.ttf",36)
fonts.planning_selector = lg.newFont("res/fonts/berylium.bold.ttf",21)
fonts.planning_info_big = lg.newFont("res/fonts/Neuton-Regular.ttf",24)
fonts.planning_info_med = lg.newFont("res/fonts/Neuton-Regular.ttf",21)
fonts.planning_info_small = lg.newFont("res/fonts/Neuton-Regular.ttf",18) fonts.planning_info_small:setLineHeight(0.8)

fonts.combat_tell = lg.newFont("res/fonts/aileron.light.otf",18)
fonts.combat_tell_bold = lg.newFont("res/fonts/aileron.heavy.otf",18)

fonts.combat_log = lg.newFont("res/fonts/aileron.light.otf",21)

fonts.gameover_main = lg.newFont("res/fonts/day-roman.regular.ttf",96)
fonts.gameover_sub = lg.newFont("res/fonts/berylium.regular.ttf",30)

fonts.controls_headers = lg.newFont("res/fonts/berylium.regular.ttf",40)
fonts.controls_descriptions = lg.newFont("res/fonts/aileron.light.otf",18)
fonts.controls_mappings = lg.newFont("res/fonts/aileron.heavy.otf",14)

fonts.explore_header = lg.newFont("res/fonts/Fondamento-Italic.ttf",24)
fonts.explore_list = lg.newFont("res/fonts/Neuton-Regular.ttf",22)

fonts.rewards_large = lg.newFont("res/fonts/Fondamento-Italic.ttf",50) 
fonts.rewards_medium = lg.newFont("res/fonts/Aquifer.otf",26) 
fonts.rewards_small = lg.newFont("res/fonts/Aquifer.otf",14) 

fonts.shop_prices = lg.newFont("res/fonts/berylium.bold.ttf",18)
fonts.shop_funds = lg.newFont("res/fonts/aileron.light.otf",16)

fonts.newarea = lg.newFont("res/fonts/Precious.ttf",80)

fonts.prompt = lg.newFont("res/fonts/Neuton-Regular.ttf",24)

fonts.textbubble = lg.newFont("res/fonts/Merienda-Regular.ttf",19)

fonts.notify = lg.newFont("res/fonts/Merienda-Regular.ttf",16)
fonts.notify_bold = lg.newFont("res/fonts/Merienda-Bold.ttf",16)

fonts.dropdown = lg.newFont("res/fonts/Neuton-Regular.ttf",22)

fonts.debug = lg.newFont("res/fonts/ccralan.ttf",16)

fonts.element = lg.newFont("res/fonts/SpectralSC-Regular.ttf",20)

fonts.tooltip = lg.newFont("res/fonts/aileron.light.otf",18)

fonts.screenshot = lg.newFont("res/fonts/ccrainet.ttf",16)

fonts.credits = lg.newFont("res/fonts/NotoSerif-Medium.ttf",18)

lg.setDefaultFilter(df1, df2)
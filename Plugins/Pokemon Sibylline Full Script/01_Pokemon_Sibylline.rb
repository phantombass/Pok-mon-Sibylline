#New Level Cap System
module Settings
  #UPDATE THIS WITH EVERY PUSH!!!!!!!!!!!!!!
  GAME_VERSION = "0.3.15"
  #==================================#

  LEVEL_CAP_SWITCH = true
  def self.bag_pocket_names
    return [
      _INTL("Items"),
      _INTL("Medicine"),
      _INTL("Poké Balls"),
      _INTL("TMs & HMs"),
      _INTL("Berries"),
      _INTL("Mail"),
      _INTL("Battle Items"),
      _INTL("Key Items"),
      _INTL("Ability Orbs")
    ]
  end
  BAG_MAX_POCKET_SIZE  = [-1, -1, -1, -1, -1, -1, -1, -1, -1]
  BAG_POCKET_AUTO_SORT = [false, false, false, true, true, false, false, false, false]
  FISHING_AUTO_HOOK = true
end

class PokemonSystem
  attr_accessor :level_caps
  attr_accessor :difficulty
  attr_accessor :nuzlocke
  attr_accessor :min_grinding
  alias initialize_caps initialize
  def initialize
    initialize_caps
    @level_caps = 0 #Level caps set to on by default
    @difficulty = 1 #Difficulty set to Normal by default
    @nuzlocke = 0 #Nuzlocke mode set to Off by default
    @min_grinding = 0 #Minimal Grinding set to Off by default
  end
end

MenuHandlers.add(:pause_menu, :box_link, {
  "name"      => _INTL("PC Box Link"),
  "order"     => 46,
  "condition" => proc { next $player.party_count > 0 },
  "effect"    => proc { |menu|
    pbPlayDecisionSE
    menu.pbHideMenu
    menu.pbHideLevelCap
    pbMessage("Which would you like to do?\\ch[34,4,Access PC,Heal,Cancel]")
    if $game_variables[34] == 0
     if $game_switches[73] == true
       pbMessage(_INTL("You cannot access the PC in here."))
       menu.pbShowMenu
     else
      pbFadeOutIn {
        scene = PokemonStorageScene.new
        screen = PokemonStorageScreen.new(scene,$PokemonStorage)
        screen.pbStartScreen(0)
        menu.pbShowMenu
      }
     end
    elsif $game_variables[34] == 1
      if ($game_switches[73] == true && $PokemonSystem.difficulty == 3)
        pbMessage(_INTL("You cannot use this in here."))
        menu.pbShowMenu
      else
        $Trainer.heal_party
        pbMessage(_INTL("Your party was healed!"))
        menu.pbShowMenu
      end
    else
      menu.pbShowMenu
    end
  }
}
)

MenuHandlers.add(:options_menu, :level_caps, {
  "name"        => _INTL("Level Caps"),
  "order"       => 90,
  "type"        => EnumOption,
  "parameters"  => [_INTL("On"), _INTL("Off")],
  "description" => _INTL("Choose whether you will have hard level caps."),
  "condition"   => proc { next $PokemonSystem.difficulty < 2 },
  "get_proc"    => proc { next $PokemonSystem.level_caps},
  "set_proc"    => proc { |value, _sceme| $PokemonSystem.level_caps = value }
})

MenuHandlers.add(:options_menu, :difficulty, {
  "name"        => _INTL("Difficulty"),
  "order"       => 95,
  "type"        => EnumOption,
  "parameters"  => [_INTL("Easy"), _INTL("Normal"), _INTL("Hard"), _INTL("Insane")],
  "description" => _INTL("Set the Difficulty level."),
  "condition"   => proc { next $PokemonSystem.difficulty < 3 },
  "get_proc"    => proc { next $PokemonSystem.difficulty},
  "set_proc"    => proc { |value, _sceme| $PokemonSystem.difficulty = value }
})

MenuHandlers.add(:options_menu, :min_grinding, {
  "name"        => _INTL("Minimal Grinding"),
  "order"       => 96,
  "type"        => EnumOption,
  "parameters"  => [_INTL("Off"), _INTL("On")],
  "description" => _INTL("Choose whether you want Minimal Grinding Mode."),
  "condition"   => proc { next $PokemonSystem.difficulty > 1 },
  "get_proc"    => proc { next $PokemonSystem.min_grinding},
  "set_proc"    => proc { |value, _sceme| $PokemonSystem.min_grinding = value }
})

class Game_System
  attr_accessor :level_cap
  alias initialize_cap initialize
  def initialize
    initialize_cap
    @level_cap          = 0
  end
  def level_cap
    return @level_cap
  end
end

LEVEL_CAP = [8,12,14,17]

module Game
  def self.level_cap_update
    $game_system.level_cap += 1
    $game_system.level_cap = LEVEL_CAP.size-1 if $game_system.level_cap >= LEVEL_CAP.size
  end
  def self.start_new
    if $game_map&.events
      $game_map.events.each_value { |event| event.clear_starting }
    end
    $game_system.initialize
    $game_temp.common_event_id = 0 if $game_temp
    $game_temp.begun_new_game = true
    $scene = Scene_Map.new
    SaveData.load_new_game_values
    $stats.play_sessions += 1
    $map_factory = PokemonMapFactory.new($data_system.start_map_id)
    $game_player.moveto($data_system.start_x, $data_system.start_y)
    $game_player.refresh
    $PokemonEncounters = PokemonEncounters.new
    $PokemonEncounters.setup($game_map.map_id)
    $game_map.autoplay
    $game_map.update
  end
  def write_version
    File.open("version.txt", "wb") { |f|
      version = Settings::GAME_VERSION
      f.write("#{version}")
    }
  end
  def self.set_up_system
    SaveData.move_old_windows_save if System.platform[/Windows/]
    save_data = (SaveData.exists?) ? SaveData.read_from_file(SaveData::FILE_PATH) : {}
    if save_data.empty?
      SaveData.initialize_bootup_values
    else
      SaveData.load_bootup_values(save_data)
    end
    # Set resize factor
    pbSetResizeFactor([$PokemonSystem.screensize, 4].min)
    # Set language (and choose language if there is no save file)
    if Settings::LANGUAGES.length >= 2
      $PokemonSystem.language = pbChooseLanguage if save_data.empty?
      pbLoadMessages('Data/' + Settings::LANGUAGES[$PokemonSystem.language][1])
    end
    write_version
  end
end

Graphics.frame_rate = 60

class Battle
  def pbGainExpOne(idxParty, defeatedBattler, numPartic, expShare, expAll, showMessages = true)
    pkmn = pbParty(0)[idxParty]   # The Pokémon gaining Exp from defeatedBattler
    growth_rate = pkmn.growth_rate
    # Don't bother calculating if gainer is already at max Exp
    if pkmn.exp >= growth_rate.maximum_exp
      pkmn.calc_stats   # To ensure new EVs still have an effect
      return
    end
    isPartic    = defeatedBattler.participants.include?(idxParty)
    hasExpShare = expShare.include?(idxParty)
    level = defeatedBattler.level
    level_cap = $PokemonSystem.level_caps == 0 ? LEVEL_CAP[$game_system.level_cap] : Settings::MAXIMUM_LEVEL
    level_cap_gap = growth_rate.exp_values[level_cap] - pkmn.exp
    # Main Exp calculation
    exp = 0
    a = level * defeatedBattler.pokemon.base_exp
    if expShare.length > 0 && (isPartic || hasExpShare)
      if numPartic == 0   # No participants, all Exp goes to Exp Share holders
        exp = a / (Settings::SPLIT_EXP_BETWEEN_GAINERS ? expShare.length : 1)
      elsif Settings::SPLIT_EXP_BETWEEN_GAINERS   # Gain from participating and/or Exp Share
        exp = a / (2 * numPartic) if isPartic
        exp += a / (2 * expShare.length) if hasExpShare
      else   # Gain from participating and/or Exp Share (Exp not split)
        exp = (isPartic) ? a : a / 2
      end
    elsif isPartic   # Participated in battle, no Exp Shares held by anyone
      exp = a / (Settings::SPLIT_EXP_BETWEEN_GAINERS ? numPartic : 1)
    elsif expAll   # Didn't participate in battle, gaining Exp due to Exp All
      # NOTE: Exp All works like the Exp Share from Gen 6+, not like the Exp All
      #       from Gen 1, i.e. Exp isn't split between all Pokémon gaining it.
      exp = a / 2
    end
    return if exp <= 0
    # Pokémon gain more Exp from trainer battles
    exp = (exp * 1.5).floor if trainerBattle?
    # Scale the gained Exp based on the gainer's level (or not)
    if Settings::SCALED_EXP_FORMULA
      exp /= 5
      levelAdjust = ((2 * level) + 10.0) / (pkmn.level + level + 10.0)
      levelAdjust = levelAdjust**5
      levelAdjust = Math.sqrt(levelAdjust)
      exp *= levelAdjust
      exp = exp.floor
      exp += 1 if isPartic || hasExpShare
      if pkmn.level >= level_cap
        exp /= 250
      end
      if exp >= level_cap_gap
        exp = level_cap_gap + 1
      end
    else
      if a <= level_cap_gap
        exp = a
      else
        exp /= 7
      end
    end
    # Foreign Pokémon gain more Exp
    isOutsider = (pkmn.owner.id != pbPlayer.id ||
                 (pkmn.owner.language != 0 && pkmn.owner.language != pbPlayer.language))
    if isOutsider
      if pkmn.owner.language != 0 && pkmn.owner.language != pbPlayer.language
        exp = (exp * 1.7).floor
      else
        exp = (exp * 1.5).floor
      end
    end
    # Exp. Charm increases Exp gained
    exp = exp * 3 / 2 if $bag.has?(:EXPCHARM)
    # Modify Exp gain based on pkmn's held item
    i = Battle::ItemEffects.triggerExpGainModifier(pkmn.item, pkmn, exp)
    if i < 0
      i = Battle::ItemEffects.triggerExpGainModifier(@initialItems[0][idxParty], pkmn, exp)
    end
    exp = i if i >= 0
    # Boost Exp gained with high affection
    if Settings::AFFECTION_EFFECTS && @internalBattle && pkmn.affection_level >= 4 && !pkmn.mega?
      exp = exp * 6 / 5
      isOutsider = true   # To show the "boosted Exp" message
    end
    # Make sure Exp doesn't exceed the maximum
    expFinal = growth_rate.add_exp(pkmn.exp, exp)
    expGained = expFinal - pkmn.exp
    return if expGained <= 0
    # "Exp gained" message
    if showMessages
      if isOutsider
        pbDisplayPaused(_INTL("{1} got a boosted {2} Exp. Points!", pkmn.name, expGained))
      else
        pbDisplayPaused(_INTL("{1} got {2} Exp. Points!", pkmn.name, expGained))
      end
    end
    curLevel = pkmn.level
    newLevel = growth_rate.level_from_exp(expFinal)
    if newLevel < curLevel
      debugInfo = "Levels: #{curLevel}->#{newLevel} | Exp: #{pkmn.exp}->#{expFinal} | gain: #{expGained}"
      raise _INTL("{1}'s new level is less than its\r\ncurrent level, which shouldn't happen.\r\n[Debug: {2}]",
                  pkmn.name, debugInfo)
    end
    # Give Exp
    if pkmn.shadowPokemon?
      if pkmn.heartStage <= 3
        pkmn.exp += expGained
        $stats.total_exp_gained += expGained
      end
      return
    end
    $stats.total_exp_gained += expGained
    tempExp1 = pkmn.exp
    battler = pbFindBattler(idxParty)
    loop do   # For each level gained in turn...
      # EXP Bar animation
      levelMinExp = growth_rate.minimum_exp_for_level(curLevel)
      levelMaxExp = growth_rate.minimum_exp_for_level(curLevel + 1)
      tempExp2 = (levelMaxExp < expFinal) ? levelMaxExp : expFinal
      pkmn.exp = tempExp2
      @scene.pbEXPBar(battler, levelMinExp, levelMaxExp, tempExp1, tempExp2)
      tempExp1 = tempExp2
      curLevel += 1
      if curLevel > newLevel
        # Gained all the Exp now, end the animation
        pkmn.calc_stats
        battler&.pbUpdate(false)
        @scene.pbRefreshOne(battler.index) if battler
        break
      end
      # Levelled up
      pbCommonAnimation("LevelUp", battler) if battler
      oldTotalHP = pkmn.totalhp
      oldAttack  = pkmn.attack
      oldDefense = pkmn.defense
      oldSpAtk   = pkmn.spatk
      oldSpDef   = pkmn.spdef
      oldSpeed   = pkmn.speed
      if battler&.pokemon
        battler.pokemon.changeHappiness("levelup")
      end
      pkmn.calc_stats
      battler&.pbUpdate(false)
      @scene.pbRefreshOne(battler.index) if battler
      pbDisplayPaused(_INTL("{1} grew to Lv. {2}!", pkmn.name, curLevel))
      @scene.pbLevelUp(pkmn, battler, oldTotalHP, oldAttack, oldDefense,
                       oldSpAtk, oldSpDef, oldSpeed)
      # Learn all moves learned at this level
      moveList = pkmn.getMoveList
      moveList.each { |m| pbLearnMove(idxParty, m[1]) if m[0] == curLevel }
    end
  end
end


class PokemonPauseMenu_Scene
  def pbStartScene
    if $game_switches[NavNums::Dispose] == false
      $RepelToggle = false
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99999
      @sprites = {}
      @sprites["cmdwindow"] = Window_CommandPokemon.new([])
      @sprites["cmdwindow"].visible = false
      @sprites["cmdwindow"].viewport = @viewport
      @sprites["infowindow"] = Window_UnformattedTextPokemon.newWithSize("", 0, 0, 32, 32, @viewport)
      @sprites["infowindow"].visible = false
      @sprites["helpwindow"] = Window_UnformattedTextPokemon.newWithSize("", 0, 0, 32, 32, @viewport)
      @sprites["helpwindow"].visible = false
      @sprites["levelcapwindow"] = Window_UnformattedTextPokemon.newWithSize("Level Cap: #{LEVEL_CAP[$game_system.level_cap]}",0,64,208,64,@viewport)
      @sprites["levelcapwindow"].visible = false
      @infostate = false
      @helpstate = false
      $close_dexnav = 0
      $sprites = @sprites
      pbSEPlay("GUI menu open")
    else
      $viewport1.dispose
      $currentDexSearch = nil
      $close_dexnav = 1
      $game_switches[NavNums::Dispose] = false
      pbSEPlay("GUI menu close")
      $RepelToggle = true
      return
    end
  end
  def pbShowLevelCap
    if $PokemonSystem.level_caps == 0 && !$currentDexSearch
      @sprites["levelcapwindow"].visible = true
    end
  end
  def pbHideLevelCap
    @sprites["levelcapwindow"].visible = false
  end
  def pbShowMenu
    @sprites["cmdwindow"].visible = true
    @sprites["levelcapwindow"].visible = true if $PokemonSystem.level_caps
    @sprites["infowindow"].visible = @infostate
    @sprites["helpwindow"].visible = @helpstate
  end

  def pbHideMenu
    @sprites["cmdwindow"].visible = false
    @sprites["levelcapwindow"].visible = false if $PokemonSystem.level_caps
    @sprites["infowindow"].visible = false
    @sprites["helpwindow"].visible = false
  end
end

class PokemonPauseMenu
  def pbShowLevelCap
    @scene.pbShowLevelCap
  end

  def pbHideLevelCap
    @scene.pbHideLevelCap
  end

  def pbStartPokemonMenu
    if !$player
      if $DEBUG
        pbMessage(_INTL("The player trainer was not defined, so the pause menu can't be displayed."))
        pbMessage(_INTL("Please see the documentation to learn how to set up the trainer player."))
      end
      return
    end
    @scene.pbStartScene
    # Show extra info window if relevant
    pbShowInfo
    if $close_dexnav != 1
      $PokemonSystem.level_caps == 0 ? pbShowLevelCap : pbHideLevelCap
    end
    # Get all commands
    command_list = []
    commands = []
    MenuHandlers.each_available(:pause_menu) do |option, hash, name|
      command_list.push(name)
      commands.push(hash)
    end
    # Main loop
    end_scene = false
    loop do
      if !$currentDexSearch
        choice = @scene.pbShowCommands(command_list)
      else
        choice = -1
      end
      if choice < 0
        pbPlayCloseMenuSE if !$currentDexSearch
        end_scene = true
        break
      end
      break if commands[choice]["effect"].call(@scene)
    end
    if $close_dexnav != 0
      @scene.pbEndScene if end_scene
    end
  end
end

class PokemonSave_Scene
  def pbStartScreen
    @viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
    @viewport.z=99999
    @sprites={}
    totalsec = Graphics.frame_count / Graphics.frame_rate
    hour = totalsec / 60 / 60
    min = totalsec / 60 % 60
    mapname=$game_map.name
    textColor = ["7FE00000","463F0000","7FE00000"][$Trainer.gender]
    locationColor = "90F090,000000"   # green
    loctext=_INTL("<ac><c3={1}>{2}</c3></ac>",locationColor,mapname)
    loctext+=_INTL("Player<r><c2={1}>{2}</c2><br>",textColor,$Trainer.name)
    if hour>0
      loctext+=_INTL("Time<r><c2={1}>{2}h {3}m</c2><br>",textColor,hour,min)
    else
      loctext+=_INTL("Time<r><c2={1}>{2}m</c2><br>",textColor,min)
    end
    loctext+=_INTL("Badges<r><c2={1}>{2}</c2><br>",textColor,$Trainer.badge_count)
    if $Trainer.has_pokedex
      loctext+=_INTL("Pokédex<r><c2={1}>{2}/{3}</c2><br>",textColor,$Trainer.pokedex.owned_count,$Trainer.pokedex.seen_count)
    end
    @sprites["locwindow"]=Window_AdvancedTextPokemon.new(loctext)
    @sprites["locwindow"].viewport=@viewport
    @sprites["locwindow"].x=0
    @sprites["locwindow"].y=0
    @sprites["locwindow"].width=228 if @sprites["locwindow"].width<228
    @sprites["locwindow"].visible=true
  end
end

#Basic Settings
Settings::TIME_SHADING = false
Settings::MECHANICS_GENERATION = 8
Settings::SPEECH_WINDOWSKINS = [
#    "speech hgss 1",
#    "speech hgss 2",
#    "speech hgss 3",
#    "speech hgss 4",
#    "speech hgss 5",
#    "speech hgss 6",
#    "speech hgss 7",
#    "speech hgss 8",
#    "speech hgss 9",
#    "speech hgss 10",
#    "speech hgss 11",
#    "speech hgss 12",
#    "speech hgss 13",
#    "speech hgss 14",
#    "speech hgss 15",
#    "speech hgss 16",
#    "speech hgss 17",
#    "speech hgss 18",
#    "speech hgss 19",
#    "speech hgss 20",
#    "speech pl 18",
    "frlgtextskin"
  ]
Settings::MENU_WINDOWSKINS = [
#    "choice 1",
#    "choice 2",
#    "choice 3",
#    "choice 4",
#    "choice 5",
#    "choice 6",
#    "choice 7",
#    "choice 8",
#    "choice 9",
#    "choice 10",
#    "choice 11",
#    "choice 12",
#    "choice 13",
#    "choice 14",
#    "choice 15",
#    "choice 16",
#    "choice 17",
#    "choice 18",
#    "choice 19",
#    "choice 20",
#    "choice 21",
#    "choice 22",
#    "choice 23",
#    "choice 24",
#    "choice 25",
#    "choice 26",
#    "choice 27",
#    "choice 28",
    "frlgtextskin"
  ]
PokemonRegionMap_Scene::SQUARE_WIDTH = 8
PokemonRegionMap_Scene::SQUARE_HEIGHT = 8
PokemonRegionMap_Scene::RIGHT = 58
PokemonRegionMap_Scene::BOTTOM = 38

def write_version(path = "version.txt")
  File.open(path, "wb") { |f|
    version = Settings::GAME_VERSION
    f.write("#{version}")
  }
end

class PokemonLoadScreen
  def pbStartLoadScreen
    commands = []
    cmd_continue     = -1
    cmd_new_game     = -1
    cmd_options      = -1
    cmd_language     = -1
    cmd_mystery_gift = -1
    cmd_debug        = -1
    cmd_quit         = -1
    show_continue = !@save_data.empty?
    if show_continue
      commands[cmd_continue = commands.length] = _INTL("Continue")
      if @save_data[:player].mystery_gift_unlocked
        commands[cmd_mystery_gift = commands.length] = _INTL("Mystery Gift")
      end
    end
    commands[cmd_new_game = commands.length]  = _INTL("New Game")
    commands[cmd_options = commands.length]   = _INTL("Options")
    commands[cmd_language = commands.length]  = _INTL("Language") if Settings::LANGUAGES.length >= 2
    commands[cmd_debug = commands.length]     = _INTL("Debug") if $DEBUG
    commands[cmd_quit = commands.length]      = _INTL("Quit Game")
    map_id = show_continue ? @save_data[:map_factory].map.map_id : 0
    @scene.pbStartScene(commands, show_continue, @save_data[:player],
                        @save_data[:frame_count] || 0, @save_data[:stats], map_id)
    @scene.pbSetParty(@save_data[:player]) if show_continue
    @scene.pbStartScene2
    loop do
      command = @scene.pbChoose(commands)
      pbPlayDecisionSE if command != cmd_quit
      case command
      when cmd_continue
        @scene.pbEndScene
        Game.load(@save_data)
        return
      when cmd_new_game
        @scene.pbEndScene
        Game.start_new
        return
      when cmd_mystery_gift
        pbFadeOutIn { pbDownloadMysteryGift(@save_data[:player]) }
      when cmd_options
        pbFadeOutIn do
          scene = PokemonOption_Scene.new
          screen = PokemonOptionScreen.new(scene)
          screen.pbStartScreen(true)
        end
      when cmd_language
        @scene.pbEndScene
        $PokemonSystem.language = pbChooseLanguage
        pbLoadMessages("Data/" + Settings::LANGUAGES[$PokemonSystem.language][1])
        if show_continue
          @save_data[:pokemon_system] = $PokemonSystem
          File.open(SaveData::FILE_PATH, "wb") { |file| Marshal.dump(@save_data, file) }
        end
        $scene = pbCallTitle
        return
      when cmd_debug
        pbFadeOutIn { pbDebugMenu(false) }
      when cmd_quit
        pbPlayCloseMenuSE
        @scene.pbEndScene
        $scene = nil
        return
      else
        pbPlayBuzzerSE
      end
    end
  end
end
class Battle::Battler
  def pbObedienceCheck?(choice)
    return true if usingMultiTurnAttack?
    return true if choice[0] != :UseMove
    return true if !@battle.internalBattle
    return true if !@battle.pbOwnedByPlayer?(@index)
    disobedient = false
    # Pokémon may be disobedient; calculate if it is
    badge_level = 10 * (@battle.pbPlayer.badge_count + 1)
    badge_level = GameData::GrowthRate.max_level if @battle.pbPlayer.badge_count >= 8
    badge_level = LEVEL_CAP[$game_system.level_cap] if @battle.pbPlayer.badge_count >= 8 && $PokemonSystem.level_caps == 0
    if Settings::ANY_HIGH_LEVEL_POKEMON_CAN_DISOBEY ||
       (Settings::FOREIGN_HIGH_LEVEL_POKEMON_CAN_DISOBEY && @pokemon.foreign?(@battle.pbPlayer))
      if @level > badge_level
        a = ((@level + badge_level) * @battle.pbRandom(256) / 256).floor
        disobedient |= (a >= badge_level)
      end
    end
    disobedient |= !pbHyperModeObedience(choice[2])
    return true if !disobedient
    # Pokémon is disobedient; make it do something else
    return pbDisobey(choice, badge_level)
  end
end

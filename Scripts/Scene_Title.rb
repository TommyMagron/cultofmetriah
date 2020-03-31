#==============================================================================
# ** Scene_Title
#------------------------------------------------------------------------------
#  This class performs the title screen processing.
#==============================================================================

class Scene_Title < Scene_Base
  #--------------------------------------------------------------------------
  # * Start Processing
  #--------------------------------------------------------------------------
  def start
    super
    SceneManager.clear
    Graphics.freeze
    @spritesheet = Sprite.new
    @spritesheet.bitmap = Cache.title2($data_system.title2_name)
    create_background
    create_foreground
    create_command_window
    play_title_music

  end
  #--------------------------------------------------------------------------
  # * Get Transition Speed
  #--------------------------------------------------------------------------
  def transition_speed
    return 20
  end
  #--------------------------------------------------------------------------
  # * Termination Processing
  #--------------------------------------------------------------------------
  def terminate
    super
    SceneManager.snapshot_for_background
    dispose_background
    dispose_foreground
  end
  #--------------------------------------------------------------------------
  # * Create Background
  #--------------------------------------------------------------------------
  def create_background
    @sprite1 = Sprite.new
    @sprite1.bitmap = Cache.title1($data_system.title1_name)
    center_sprite(@sprite1)
  end

  def create_rideaux
    @sprites_rideau = []
    for i in (0..15)
      sprite_rideau = Sprite.new(@viewport)
      sprite_rideau.bitmap = Bitmap.new(32, 32)
      sprite_rideau.ox = sprite_rideau.bitmap.width / 2
      sprite_rideau.oy = sprite_rideau.bitmap.height / 2
      @spritesheet.src_rect.set(1, 215, 32, 32)
      sprite_rideau.bitmap.blt(0, 0, @spritesheet.bitmap, @spritesheet.src_rect)
      sprite_rideau.z = 100
      sprite_rideau.zoom_x = 4.3
      sprite_rideau.zoom_y = 4.3
      sprite_rideau.angle = 180

      if i % 2 != 0 then
        sprite_rideau.mirror = true
      end

      @sprites_rideau.push(sprite_rideau)

      x = 0
      for sprite_rideau in @sprites_rideau
          sprite_rideau.x = x * 128
          sprite_rideau.y = 64
          x += 1
      end
    end
  end

  def create_murs
    @sprites_murs = []
    @sprites_murs_ombre = []

    y = 0
    for i in (0..35)
      sprite_mur = Sprite.new(@viewport)
      sprite_mur.bitmap = Bitmap.new(32, 16)
      sprite_mur_ombre = Sprite.new(@viewport)
      sprite_mur_ombre.bitmap = Bitmap.new(16, 32)
      sprite_mur.ox = sprite_mur.bitmap.width / 2
      sprite_mur.oy = sprite_mur.bitmap.height / 2
      sprite_mur_ombre.ox = sprite_mur_ombre.bitmap.width / 2
      sprite_mur_ombre.oy = sprite_mur_ombre.bitmap.height / 2
      @spritesheet.src_rect.set(60, 230, 32, 16)
      sprite_mur.bitmap.blt(0, 0, @spritesheet.bitmap, @spritesheet.src_rect)
      @spritesheet.src_rect.set(38, 213, 16, 32)
      sprite_mur_ombre.bitmap.blt(0, 0, @spritesheet.bitmap, @spritesheet.src_rect)
      sprite_mur.zoom_x = 4
      sprite_mur.zoom_y = 4
      sprite_mur_ombre.zoom_x = 4
      sprite_mur_ombre.zoom_y = 4
      sprite_mur.z = 50
      sprite_mur_ombre.z = 80
      sprite_mur_ombre.opacity = 100

      if i % 2 == 0 then
        sprite_mur.x = 64
        sprite_mur_ombre.x = 64
        sprite_mur_ombre.angle = -90
      else
        sprite_mur.x = Graphics.width - 64
        sprite_mur_ombre.x = Graphics.width - 64
        sprite_mur.mirror = true
        sprite_mur_ombre.angle = 90
        sprite_mur_ombre.mirror = true
        y += 1
      end

      sprite_mur.y = y * 64
      sprite_mur_ombre.y = y * 64

      @sprites_murs.push(sprite_mur)
      @sprites_murs_ombre.push(sprite_mur_ombre)
    end
  end

  #--------------------------------------------------------------------------
  # * Create Foreground
  #--------------------------------------------------------------------------
  def create_foreground
    @viewport2 = Viewport.new
    @viewport2.z = 300
    @overlay = Sprite.new(@viewport2)
    @overlay.bitmap = Bitmap.new(1920, 1080)
    @overlay.bitmap.fill_rect(0, 0, 1920, 1080, Color.new(255,255,255))
    create_rideaux
    create_murs

    @foreground_sprite = Sprite.new
    @foreground_sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
    @foreground_sprite.z = 100

    draw_game_title if $data_system.opt_draw_title
  end
  #--------------------------------------------------------------------------
  # * Draw Game Title
  #--------------------------------------------------------------------------
  def draw_game_title
    @foreground_sprite.bitmap.font.size = 48
    rect = Rect.new(0, 0, Graphics.width, Graphics.height / 2)
    @foreground_sprite.bitmap.draw_text(rect, $data_system.game_title, 1)
  end
  #--------------------------------------------------------------------------
  # * Free Background
  #--------------------------------------------------------------------------
  def dispose_background
    @sprite1.bitmap.dispose
    @sprite1.dispose
  end
  #--------------------------------------------------------------------------
  # * Free Foreground
  #--------------------------------------------------------------------------
  def dispose_foreground
    @foreground_sprite.bitmap.dispose
    @foreground_sprite.dispose
  end
  #--------------------------------------------------------------------------
  # * Move Sprite to Screen Center
  #--------------------------------------------------------------------------
  def center_sprite(sprite)
    sprite.ox = sprite.bitmap.width / 2
    sprite.oy = sprite.bitmap.height / 2
    sprite.x = Graphics.width / 2
    sprite.y = Graphics.height / 2
  end
  #--------------------------------------------------------------------------
  # * Create Command Window
  #--------------------------------------------------------------------------
  def create_command_window
    @command_window = Window_TitleCommand.new
    @command_window.set_handler(:new_game, method(:command_new_game))
    @command_window.set_handler(:continue, method(:command_continue))
    @command_window.set_handler(:shutdown, method(:command_shutdown))
  end
  #--------------------------------------------------------------------------
  # * Close Command Window
  #--------------------------------------------------------------------------
  def close_command_window
    @command_window.close
    update until @command_window.close?
  end
  #--------------------------------------------------------------------------
  # * [New Game] Command
  #--------------------------------------------------------------------------
  def command_new_game
    DataManager.setup_new_game
    close_command_window
    fadeout_all
    $game_map.autoplay
    SceneManager.goto(Scene_Map)
  end
  #--------------------------------------------------------------------------
  # * [Continue] Command
  #--------------------------------------------------------------------------
  def command_continue
    close_command_window
    SceneManager.call(Scene_Load)
  end
  #--------------------------------------------------------------------------
  # * [Shut Down] Command
  #--------------------------------------------------------------------------
  def command_shutdown
    close_command_window
    fadeout_all
    SceneManager.exit
  end
  #--------------------------------------------------------------------------
  # * Play Title Screen Music
  #--------------------------------------------------------------------------
  def play_title_music
    $data_system.title_bgm.play
    RPG::BGS.stop
    RPG::ME.stop
  end

  def update
    super
    @overlay.opacity = @overlay.opacity - 2 
  end
end

TILE_WIDTH = 128
TILE_HEIGHT = 64

TILE_WIDTH_HALF = TILE_WIDTH / 2
TILE_HEIGHT_HALF = TILE_HEIGHT / 2

SPACE_BETWEEN_ORIGIN_TILEMAP_AND_SCREEN_TOP_BORDER = TILE_HEIGHT

class Sprite_Character < Sprite_Base

  def initialize(viewport, character = nil)
    super(viewport)
    #@debug = QDebug.new
    @character = character
    @balloon_duration = 0
    #@losange = Bitmap.new("Graphics/Pictures/losange_128_64.png")
    #@spriteLosange = Sprite.new
    #@spriteLosange.bitmap = @losange
    update
  end

  #--------------------------------------------------------------------------
  # * Set Character Bitmap
  #--------------------------------------------------------------------------
  def set_character_bitmap
    self.bitmap = Cache.character(@character_name)
    sign = @character_name[/^[\!\$]./]
    if sign && sign.include?('$')
      @cw = bitmap.width / 3
      @ch = bitmap.height / 4
    else
      @cw = bitmap.width / 8
      @ch = bitmap.height / 4
    end
    self.ox = @cw / 2
    self.oy = @ch
  end

  #--------------------------------------------------------------------------
  # * Update Transfer Origin Rectangle
  #--------------------------------------------------------------------------
  def update_src_rect
    if @tile_id == 0
      #index = @character.character_index : le personnage possède tout son sprite
      pattern = @character.pattern < 8 ? @character.pattern : 1 #@TODO : change pattern calculation (pattern represents one column)
      sx = pattern * @cw #@TODO test sprite complet, replace (index % 4 * 3 + pattern) * @cw
      sy = ((@character.direction - 2) / 2) * @ch
      self.src_rect.set(sx, sy, @cw, @ch)
    end
  end
end

class Game_CharacterBase

  SPACE_BETWEEN_CHARACTERN_PATTERN = 12

  #--------------------------------------------------------------------------
  # * Initialize Public Member Variables
  #--------------------------------------------------------------------------
  def init_public_members
    #@debug = QDebug.new
    @id = 0
    @x = 0
    @y = 0
    @real_x = 0
    @real_y = 0
    @tile_id = 0
    @character_name = ""
    @character_index = 0
    @move_speed = 4
    @move_frequency = 6
    @walk_anime = true
    @step_anime = false
    @direction_fix = false
    @opacity = 255
    @blend_type = 0
    @direction = 6
    @pattern = 1
    @priority_type = 1
    @through = false
    @bush_depth = 0
    @animation_id = 0
    @balloon_id = 0
    @transparent = false
  end

  #--------------------------------------------------------------------------
  # * Get Screen X-Coordinates
  #--------------------------------------------------------------------------
  def screen_x
    ($game_map.adjust_x(@real_x) - $game_map.adjust_y(@real_y)) * TILE_WIDTH_HALF  + TILE_WIDTH_HALF
  end
  #--------------------------------------------------------------------------
  # * Get Screen Y-Coordinates
  #--------------------------------------------------------------------------
  def screen_y
     ($game_map.adjust_x(@real_x) + $game_map.adjust_y(@real_y)) * TILE_HEIGHT_HALF  + SPACE_BETWEEN_ORIGIN_TILEMAP_AND_SCREEN_TOP_BORDER + TILE_HEIGHT_HALF + SPACE_BETWEEN_CHARACTERN_PATTERN - jump_height
  end

  #--------------------------------------------------------------------------
  # * Move Straight
  #     d:        Direction (2,4,6,8)
  #     turn_ok : Allows change of direction on the spot
  #--------------------------------------------------------------------------
  def move_straight(d, turn_ok = true)
    @move_succeed = passable?(@x, @y, d)
    if @move_succeed
      set_direction(d)
      @x = $game_map.round_x_with_direction(@x, d)
      @y = $game_map.round_y_with_direction(@y, d)
      @real_x = $game_map.x_with_direction(@x, reverse_dir(d))
      @real_y = $game_map.y_with_direction(@y, reverse_dir(d))
      increase_steps
    elsif turn_ok
      set_direction(d)
      check_event_trigger_touch_front
    end
  end
end

class Spriteset_Map

  def initialize
    #@debug = QDebug.new
    create_viewports
    create_tilemap
    create_parallax
    create_characters
    create_shadow
    create_weather
    create_pictures
    create_timer
    update
  end

  #--------------------------------------------------------------------------
  # * Update Tilemap
  #--------------------------------------------------------------------------
  def update_tilemap
    @tilemap.map_data = $game_map.data
    @tilemap.ox = ($game_map.display_x - $game_map.display_y) * TILE_WIDTH_HALF
    @tilemap.oy = ($game_map.display_x + $game_map.display_y) * TILE_HEIGHT_HALF
    @tilemap.update
  end

  #--------------------------------------------------------------------------
  # * Update Weather
  #--------------------------------------------------------------------------
  def update_weather
    @weather.type = $game_map.screen.weather_type
    @weather.power = $game_map.screen.weather_power
    @weather.ox = $game_map.display_x * TILE_WIDTH_HALF
    @weather.oy = $game_map.display_y * TILE_HEIGHT
    @weather.update
  end
end

class Game_Map

  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  def initialize
    #@debug = QDebug.new
    @screen = Game_Screen.new
    @interpreter = Game_Interpreter.new
    @map_id = 0
    @events = {}
    @display_x = 0
    @display_y = 0
    create_vehicles
    @name_display = true
  end

  #--------------------------------------------------------------------------
  # * Number of Horizontal Tiles on Screen
  #--------------------------------------------------------------------------
  def screen_tile_x
    Graphics.width / TILE_WIDTH_HALF
  end

  #--------------------------------------------------------------------------
  # * Number of Vertical Tiles on Screen
  #--------------------------------------------------------------------------
  def screen_tile_y
    Graphics.height / TILE_HEIGHT_HALF
  end

  #--------------------------------------------------------------------------
  # * Calculate X Coordinate of Parallax Display Origin
  #--------------------------------------------------------------------------
  def parallax_ox(bitmap)
      w1 = [bitmap.width - Graphics.width, 0].max
      w2 = [width * TILE_WIDTH_HALF - Graphics.width, 1].max
      (@parallax_x - @parallax_y) * TILE_WIDTH_HALF
  end

  #--------------------------------------------------------------------------
  # * Calculate Y Coordinate of Parallax Display Origin
  #--------------------------------------------------------------------------
  def parallax_oy(bitmap)
      h1 = [bitmap.height - Graphics.height, 0].max
      h2 = [height * TILE_HEIGHT_HALF - Graphics.height, 1].max
      (@parallax_x + @parallax_y) * TILE_HEIGHT_HALF
  end

  #--------------------------------------------------------------------------
  # * Set Display Position
  #--------------------------------------------------------------------------
  def set_display_pos(x, y)
    x = [0, [x, width - screen_tile_x].min].max unless loop_horizontal?
    y = [0, [y, height - screen_tile_y].min].max unless loop_vertical?
    @display_x = x
    @display_y = y
    @parallax_x = x
    @parallax_y = y
  end

  #--------------------------------------------------------------------------
  # * Scroll Setup
  #--------------------------------------------------------------------------
  def setup_scroll
    @scroll_direction = 2
    @scroll_rest = 0
    @scroll_speed = 4
  end

  #--------------------------------------------------------------------------
  # * Calculate Scroll Distance
  #--------------------------------------------------------------------------
  def scroll_distance
    2 ** @scroll_speed / 256.0
  end

  #--------------------------------------------------------------------------
  # * Scroll Down
  #--------------------------------------------------------------------------
  def scroll_down(distance)
    if loop_vertical?
      @display_y += distance
      @display_y %= @map.height
      @parallax_y += distance if @parallax_loop_y
    else
      last_y = @display_y
      @display_y = [@display_y + distance, height - screen_tile_y].min
      @parallax_y += @display_y - last_y
    end
  end
  #--------------------------------------------------------------------------
  # * Scroll Left
  #--------------------------------------------------------------------------
  def scroll_left(distance)
    if loop_horizontal?
      @display_x += @map.width - distance
      @display_x %= @map.width 
      @parallax_x -= distance if @parallax_loop_x
    else
      last_x = @display_x
      @display_x = [@display_x - distance, 0].max
      @parallax_x += @display_x - last_x
    end
  end
  #--------------------------------------------------------------------------
  # * Scroll Right
  #--------------------------------------------------------------------------
  def scroll_right(distance)
    if loop_horizontal?
      @display_x += distance
      @display_x %= @map.width
      @parallax_x += distance if @parallax_loop_x
    else
      last_x = @display_x
      @display_x = [@display_x + distance, (width - screen_tile_x)].min
      @parallax_x += @display_x - last_x
    end
  end
  #--------------------------------------------------------------------------
  # * Scroll Up
  #--------------------------------------------------------------------------
  def scroll_up(distance)
    if loop_vertical?
      @display_y += @map.height - distance
      @display_y %= @map.height
      @parallax_y -= distance if @parallax_loop_y
    else
      last_y = @display_y
      @display_y = [@display_y - distance, 0].max
      @parallax_y += @display_y - last_y
    end
  end
end

class Game_Player < Game_Character
  def initialize
    super
    #@debug = QDebug.new
    @vehicle_type = :walk           # Type of vehicle currently being ridden
    @vehicle_getting_on = false     # Boarding vehicle flag
    @vehicle_getting_off = false    # Getting off vehicle flag
    @followers = Game_Followers.new(self)
    @transparent = $data_system.opt_transparent
    clear_transfer_info
  end

  #--------------------------------------------------------------------------
  # * Frame Update
  #--------------------------------------------------------------------------
  def update
    last_real_x = @real_x
    last_real_y = @real_y
    last_moving = moving?
    move_by_input
    super
    update_scroll(last_real_x, last_real_y)
    update_vehicle
    update_nonmoving(last_moving) unless moving?
    @followers.update
  end

  #--------------------------------------------------------------------------
  # * Move to Designated Position
  #--------------------------------------------------------------------------
  def moveto(x, y)
    super
    center(x, y)
    make_encounter_count
    vehicle.refresh if vehicle
    @followers.synchronize(x, y, direction)
  end

  #--------------------------------------------------------------------------
  # * X Coordinate of Screen Center
  #--------------------------------------------------------------------------
  def center_x
    (Graphics.width / TILE_WIDTH_HALF - 1) / 2
  end

  #--------------------------------------------------------------------------
  # * Y Coordinate of Screen Center
  #--------------------------------------------------------------------------
  def center_y
    (Graphics.height / TILE_HEIGHT - 1) / 2
  end

  def center_screen_x
    Graphics.width / 2 - TILE_WIDTH_HALF
  end

  def center_screen_y
    Graphics.height / 2
  end


  #----------------------------------------------------------------------------------------------
  # * Set Map Display Position to Center of Screen
  #   TILE_HEIGHT => Correspond à l'espace entre l'origine de la carte et le bord haut de l'ecran
  #   Cela est dû à la transformation de la carte
  #----------------------------------------------------------------------------------------------
  def center(x, y)

    # Get screen coordinates
    screen_x = (x - y) * TILE_WIDTH_HALF
    screen_y = (x + y) * TILE_HEIGHT_HALF + SPACE_BETWEEN_ORIGIN_TILEMAP_AND_SCREEN_TOP_BORDER

    # Calculate distance from center screen
    distance_from_center_x = screen_x - center_screen_x
    distance_from_center_y = screen_y - center_screen_y

    # Calculate parallax origin tile with new screen coordinates
    parallax_x = (distance_from_center_x / TILE_WIDTH_HALF + distance_from_center_y / TILE_HEIGHT_HALF) / 2
    parallax_y = (distance_from_center_y / TILE_HEIGHT_HALF - distance_from_center_x / TILE_WIDTH_HALF) / 2

    $game_map.set_display_pos(parallax_x, parallax_y)
  end

  #--------------------------------------------------------------------------
  # * Scroll Processing
  #--------------------------------------------------------------------------
  def update_scroll(last_real_x, last_real_y)
    screen_x1 = (last_real_x - last_real_y) * TILE_WIDTH_HALF
    screen_y1 = (last_real_x + last_real_y) * TILE_HEIGHT_HALF + TILE_HEIGHT_HALF + SPACE_BETWEEN_ORIGIN_TILEMAP_AND_SCREEN_TOP_BORDER
    screen_x2 = (@real_x - @real_y) * TILE_WIDTH_HALF
    screen_y2 = (@real_x + @real_y) * TILE_HEIGHT_HALF + TILE_HEIGHT_HALF + SPACE_BETWEEN_ORIGIN_TILEMAP_AND_SCREEN_TOP_BORDER

    screen_tile_displayed_x = ($game_map.display_x - $game_map.display_y) * TILE_WIDTH_HALF
    screen_tile_displayed_y = ($game_map.display_x + $game_map.display_y) * TILE_HEIGHT_HALF

    distance_from_screen_x2 = screen_x2 - screen_tile_displayed_x
    distance_from_screen_y2 = screen_y2 - screen_tile_displayed_y

    $game_map.scroll_down (@real_y - last_real_y) if @real_y > last_real_y && distance_from_screen_y2 > center_screen_y
    $game_map.scroll_left (last_real_x - @real_x) if @real_x < last_real_x && distance_from_screen_x2 < center_screen_x
    $game_map.scroll_right(@real_x - last_real_x) if @real_x > last_real_x && distance_from_screen_x2 > center_screen_x
    $game_map.scroll_up   (last_real_y - @real_y) if @real_y < last_real_y && distance_from_screen_y2 < center_screen_y
  end
end

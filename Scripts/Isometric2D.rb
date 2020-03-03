TILE_WIDTH_HALF = 32
TILE_HEIGHT_HALF = 16
ADJUST_HEIGHT_MAP_START = 96

class Sprite_Character < Sprite_Base

  def initialize(viewport, character = nil)
    super(viewport)
    #@debug = QDebug.new
    #@losange = Bitmap.new("Graphics/Pictures/losange_64_32.png")
    #@spriteLosange = Sprite.new
    #@spriteLosange.bitmap = @losange
    @character = character
    @balloon_duration = 0
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



  def update_position
    #@spriteLosange.x = ((0 - 0) * TILE_WIDTH_HALF) + Graphics.width / 2 - TILE_WIDTH_HALF
    #@spriteLosange.y = ((0 + 0) * TILE_HEIGHT_HALF) + 64
    move_animation(@character.screen_x - x, @character.screen_y - y)
    self.x = @character.screen_x
    self.y = @character.screen_y
    self.z = @character.screen_z
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
    @tilemap.ox = ($game_map.display_x * 64) / 2
    @tilemap.oy = ($game_map.display_y * 32) / 2
    @tilemap.update
  end

  #--------------------------------------------------------------------------
  # * Update Weather
  #--------------------------------------------------------------------------
  def update_weather
    @weather.type = $game_map.screen.weather_type
    @weather.power = $game_map.screen.weather_power
    @weather.ox = $game_map.display_x * 64
    @weather.oy = $game_map.display_y * 32
    @weather.update
  end
end

class Game_CharacterBase

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
  # * Get Number of Pixels to Shift Up from Tile Position
  #--------------------------------------------------------------------------
  def shift_y
    object_character? ? 0 : 10
  end
  #--------------------------------------------------------------------------
  # * Get Screen X-Coordinates
  #--------------------------------------------------------------------------
  def screen_x
    xCoordinate = $game_map.adjust_x(@real_x)
    yCoordinate = $game_map.adjust_y(@real_y)
    ((xCoordinate - yCoordinate) * TILE_WIDTH_HALF) + (Graphics.width / 2)
  end
  #--------------------------------------------------------------------------
  # * Get Screen Y-Coordinates
  #--------------------------------------------------------------------------
  def screen_y
    xCoordinate = $game_map.adjust_x(@real_x)
    yCoordinate = $game_map.adjust_y(@real_y)
    ((xCoordinate + yCoordinate) * TILE_HEIGHT_HALF) + ADJUST_HEIGHT_MAP_START - shift_y - jump_height
  end

  #--------------------------------------------------------------------------
  # * Get Move Speed (Account for Dash)
  #--------------------------------------------------------------------------
  def real_move_speed
    @move_speed + (dash? ? 1 : 0)
  end

  #--------------------------------------------------------------------------
  # * Calculate Move Distance per Frame
  #--------------------------------------------------------------------------
  def distance_per_frame
    2 ** real_move_speed / 256.0
  end

  #--------------------------------------------------------------------------
  # * Move Straight
  #     d:        Direction (2,4,6,8)
  #     turn_ok : Allows change of direction on the spot
  #--------------------------------------------------------------------------
  def move_straight(d, turn_ok = true)
    #@debug.refresh(0, @x)
    #@debug.refresh(1, @y)
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
    Graphics.width / 64
  end
  #--------------------------------------------------------------------------
  # * Number of Vertical Tiles on Screen
  #--------------------------------------------------------------------------
  def screen_tile_y
    Graphics.height / 32
  end

  #--------------------------------------------------------------------------
  # * Set Display Position
  #--------------------------------------------------------------------------
  def set_display_pos(x, y)
    x = [0, [x, width - screen_tile_x].min].max unless loop_horizontal?
    y = [0, [y, height - screen_tile_y].min].max unless loop_vertical?
    @display_x = (x + width) % width
    @display_y = (y + height) % height
    @parallax_x = x
    @parallax_y = y
  end
  #--------------------------------------------------------------------------
  # * Calculate X Coordinate of Parallax Display Origin
  #--------------------------------------------------------------------------
  def parallax_ox(bitmap)
    if @parallax_loop_x
      @parallax_x * 32
    else
      w1 = [bitmap.width - Graphics.width, 0].max
      w2 = [width * 64 - Graphics.width, 1].max
      @parallax_x * 32 * w1 / w2
    end
  end
  #--------------------------------------------------------------------------
  # * Calculate Y Coordinate of Parallax Display Origin
  #--------------------------------------------------------------------------
  def parallax_oy(bitmap)
    if @parallax_loop_y
      @parallax_y * 16
    else
      h1 = [bitmap.height - Graphics.height, 0].max
      h2 = [height * 32 - Graphics.height, 1].max
      @parallax_y * 16 * h1 / h2
    end
  end

  #--------------------------------------------------------------------------
  # * Calculate X Coordinate, Minus Display Coordinate
  #--------------------------------------------------------------------------
  def adjust_x(x)
    if loop_horizontal? && x < @display_x - (width - screen_tile_x) / 2
      x - @display_x + @map.width
    else
      #@debug.refresh(0,  x - @display_x)
      x - @display_x
    end
  end
  #--------------------------------------------------------------------------
  # * Calculate Y Coordinate, Minus Display Coordinate
  #--------------------------------------------------------------------------
  def adjust_y(y)
    if loop_vertical? && y < @display_y - (height - screen_tile_y) / 2
      y - @display_y + @map.height
    else
      #@debug.refresh(1, @display_y) # @display_y vaut -3 ??
      y - @display_y
    end
  end

  #--------------------------------------------------------------------------
  # * Calculate X Coordinate After Loop Adjustment
  # * @TODO a modifier pour vue isometrique
  #--------------------------------------------------------------------------
  def round_x(x)
    loop_horizontal? ? (x + width) % width : x
  end
  #--------------------------------------------------------------------------
  # * Calculate Y Coordinate After Loop Adjustment
  # * @TODO a modifier pour vue isometrique
  #--------------------------------------------------------------------------
  def round_y(y)
    loop_vertical? ? (y + height) % height : y
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
  # * Scroll Up
  #--------------------------------------------------------------------------
  def scroll_up(distance)
    if loop_horizontal?
      @display_x += distance
      @display_x %= @map.width
      @parallax_x += distance if @parallax_loop_x
    else
      last_x = @display_x
      @display_x = [@display_x + distance, (width - screen_tile_x)].min
      @parallax_x += @display_x - last_x
    end
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
    @debug = QDebug.new
    @vehicle_type = :walk           # Type of vehicle currently being ridden
    @vehicle_getting_on = false     # Boarding vehicle flag
    @vehicle_getting_off = false    # Getting off vehicle flag
    @followers = Game_Followers.new(self)
    @transparent = $data_system.opt_transparent
    clear_transfer_info
  end

  def center_x
    (Graphics.width / 64 - 1) / 2.0
  end
  
  #--------------------------------------------------------------------------
  # * Y Coordinate of Screen Center
  #--------------------------------------------------------------------------
  def center_y
    (Graphics.height / 32 - 1) / 2.0
  end

  #--------------------------------------------------------------------------
  # * Set Map Display Position to Center of Screen
  #--------------------------------------------------------------------------
  def center(x, y)
    @debug.refresh(0,  center_x)
    @debug.refresh(1,  center_y)
    $game_map.set_display_pos(x - center_x, y - center_y)
  end



end
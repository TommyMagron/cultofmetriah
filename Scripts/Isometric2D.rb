
class Sprite_Character < Sprite_Base

  def initialize(viewport, character = nil)
    super(viewport)
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
end

class Spriteset_Map
  #--------------------------------------------------------------------------
  # * Update Tilemap
  #--------------------------------------------------------------------------
  def update_tilemap
    @tilemap.map_data = $game_map.data
    @tilemap.ox = $game_map.display_x * 128
    @tilemap.oy = $game_map.display_y * 64
    @tilemap.update
  end

  #--------------------------------------------------------------------------
  # * Update Weather
  #--------------------------------------------------------------------------
  def update_weather
    @weather.type = $game_map.screen.weather_type
    @weather.power = $game_map.screen.weather_power
    @weather.ox = $game_map.display_x * 128
    @weather.oy = $game_map.display_y * 64
    @weather.update
  end
end

class Game_CharacterBase
  

  TILE_WIDTH_HALF = 64
  TILE_HEIGHT_HALF = 32
  ADJUST_ORIGIN_SCREEN_Y_COORDINATES = 96

  #--------------------------------------------------------------------------
  # * Initialize Public Member Variables
  #--------------------------------------------------------------------------
  def init_public_members
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
    object_character? ? 0 : 8
  end
  #--------------------------------------------------------------------------
  # * Get Screen X-Coordinates
  #--------------------------------------------------------------------------
  def screen_x
    xCoordinate = $game_map.adjust_x(@real_x)
    yCoordinate = $game_map.adjust_y(@real_y)
    ((xCoordinate - yCoordinate) * TILE_WIDTH_HALF) + (Graphics.width / 2 - TILE_WIDTH_HALF)
  end
  #--------------------------------------------------------------------------
  # * Get Screen Y-Coordinates
  #--------------------------------------------------------------------------
  def screen_y
    xCoordinate = $game_map.adjust_x(@real_x)
    yCoordinate = $game_map.adjust_y(@real_y)
    ((xCoordinate + yCoordinate) * TILE_HEIGHT_HALF  + ADJUST_ORIGIN_SCREEN_Y_COORDINATES) - shift_y - jump_height
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
end

class Game_Map

#--------------------------------------------------------------------------
  # * Number of Horizontal Tiles on Screen
  #--------------------------------------------------------------------------
  def screen_tile_x
    Graphics.width / 128
  end
  #--------------------------------------------------------------------------
  # * Number of Vertical Tiles on Screen
  #--------------------------------------------------------------------------
  def screen_tile_y
    Graphics.height / 64
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

  def center_x
    ($game_map.screen_tile_x / 128 - 1) / 2.0
  end
  #--------------------------------------------------------------------------
  # * Y Coordinate of Screen Center
  #--------------------------------------------------------------------------
  def center_y
    ($game_map.screen_tile_y / 64 - 1) / 2.0
  end

end
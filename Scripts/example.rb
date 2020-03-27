#==============================================================================
# MBS - Isometric
#------------------------------------------------------------------------------
#================================================================================
# Instructions
#------------------------------------------------- -----------------------------
# 1. Tileset
#
# Le script utilise un jeu de tuiles avec des cubes isométriques, la grille du jeu de tuiles doit avoir
# 64 pixels, le jeu de tuiles doit avoir 8 colonnes et un maximum de 16 lignes.
# La première tuile du jeu de tuiles sera toujours transparente, vous pouvez donc
# que vous voulez dedans (un modèle pour les blocs, par exemple).
# Ensuite, enregistrez simplement le jeu de tuiles dans le dossier du jeu et configurez le chemin du
# fichier.
# Les ensembles de tuiles isométriques doivent avoir le nom des ensembles de tuiles dans la base de données (Ex.:
# Le jeu de tuiles 'Mundo' dans la base de données charge le jeu de tuiles isométrique 'Mundo.png' dans
# dossier choisi)
#
# 2. Configuration dans la base de données
#
# Le jeu de tuiles dans la base de données doit avoir seulement les tuiles A5 et B-E, toutes les autres tuiles seront
# ignoré.
# Dans les onglets B-E, toutes les tuiles qui ont une continuation verticale (par exemple,
# exemple un arbre) doit être récolté avec la terre, la terre (0-7) détermine
# la hauteur de cette tuile (dans l'exemple de l'arbre, le tronc doit être 0 et les feuilles
# doit être 1).
#
# 3. Cartes
#
# Pour définir une carte comme isométrique, ajoutez simplement "[Isométrique]"
# (sans guillemets) à ses notes.
# Le mappage est le même que la normale, la seule différence est qu'il est possible de définir le
# hauteur d'une tuile (pour faire un mur par exemple), la hauteur maximale est
# défini dans les paramètres, il n'est pas recommandé de changer (autre que quiconque
# vous devriez avoir besoin de plus de 5 tuiles en hauteur ...), mais n'hésitez pas.
# Pour définir la hauteur de la tuile, il suffit de la marquer avec un numéro de région (F7)
# correspondant à la hauteur.
# Obs.: La hauteur de la tuile influence également la passabilité, une tuile est seulement
# passable si la différence de hauteur entre lui et le caractère est inférieure à 2, ceci
# empêche le joueur de sauter par-dessus un mur de 2 tuiles de haut à moins
# il est sur une tuile de 1 ou qu'il saute d'un mur de 2
# tuiles hautes directement au sol.
#==============================================================================
($imported ||= {})[:mbs_isometric] = true
#==============================================================================
module MBS
  module Isometric
#==============================================================================
# Configurações
#==============================================================================
    # Altura máxima de um tile
    MAX_HEIGHT = 5

    # Caso queira que as paredes fiquem transparentes quando um char passar por
    # trás dela deixe como true, se não deixe como false
    $view_behind = true

    # Pasta onde ficam os tilesets isométricos
    ISO_TILESET = 'Graphics/Iso/'
   
    # Caso queira que o movimento seja em 8 direções, deixe como true, se não,
    # mude para false
    DIR8 = true
#==============================================================================
# Fim das Configurações
#==============================================================================
    ISO_TAG = /[Isometric]/i
  end
end

#------------------------------------------------------------------------------
# Ajuste de performance
#------------------------------------------------------------------------------
Win32API.new('kernel32', 'SetPriorityClass', 'pi', 'i').call(-1, 0x080)
Graphics.frame_rate = 40

#==============================================================================
# ** Isomap
#------------------------------------------------------------------------------
# Esta classe desenha o mapa isométrico, bem como os chars do mapa
#==============================================================================
class Isomap
 
  #--------------------------------------------------------------------------
  # Inclusão do módulo MBS::Isometric
  #--------------------------------------------------------------------------
  include MBS::Isometric
 
  #--------------------------------------------------------------------------
  # Definição dos atributos
  #--------------------------------------------------------------------------
  attr_accessor :flags, :bitmaps, :characters, :ox, :oy, :viewport
  attr_reader :sprite, :data
 
  #--------------------------------------------------------------------------
  # * Inicialização do objeto
  #     viewport : A camada da tela onde fica o sprite
  #--------------------------------------------------------------------------
  def initialize(viewport)
    @viewport = viewport
    setup
  end
 
  #--------------------------------------------------------------------------
  # * Configuração das variáveis
  #--------------------------------------------------------------------------
  def setup
    @ox = 0
    @oy = 0
    @tileset = nil
    @data = nil
    @todraw = nil
    @flags = []
    @bitmaps = []
    @characters = []
    @sprite = Sprite.new(self.viewport)
    @sprite.z = 200
    @sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
  end

  #--------------------------------------------------------------------------
  # * Atualização do objeto
  #--------------------------------------------------------------------------
  def update
    @sprite.update
    return unless @tileset
    draw_sprites
  end
 
  #--------------------------------------------------------------------------
  # * Definição do tileset isométrico
  #     name : Nome do arquivo de tileset
  #--------------------------------------------------------------------------
  def data=(table)
    @data = table
    @todraw = Table.new(table.xsize, table.ysize, 7)
  end
 
  #--------------------------------------------------------------------------
  # * Definição do tileset isométrico
  #     name : Nome do arquivo de tileset
  #--------------------------------------------------------------------------
  def tileset=(name)
    @tileset = Bitmap.new(ISO_TILESET + name)
  end
 
  #--------------------------------------------------------------------------
  # * Verificação de se um char está atrás de um bloco na posição XY
  #     x : Coordenada X
  #     y : Coordenada Y
  #     h : Altura do bloco
  #--------------------------------------------------------------------------
  def char_hidden?(x, y, h)
    @characters.each do |spr|
      next unless spr.visible
      char = spr.character
      ch = char.region_id % (MAX_HEIGHT + 1)
      next if ch >= h
      return true if catch(:any) do
        (1...(h - ch)).each do |i|
          throw(:any, true) if (char.x == x && char.y == y - i ||
           char.x == x - i && char.y == y ||
           char.x == x - i && char.y == y - i)
         end
         false
      end
    end
    false
  end
 
  #--------------------------------------------------------------------------
  # * Aquisição do ID de um tile A5
  #--------------------------------------------------------------------------
  def tileA5(id)
    return id - 0x600 # 0x600 = 1536 (número de tiles A1-A4)
  end
 
  #--------------------------------------------------------------------------
  # * Aquisição da região de um tile
  #--------------------------------------------------------------------------
  def region_id(x, y)
    (data[x, y, 3] >> 8) % (MAX_HEIGHT + 1)
  end
 
  #--------------------------------------------------------------------------
  # * Desenho dos sprites na tela
  #--------------------------------------------------------------------------
  def draw_sprites
    return unless @data
    @sprite.bitmap.clear
    return if @data.xsize <= 0 || @data.ysize <= 0
    for y in 0...@data.ysize
      for x in 0...@data.xsize
        catch(:draw) do
          # Desenho do bloco de chão/parede
          tile_id = data[x, y, 0]
          id = tileA5(tile_id)
          if id > 0 && id <= 128
            region = region_id(x, y)
            draw_block(x, y, id, $view_behind ? char_hidden?(x, y, region) : false)
          end
         
          # Desenho dos tiles B-E (Abaixo do personagem)
          tile_id = data[x, y, 2]
          if (tile_id || 0) >= 0 && flags[tile_id] & 0x0010 == 0       
            draw_second_layer(x, y, tile_id)
          end
         
          # Desenho dos chars
          @characters.select do |spr|
            spr.visible && spr.character.real_x.ceil == x &&
            spr.character.real_y.ceil == y
          end.each do |spr|
            draw_character(spr)
          end
         
          # Desenho dos tiles B-E (Acima do personagem)
          if (tile_id || 0) <= 0 || flags[tile_id] & 0x0010 == 0
            next
          else
            draw_second_layer(x, y, tile_id)
          end
        end
      end
    end
  end
 
  #--------------------------------------------------------------------------
  # * Ajuste das coordenadas
  #     x : Coordenada X
  #     y : Coordenada Y
  #--------------------------------------------------------------------------
  def adjust_xy(x, y)
    [x - self.ox - 32, y - self.oy + (MAX_HEIGHT + 1) * 32]
  end
 
  #--------------------------------------------------------------------------
  # * Desenho de um bloco de tile na tela
  #     a          : Coordenada X
  #     y          : Coordenada Y
  #     id         : ID do tile
  #     translucid : Se o tile será semi-transparente ou não
  #--------------------------------------------------------------------------
  def draw_block(a, b, id, translucid=false)
    return if id <= 0
    # Retângulo do bloco no tileset
    rect = Rect.new((id % 8) * 64, (id / 8) * 64, 64, 64)
   
    # Coordenadas
    x = (a - b) * 32
    y = (a + b) * 16
    x, y = *adjust_xy(x, y)
   
    # Altura do bloco
    height = region_id(a, b)
   
    # Interrompe o desenho se estiver fora da tela
    return if x < -64 || y < -64
    if x >= Graphics.width || (y - MAX_HEIGHT * 32 - 32) >= Graphics.height
      throw(:draw)
    end

    # Desenho do bloco
    @sprite.bitmap.blt(x, y, @tileset, rect)
    for h in 1..height
      @sprite.bitmap.blt(x, y - h * 32, @tileset, rect, translucid ? 50 : 255)
    end
  end
 
  #--------------------------------------------------------------------------
  # * Desenho de um tile da segunda camada na tela
  #--------------------------------------------------------------------------
  def draw_second_layer(a, b, tile_id)
   
    # Valores do tile
    id = tile_id % 0x100                     # ID do tile
    lt = tile_id / 0x100                     # Tileset (0-4)
    tt = (@flags[tile_id] & 0xf000) / 0x1000 # Tag de terreno do tile (0-7)
    height = (data[a, b + tt, 3] >> 8) % (MAX_HEIGHT + 1) # Altura do tile
   
    # Alistamento do tile para desenho posterior
    if tt > 0 && @todraw[a, b+tt, tt-1] != tile_id
      @todraw[a, b+tt, tt-1] = tile_id
      return
    end
   
    # Desenho dos tiles alistados
    for i in 0...7
      if @todraw[a, b, i] > 0
        draw_second_layer(a, b-i-1, @todraw[a, b, i])
        @todraw[a, b, i] = 0
      end
    end
   
    # Bitmap do tileset
    bmp = @bitmaps[5 + lt]
   
    # Coordenadas
    a -= tt
    x = (a - b) * 32
    y = (a + b) * 16
    x, y = *adjust_xy(x, y)
   
    # Retângulo do tile
    if id < 128
      rect = Rect.new((id % 8) * 32, (id / 8) * 32, 32, 32)
    else
      id -= 128
      rect = Rect.new((id % 8) * 32 + 256, (id / 8) * 32, 32, 32)
    end
   
    # Desenho do tile
    @sprite.bitmap.blt(x + 16, y - 8 - height * 32, bmp, rect)
  end
 
  #--------------------------------------------------------------------------
  # * Desenho de um char na tela
  #--------------------------------------------------------------------------
  def draw_character(sprite)
    return unless sprite.is_a?(Sprite_Character)
    # Coordenadas
    x, y = *adjust_xy(sprite.x - sprite.ox, sprite.y - sprite.oy)
   
    return if x < -64 || y < -64 || x >= Graphics.width || (y - sprite.src_rect.height) >= Graphics.height
   
    # Desenho do char
    @sprite.bitmap.blt(x, y, sprite.bitmap, sprite.src_rect)
  end
 
  #--------------------------------------------------------------------------
  # * Disposição do objeto
  #--------------------------------------------------------------------------
  def dispose
    @sprite.dispose
  end
end

#==============================================================================
# * Game_CharacterBase
#------------------------------------------------------------------------------
# Aqui são feitas as modificações nos characters para corrigir a posição na
# tela e ajustar o movimento diagonal
#==============================================================================
class Game_CharacterBase
  #--------------------------------------------------------------------------
  # Alias
  #--------------------------------------------------------------------------
  alias mbsisomovediagonal move_diagonal
  alias mbsisomovestraight move_straight
  alias mbsisomappassable map_passable?
  alias mbsisoscreenx screen_x
  alias mbsisoscreeny screen_y
  alias mbsisoshifty shift_y
  alias mbsisoopacity opacity
 
  #--------------------------------------------------------------------------
  # * Definição de coordenada X na tela
  #--------------------------------------------------------------------------
  def screen_x
    return (@real_x - @real_y + 1) * 32 if $game_map.isometric?
    mbsisoscreenx
  end
  #--------------------------------------------------------------------------
  # * Definição de coordenada Y na tela
  #--------------------------------------------------------------------------
  def screen_y
    if $game_map.isometric?
      return (@real_x + @real_y + 1) * 16 - shift_y - jump_height - region_height
    end
    mbsisoscreeny
  end
 
  #--------------------------------------------------------------------------
  # * Aquisição da altura do char de acordo com a região
  #--------------------------------------------------------------------------
  def region_height
    (region_id % (MBS::Isometric::MAX_HEIGHT + 1)) * 32
  end
 
  #--------------------------------------------------------------------------
  # * Aquisição da mudança de posição sobre tile
  #--------------------------------------------------------------------------
  def shift_y
    return 0 if $game_map.isometric?
    mbsisoshifty
  end
 
  #--------------------------------------------------------------------------
  # * Aquisição da opacidade do char
  #--------------------------------------------------------------------------
  def opacity
    return 0 if $game_map.isometric?
    mbsisoopacity
  end
 
  #--------------------------------------------------------------------------
  # * Movimento na diagonal
  #     horz : Direção horizontal (4 ou 6)
  #     vert : Direção vertical (2 ou 8)
  #--------------------------------------------------------------------------
  def move_diagonal(horz, vert)
    # Ajuste de velocidade
    if $game_map.isometric?
      if (horz == 4 && vert == 2) || (horz == 6 && vert == 8)
        unless @dsa
          @move_speed /= 1.25
          @dsa = true
        end
      elsif @dsa
        @move_speed *= 1.25
        @dsa = false
      end
    end
    mbsisomovediagonal(horz, vert)
  end
 
  #--------------------------------------------------------------------------
  # * Movimento em linha reta
  #--------------------------------------------------------------------------
  def move_straight(*args)
    # Ajuste de velocidade
    if @dsa
      @move_speed *= 1.25
      @dsa = false
    end
    mbsisomovestraight(*args)
  end
 
  #--------------------------------------------------------------------------
  # * Aquisição da diferença entre as regiões do character e do tile XY no
  #   mapa
  #     x : coordenada X
  #     y : coordenada Y
  #--------------------------------------------------------------------------
  def region_difference(x, y)
    mh = MBS::Isometric::MAX_HEIGHT
    (($game_map.region_id(x, y) % (mh + 1)) - (region_id % (mh + 1))).abs
  end
 
  #--------------------------------------------------------------------------
  # * Definição de passagem no mapa
  #     x : coordenada X
  #     y : coordenada Y
  #     d : direção (2,4,6,8)
  #--------------------------------------------------------------------------
  def map_passable?(x, y, d)
    if $game_map.isometric?
      return mbsisomappassable(x, y, d) && region_difference(x, y) < 2
    end
    mbsisomappassable(x, y, d)
  end
end

#==============================================================================
# ** Game_Map
#------------------------------------------------------------------------------
# Aqui são feitas as modificações para evitar que a tela mude de posição
#==============================================================================
class Game_Map 
  #--------------------------------------------------------------------------
  # Alias
  #--------------------------------------------------------------------------
  alias mbsisosetdisplaypos set_display_pos
 
  #--------------------------------------------------------------------------
  # * Definir a posição de exibição
  #     x : coordenada X de exibição
  #     y : coordenada Y de exibição
  #--------------------------------------------------------------------------
  def set_display_pos(x, y)
    if isometric?
      @parallax_x = x
      @parallax_y = y
    else
      mbsisosetdisplaypos(x, y)
    end
  end
 
  #--------------------------------------------------------------------------
  # * Verificação de se o mapa é isométrico
  #--------------------------------------------------------------------------
  def isometric?
    !@map.note[MBS::Isometric::ISO_TAG].nil?
  end
end

#==============================================================================
# ** Game_Player
#------------------------------------------------------------------------------
# Aqui são feitas as modificações para evitar que a tela mude de posição e para
# o movimento diagonal
#==============================================================================
class Game_Player < Game_Character
  #--------------------------------------------------------------------------
  # Alias
  #--------------------------------------------------------------------------
  alias mbsisoupdatescroll update_scroll
 
  #--------------------------------------------------------------------------
  # * Atualização da rolagem
  #     last_real_x : ultima coordenada X real
  #     last_real_y : ultima coordenada Y real
  #--------------------------------------------------------------------------
  def update_scroll(*args)
    return if $game_map.isometric?
    mbsisoupdatescroll(*args)
  end
 
  #--------------------------------------------------------------------------
  # Movimento diagonal
  #--------------------------------------------------------------------------
  if MBS::Isometric::DIR8
    #------------------------------------------------------------------------
    # * Processamento de movimento através de pressionar tecla
    #------------------------------------------------------------------------
    def move_by_input
      return if !movable? || $game_map.interpreter.running?
      case Input.dir8
      when 1 # Esquerda-cima
        @direction = 4
        move_diagonal(4,2)
      when 2 # Cima
        move_straight(2)
      when 3 # Direita-cima
        @direction = 2
        move_diagonal(6,2)
      when 4 # Esquerda
        move_straight(4)
      when 6 # Direita
        move_straight(6)
      when 7 # Esquerda-baixo
        @direction = 8
        move_diagonal(4,8)
      when 8 # Baixo
        move_straight(8)
      when 9 # Direita-baixo
        @direction = 6
        move_diagonal(6,8)
      end
    end
  end
end

#==============================================================================
# ** Spriteset_Map
#------------------------------------------------------------------------------
# Aqui são feitas as modificações nos sprites do mapa para se mostrar o Isomap
# e não o Tilemap
#==============================================================================
class Spriteset_Map
  #--------------------------------------------------------------------------
  # * Alias
  #--------------------------------------------------------------------------
  alias mbsisoinitialize initialize
  alias mbsisoloadtileset load_tileset
  alias mbsisoupdatetilemap update_tilemap
  alias mbsisocreatetilemap create_tilemap
 
  #--------------------------------------------------------------------------
  # * Inicialização do objeto
  #--------------------------------------------------------------------------
  def initialize(*args)
    mbsisoinitialize(*args)
  end
 
  #--------------------------------------------------------------------------
  # * Criação do tilemap
  #--------------------------------------------------------------------------
  def create_tilemap
    mbsisocreatetilemap
    setup_tilemap
  end
 
  #--------------------------------------------------------------------------
  # * Configuração do tilemap
  #--------------------------------------------------------------------------
  def setup_tilemap
    if @tilemap.is_a?(Tilemap) && $game_map.isometric?
      @tilemap = Isomap.new(@viewport1)
      load_tileset
    elsif @tilemap.is_a?(Isomap) && !$game_map.isometric?
      mbsisocreatetilemap
    end
  end
 
  #--------------------------------------------------------------------------
  # * Atualização do tilemap
  #--------------------------------------------------------------------------
  def update_tilemap
    setup_tilemap
    if @tilemap.is_a?(Isomap)
      @tilemap.data = $game_map.data
      @tilemap.characters = @character_sprites
      @tilemap.ox = $game_player.screen_x - Graphics.width / 2 + $game_map.display_x * 32
      @tilemap.oy = $game_player.screen_y - Graphics.height / 2 + (MBS::Isometric::MAX_HEIGHT + 1) * 32 + $game_map.display_y * 16
      @tilemap.update
    else
      mbsisoupdatetilemap
    end
  end
 
  #--------------------------------------------------------------------------
  # * Carregamento dos tilesets
  #--------------------------------------------------------------------------
  def load_tileset
    mbsisoloadtileset
    @tilemap.tileset = @tileset.name if @tilemap.is_a?(Isomap)
  end
 
  #--------------------------------------------------------------------------
  # * Disposição do tilemap
  #--------------------------------------------------------------------------
  def dispose_tilemap
    @tilemap.dispose
  end
end
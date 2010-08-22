require 'permissive_field_of_view'

class ShadowMap
  include PermissiveFieldOfView
  def initialize map
    @map = map
    @width = map.width
    @height = map.height
    reset_shadows
  end

  def reset_shadows
    @light_map = Array.new(@map.width) do |x|
      Array.new(@map.height) do |y|
        false
      end
    end
  end

  def blocked? x,y
    return @map.tile_at(x,y) != :empty
  end

  def light x,y
    @light_map[x][y] = true
  end

  def lit? x,y
    @light_map[x][y]
  end

end
